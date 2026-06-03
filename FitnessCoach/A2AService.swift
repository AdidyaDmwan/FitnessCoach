import Foundation
import Combine

struct A2ARequest: Codable {
    let jsonrpc: String
    let id: String
    let method: String
    let params: A2ARequestParams
}

struct A2ARequestParams: Codable {
    let agent: String
    let task: String
}

struct A2AResponse: Codable {
    let jsonrpc: String
    let id: String
    let result: A2AResult
}

struct A2AResult: Codable {
    let agent: String
    let task: String
    let status: String
    let artifact: CalorieArtifact
}

struct CalorieArtifact: Codable {
    let date: String
    let calories: CalorieData
}

struct CalorieData: Codable {
    let active: Int
    let resting: Int
    let total: Int
    let unit: String
}

struct FitnessDashboardSnapshot {
    let dailyGoal: Int
    let activeCalories: Int
    let restingCalories: Int
    let totalCalories: Int
    let progress: Double
    let healthConnectionStatus: String
    let sourceAgent: String
    let recommendationTitle: String
    let recommendationDetail: String
    let updatedAt: Date
    let isUsingMockData: Bool
}

struct WorkoutRecommendation: Codable {
    let title: String
    let duration: String
    let exercises: [String]
    let tip: String

    init(title: String, duration: String, exercises: [String], tip: String) {
        self.title = title
        self.duration = duration
        self.exercises = exercises
        self.tip = tip
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        duration = try container.decode(String.self, forKey: .duration)
        tip = try container.decodeIfPresent(String.self, forKey: .tip) ?? ""

        if let strings = try? container.decode([String].self, forKey: .exercises) {
            exercises = strings
        } else {
            let flexibleExercises = try container.decode([FlexibleExercise].self, forKey: .exercises)
            exercises = flexibleExercises.map { $0.text }
        }
    }
}

private struct FlexibleExercise: Decodable {
    let text: String

    init(from decoder: Decoder) throws {
        if let singleValueContainer = try? decoder.singleValueContainer(),
           let value = try? singleValueContainer.decode(String.self) {
            text = value
            return
        }

        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        let preferredKeys = ["name", "title", "exercise", "description"]

        for key in preferredKeys {
            if let codingKey = DynamicCodingKey(stringValue: key),
               let value = try? container.decode(String.self, forKey: codingKey) {
                text = value
                return
            }
        }

        text = "Exercise"
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

final class DailyGoalStore: ObservableObject {
    @Published var dailyGoal: Int
    private let defaults: UserDefaults
    private let defaultsKey = "dailyGoal"
    private let defaultGoal = 700

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: defaultsKey) == nil {
            self.dailyGoal = defaultGoal
        } else {
            self.dailyGoal = defaults.integer(forKey: defaultsKey)
        }
    }

    func setGoal(_ value: Int) {
        dailyGoal = value
        defaults.set(value, forKey: defaultsKey)
    }
}

private struct UIAgentWorkoutRequest: Encodable {
    let fitnessLevel: String
    let goal: String
    let availableTime: Int
    let activeCalories: Int
    let dailyGoal: Int
    let progress: Double
}

private struct UIAgentWorkoutResponse: Decodable {
    let workout: String
    let status: String
}

private struct QAAgentValidationRequest: Encodable {
    let content: String
    let type: String
}

private struct QAAgentValidationResponse: Decodable {
    let validation: String
    let status: String
}

private struct WorkoutValidation: Decodable {
    let isValid: Bool
    let issues: [String]
    let safeContent: String
}

final class FitnessA2AClient {
    private let healthKitService: HealthKitService
    private let goalStore: DailyGoalStore
    var dailyGoal: Int { goalStore.dailyGoal }
    private let baseURL = URL(string: "http://localhost:5001")!
    private let urlSession: URLSession

