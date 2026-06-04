import Foundation

struct WorkoutSessionRecord: Codable, Identifiable {
    let id: UUID
    let move: WorkoutMove
    let date: Date
    let reps: Int
    let targetReps: Int
    let duration: TimeInterval
    let averageScore: Int

    init(
        id: UUID = UUID(),
        move: WorkoutMove,
        date: Date = Date(),
        reps: Int,
        targetReps: Int,
        duration: TimeInterval,
        averageScore: Int
    ) {
        self.id = id
        self.move = move
        self.date = date
        self.reps = reps
        self.targetReps = targetReps
        self.duration = duration
        self.averageScore = averageScore
    }
}

final class WorkoutHistoryStore: ObservableObject {
    @Published private(set) var sessions: [WorkoutSessionRecord] = []

    private let defaults: UserDefaults
    private let sessionsKey = "workoutSessionHistory"
    private let maxSavedSessions = 80

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var totalReps: Int {
        sessions.reduce(0) { $0 + $1.reps }
    }

    var weeklySessions: [WorkoutSessionRecord] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let startOfWeek = calendar.date(byAdding: .day, value: -6, to: startOfToday) else {
            return sessions
        }

        return sessions.filter { $0.date >= startOfWeek }
    }

    var weeklyReps: Int {
        weeklySessions.reduce(0) { $0 + $1.reps }
    }

    var averageScore: Int {
        guard !sessions.isEmpty else {
            return 0
        }

        return sessions.reduce(0) { $0 + $1.averageScore } / sessions.count
    }

    var latestSession: WorkoutSessionRecord? {
        sessions.first
    }

    func add(_ record: WorkoutSessionRecord) {
        guard record.reps > 0 else {
            return
        }

        sessions.insert(record, at: 0)
        if sessions.count > maxSavedSessions {
            sessions = Array(sessions.prefix(maxSavedSessions))
        }
        save()
    }

    func load() {
        guard let data = defaults.data(forKey: sessionsKey),
              let decodedSessions = try? JSONDecoder().decode([WorkoutSessionRecord].self, from: data) else {
            sessions = []
            return
        }

        sessions = decodedSessions.sorted { $0.date > $1.date }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(sessions) else {
            return
        }

        defaults.set(data, forKey: sessionsKey)
    }
}

final class WorkoutGoalStore: ObservableObject {
    @Published var weeklySessionGoal: Int {
        didSet { defaults.set(weeklySessionGoal, forKey: weeklySessionGoalKey) }
    }

    @Published var weeklyRepGoal: Int {
        didSet { defaults.set(weeklyRepGoal, forKey: weeklyRepGoalKey) }
    }

    private let defaults: UserDefaults
    private let weeklySessionGoalKey = "weeklySessionGoal"
    private let weeklyRepGoalKey = "weeklyRepGoal"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        weeklySessionGoal = defaults.object(forKey: weeklySessionGoalKey) == nil
            ? 4
            : defaults.integer(forKey: weeklySessionGoalKey)
        weeklyRepGoal = defaults.object(forKey: weeklyRepGoalKey) == nil
            ? 120
            : defaults.integer(forKey: weeklyRepGoalKey)
    }

    func adjustSessions(by amount: Int) {
        weeklySessionGoal = max(1, weeklySessionGoal + amount)
    }

    func adjustReps(by amount: Int) {
        weeklyRepGoal = max(10, weeklyRepGoal + amount)
    }
}