    init(
        healthKitService: HealthKitService = HealthKitService(),
        urlSession: URLSession = .shared,
        goalStore: DailyGoalStore = DailyGoalStore()
    ) {
        self.healthKitService = healthKitService
        self.urlSession = urlSession
        self.goalStore = goalStore
    }

    func refreshDashboard() async -> FitnessDashboardSnapshot {
        let request = A2ARequest(
            jsonrpc: "2.0",
            id: "task-dashboard-\(Int(Date().timeIntervalSince1970))",
            method: "tasks/send",
            params: A2ARequestParams(agent: "AppleHealthAgent", task: "fetchDashboardMetrics")
        )

        if let healthData = await healthKitService.fetchTodaySamples(), healthData.activeCalories > 0 {
            let totalCalories = max(healthData.activeCalories + healthData.restingCalories, healthData.activeCalories)
            return makeSnapshot(
                request: request,
                activeCalories: healthData.activeCalories,
                restingCalories: healthData.restingCalories,
                totalCalories: totalCalories,
                status: healthKitService.connectionState.rawValue,
                sourceAgent: "AppleHealthAgent",
                isUsingMockData: false
            )
        }

        if let mockResponse = loadMockA2AResponse() {
            let fallbackStatus = healthKitService.connectionState == .unavailable
                ? "Unavailable - Mock A2A"
                : "No Health Data - Mock A2A"

            return makeSnapshot(
                request: request,
                activeCalories: mockResponse.result.artifact.calories.active,
                restingCalories: mockResponse.result.artifact.calories.resting,
                totalCalories: mockResponse.result.artifact.calories.total,
                status: fallbackStatus,
                sourceAgent: mockResponse.result.agent,
                isUsingMockData: true
            )
        }

        return makeSnapshot(
            request: request,
            activeCalories: 0,
            restingCalories: 0,
            totalCalories: 0,
            status: healthKitService.connectionState.rawValue,
            sourceAgent: request.params.agent,
            isUsingMockData: true
        )
    }

    private func makeSnapshot(
        request: A2ARequest,
        activeCalories: Int,
        restingCalories: Int,
        totalCalories: Int,
        status: String,
        sourceAgent: String,
        isUsingMockData: Bool
    ) -> FitnessDashboardSnapshot {
        let progress = dailyGoal == 0 ? 0 : min(Double(activeCalories) / Double(dailyGoal), 1.0)
        let recommendation = recommendationFor(activeCalories: activeCalories, progress: progress)

        return FitnessDashboardSnapshot(
            dailyGoal: dailyGoal,
            activeCalories: activeCalories,
            restingCalories: restingCalories,
            totalCalories: totalCalories,
            progress: progress,
            healthConnectionStatus: status,
            sourceAgent: sourceAgent,
            recommendationTitle: recommendation.title,
            recommendationDetail: "\(recommendation.detail) - \(request.method)",
            updatedAt: Date(),
            isUsingMockData: isUsingMockData
        )
    }

    private func recommendationFor(activeCalories: Int, progress: Double) -> (title: String, detail: String) {
        if progress >= 0.85 {
            return ("Recovery Mobility", "Goal almost complete")
        } else if activeCalories < 250 {
            return ("Full Body HIIT", "Boost active calories")
        } else {
            return ("Core Stability", "Keep momentum steady")
        }
    }

    private func loadMockA2AResponse() -> A2AResponse? {
        guard let url = Bundle.main.url(forResource: "mock_a2a_response", withExtension: "json") else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(A2AResponse.self, from: data)
        } catch {
            print("Mock A2A decode failed: \(error.localizedDescription)")
            return nil
        }
    }

    func fetchValidatedWorkoutRecommendation(snapshot: FitnessDashboardSnapshot) async -> WorkoutRecommendation {
        do {
            let workout = try await fetchWorkoutRecommendation(snapshot: snapshot)
            let validation = try await validate(workout: workout)
            return validation.isValid ? workout : Self.fallbackWorkout
        } catch {
            print("AI workout fallback used: \(error.localizedDescription)")
            return Self.fallbackWorkout
        }
    }

    private func fetchWorkoutRecommendation(snapshot: FitnessDashboardSnapshot) async throws -> WorkoutRecommendation {
        let requestBody = UIAgentWorkoutRequest(
            fitnessLevel: savedFitnessLevel,
            goal: savedGoal,
            availableTime: 30,
            activeCalories: snapshot.activeCalories,
            dailyGoal: snapshot.dailyGoal,
            progress: snapshot.progress
        )
        let response: UIAgentWorkoutResponse = try await post(
            requestBody,
            path: "/api/workout-recommendation"
        )

        guard response.status == "completed" else {
            throw A2AClientError.agentFailed("UIAgent status: \(response.status)")
        }

        guard let data = response.workout.data(using: .utf8) else {
            throw A2AClientError.invalidJSONString
        }

        return try JSONDecoder().decode(WorkoutRecommendation.self, from: data)
    }

    private func validate(workout: WorkoutRecommendation) async throws -> WorkoutValidation {
        let response: QAAgentValidationResponse = try await post(
            QAAgentValidationRequest(content: workout.validationText, type: "workout"),
            path: "/api/validate"
        )

        guard response.status == "completed" else {
            throw A2AClientError.agentFailed("QAAgent status: \(response.status)")
        }

        guard let data = response.validation.data(using: .utf8) else {
            throw A2AClientError.invalidJSONString
        }

        return try JSONDecoder().decode(WorkoutValidation.self, from: data)
    }

    private var savedFitnessLevel: String {
        UserDefaults.standard.string(forKey: "profileFitnessLevel") ?? "Intermediate Level"
    }

    private var savedGoal: String {
        UserDefaults.standard.string(forKey: "profileGoal") ?? "General Fitness"
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(
        _ body: RequestBody,
        path: String
    ) async throws -> ResponseBody {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw A2AClientError.badResponse
        }

        return try JSONDecoder().decode(ResponseBody.self, from: data)
    }

    static let fallbackWorkout = WorkoutRecommendation(
        title: "Full Body HIIT",
        duration: "30 min",
        exercises: [
            "Jumping jacks",
            "Bodyweight squats",
            "Push ups",
            "Mountain climbers",
            "Plank"
        ],
        tip: "Move at a steady pace and stop if anything feels painful."
    )
}

private enum A2AClientError: LocalizedError {
    case badResponse
    case invalidJSONString
    case agentFailed(String)

    var errorDescription: String? {
        switch self {
        case .badResponse:
            return "The agent returned an invalid response."
        case .invalidJSONString:
            return "The agent returned malformed JSON content."
        case .agentFailed(let message):
            return message
        }
    }
}

private extension WorkoutRecommendation {
    var validationText: String {
        var lines = ["Title: \(title)", "Exercises:"]
        lines.append(contentsOf: exercises.map { "- \($0)" })
        return lines.joined(separator: "\n")
    }
}

@MainActor
final class DashboardA2AViewModel: ObservableObject {
    @Published var snapshot: FitnessDashboardSnapshot?
    @Published var aiWorkout: WorkoutRecommendation?
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var dailyGoalStore = DailyGoalStore()

    private let client: FitnessA2AClient

    init(client: FitnessA2AClient? = nil) {
        let goalStore = DailyGoalStore()
        self.dailyGoalStore = goalStore
        self.client = client
            ?? FitnessA2AClient(goalStore: goalStore)
    }

    func updateDailyGoal(_ newGoal: Int) {
        dailyGoalStore.setGoal(newGoal)
        refresh()
    }

    func refresh() {
        isRefreshing = true
        errorMessage = nil

        Task {
            let snapshot = await client.refreshDashboard()
            let workout = await client.fetchValidatedWorkoutRecommendation(snapshot: snapshot)
            self.snapshot = snapshot
            self.aiWorkout = workout
            self.isRefreshing = false
        }
    }
}
