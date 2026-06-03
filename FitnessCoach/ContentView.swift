//
//  ContentView.swift
//  FitnessCoach
//
//  Created by 17 on 2026/5/13.
//

import SwiftUI
import UIKit

struct ContentView: View {
    var body: some View {
        NavigationView {
            MainTabView()
                .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .accentColor(.fcInk)
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeDashboardView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            TabBackContainer(title: "Energy", selectedTab: $selectedTab) {
                NutritionLogView()
            }
                .tabItem { Label("Energy", systemImage: "waveform.path.ecg") }
                .tag(1)

            TabBackContainer(title: "Camera", selectedTab: $selectedTab) {
                CameraFeedbackView()
            }
                .tabItem { Label("Camera", systemImage: "camera") }
                .tag(2)

            AIChatView()
                .tabItem { Label("AI Chat", systemImage: "bubble.left.and.bubble.right") }
                .tag(3)

            TabBackContainer(title: "More", selectedTab: $selectedTab) {
                ProfileScreenView()
            }
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tag(4)
        }
        .accentColor(.fcInk)
        .navigationBarHidden(true)
        .toolbarBackground(Color.white, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        appearance.shadowColor = UIColor.separator

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

struct TabBackContainer<Content: View>: View {
    let title: String
    @Binding var selectedTab: Int
    let content: Content

    init(title: String, selectedTab: Binding<Int>, @ViewBuilder content: () -> Content) {
        self.title = title
        self._selectedTab = selectedTab
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    selectedTab = 0
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.fcInk)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(Color.fcSoft)
                    .clipShape(Capsule())
                }

                Spacer()

                Text(title)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.fcInk)

                Spacer()

                Color.clear
                    .frame(width: 82, height: 42)
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .background(Color.white)

            content
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
    }
}

struct HomeDashboardView: View {
    @StateObject private var viewModel = DashboardA2AViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Today")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(.fcMuted)

                        Text("Fitness Coach")
                            .font(.system(size: 32, weight: .heavy))
                            .foregroundColor(.fcInk)
                    }

                    Spacer()

                    Button(action: {
                        viewModel.refresh()
                    }) {
                        if viewModel.isRefreshing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .fcInk))
                                .frame(width: 48, height: 48)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundColor(.fcInk)
                                .frame(width: 48, height: 48)
                        }
                    }
                    .background(Color.fcSoft)
                    .clipShape(Circle())
                }
                .padding(.top, 24)

                HomeGoalSummaryCard(
                    snapshot: viewModel.snapshot,
                    displayedGoal: viewModel.dailyGoalStore.dailyGoal,
                    decreaseGoal: {
                        adjustDailyGoal(by: -25)
                    },
                    increaseGoal: {
                        adjustDailyGoal(by: 25)
                    }
                )

                HomeWorkoutRecommendationCard(
                    snapshot: viewModel.snapshot,
                    aiWorkout: viewModel.aiWorkout,
                    tag: viewModel.aiWorkout.map { truncatedTag($0.tip) } ?? "Based on your activity"
                )

                HealthStatusCard(snapshot: viewModel.snapshot, isRefreshing: viewModel.isRefreshing)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .onAppear {
            if viewModel.snapshot == nil {
                viewModel.refresh()
            }
        }
    }

    private func truncatedTag(_ text: String) -> String {
        guard text.count > 30 else {
            return text
        }

        let endIndex = text.index(text.startIndex, offsetBy: 30)
        return String(text[..<endIndex])
    }

    private func adjustDailyGoal(by amount: Int) {
        let currentGoal = viewModel.snapshot?.dailyGoal ?? viewModel.dailyGoalStore.dailyGoal
        let newGoal = max(100, currentGoal + amount)
        viewModel.updateDailyGoal(newGoal)
    }
}

struct WorkoutRecommendationView: View {
    @Environment(\.presentationMode) private var presentationMode

    private let rows = [
        WorkoutPlanExercise(
            title: "Jumping Jack",
            focus: "Full body warm up",
            target: "30 reps",
            detail: "Open arms and feet together, then return to standing.",
            formTip: "Keep your full body visible to the camera.",
            cameraMove: .jumpingJack
        ),
        WorkoutPlanExercise(
            title: "Squat",
            focus: "Lower body strength",
            target: "15 reps",
            detail: "Sit hips back, bend knees, then stand tall.",
            formTip: "Camera works best from the front with knees and ankles visible.",
            cameraMove: .squat
        ),
        WorkoutPlanExercise(
            title: "Push Up",
            focus: "Upper body strength",
            target: "15 reps",
            detail: "Lower your chest, then press until elbows extend.",
            formTip: "Use a side angle so shoulders, elbows, and wrists are visible.",
            cameraMove: .pushUp
        ),
        WorkoutPlanExercise(
            title: "Sit Up",
            focus: "Core strength",
            target: "15 reps",
            detail: "Curl your shoulders toward your hips, then return down.",
            formTip: "Use a side angle so shoulders and hips are easy to detect.",
            cameraMove: .sitUp
        ),
        WorkoutPlanExercise(
            title: "Wall Sit",
            focus: "Lower body endurance",
            target: "45 sec",
            detail: "Hold your back against a wall with knees bent.",
            formTip: "Timed hold. Camera counting is not needed for this movement.",
            cameraMove: nil
        ),
        WorkoutPlanExercise(
            title: "Plank",
            focus: "Core stability",
            target: "60 sec",
            detail: "Hold a straight line from shoulders to ankles.",
            formTip: "Timed hold. Keep hips level and breathe steadily.",
            cameraMove: nil
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top) {
                        BackCircleButton {
                            presentationMode.wrappedValue.dismiss()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Smart Workout")
                                .font(.system(size: 27, weight: .heavy))
                                .foregroundColor(.fcInk)

                            Text("Camera-guided reps for supported movements")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.fcMuted)
                        }

                        Spacer()

                        CircleIconButton(systemName: "camera.viewfinder")
                    }
                    .padding(.top, 26)

                    VStack(alignment: .leading, spacing: 18) {
                        Text("Today's Plan")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(.fcInk)

                        HStack(spacing: 12) {
                            PlanSummaryTile(title: "Exercises", value: "\(rows.count)")
                            PlanSummaryTile(title: "Camera", value: "\(rows.filter { $0.cameraMove != nil }.count)")
                            PlanSummaryTile(title: "Goal", value: "Form")
                        }
                    }

                    VStack(spacing: 14) {
                        ForEach(rows) { row in
                            WorkoutPlanRow(exercise: row)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
    }
}

final class WorkoutTimerViewModel: ObservableObject {
    @Published var secondsRemaining: Int = 30
    @Published var isRunning: Bool = false
    @Published var currentSet: Int = 1
    @Published var totalSets: Int = 3
    @Published var currentExerciseIndex: Int = 0

    let exercises = ["Plank", "Push Ups", "Wall Sit", "Crunches", "Jumping Jacks", "Squats"]

    var currentExercise: String {
        exercises[currentExerciseIndex]
    }

    var nextExercise: String {
        let nextIndex = (currentExerciseIndex + 1) % exercises.count
        return exercises[nextIndex]
    }

    var progress: CGFloat {
        1.0 - CGFloat(secondsRemaining) / 30.0
    }

    private var timer: Timer?

    func start() {
        guard !isRunning else {
            return
        }

        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else {
                return
            }

            if self.secondsRemaining > 0 {
                self.secondsRemaining -= 1
            } else {
                self.next()
            }
        }
    }

    func pause() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    func next() {
        pause()
        secondsRemaining = 30

        if currentSet < totalSets {
            currentSet += 1
        } else {
            currentSet = 1
            currentExerciseIndex = (currentExerciseIndex + 1) % exercises.count
        }
    }
}

struct ActiveWorkoutView: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var timerVM = WorkoutTimerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackCircleButton {
                    presentationMode.wrappedValue.dismiss()
                }

                Spacer()

                HStack(spacing: 8) {
                    ForEach(0..<6) { index in
                        Circle()
                            .fill(index < 4 ? Color.fcInk : Color.fcLine)
                            .frame(width: 9, height: 9)
                    }
                }

                Spacer()

                Color.clear
                    .frame(width: 48, height: 48)
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)

            Spacer(minLength: 52)

            Text(timerVM.currentExercise)
                .font(.system(size: 38, weight: .heavy))
                .foregroundColor(.fcInk)

            Spacer(minLength: 58)

            RingProgress(progress: timerVM.progress, lineWidth: 13) {
                Text("\(timerVM.secondsRemaining)\"")
                    .font(.system(size: 72, weight: .heavy))
                    .foregroundColor(.fcInk)
            }
            .frame(width: 274, height: 274)

            Text("Set \(timerVM.currentSet)/\(timerVM.totalSets) - 30s rest next")
                .font(.system(size: 17, weight: .heavy))
                .foregroundColor(.fcMuted)
                .padding(.top, 46)

            Spacer()

            HStack(spacing: 18) {
                Button(action: {
                    timerVM.isRunning ? timerVM.pause() : timerVM.start()
                }) {
                    Image(systemName: timerVM.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 74)
                        .background(Color.fcInk)
                        .clipShape(Capsule())
                }

                Button(action: timerVM.next) {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(.fcInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 74)
                        .background(Color.fcSoft)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 28)

            VStack(spacing: 8) {
                Text("UP NEXT")
                    .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.fcMuted)

                Text(timerVM.nextExercise)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.fcInk)
            }
            .padding(.top, 32)
            .padding(.bottom, 34)
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
        .onAppear {
            timerVM.start()
        }
        .onDisappear {
            timerVM.pause()
        }
    }
}

final class NutritionStore: ObservableObject {
    @Published var breakfast: Int
    @Published var lunch: Int
    @Published var dinner: Int
    @Published var snacks: Int
    @Published var waterGlasses: Int

    private let defaults = UserDefaults.standard
    private var dateKey: String

    var totalEaten: Int {
        breakfast + lunch + dinner + snacks
    }

    init() {
        dateKey = Self.key(for: Date())
        breakfast = 0
        lunch = 0
        dinner = 0
        snacks = 0
        waterGlasses = 0
        load(for: Date())
    }

    func load(for date: Date) {
        dateKey = Self.key(for: date)
        breakfast = defaults.integer(forKey: key("breakfast"))
        lunch = defaults.integer(forKey: key("lunch"))
        dinner = defaults.integer(forKey: key("dinner"))
        snacks = defaults.integer(forKey: key("snacks"))
        waterGlasses = defaults.integer(forKey: key("water"))
    }

    func update(meal: String, calories: Int) {
        let value = max(calories, 0)

        switch meal.lowercased() {
        case "breakfast":
            breakfast = value
            defaults.set(value, forKey: key("breakfast"))
        case "lunch":
            lunch = value
            defaults.set(value, forKey: key("lunch"))
        case "dinner":
            dinner = value
            defaults.set(value, forKey: key("dinner"))
        case "snacks":
            snacks = value
            defaults.set(value, forKey: key("snacks"))
        default:
            break
        }
    }

    func updateWaterGlasses(_ glasses: Int) {
        let value = max(0, min(glasses, 8))
        waterGlasses = value
        defaults.set(value, forKey: key("water"))
    }

    private func key(_ meal: String) -> String {
        "nutrition.\(dateKey).\(meal)"
    }

    private static func key(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}

final class EnergyGoalStore: ObservableObject {
    @Published var calorieGoal: Int

    private let defaults = UserDefaults.standard
    private let key = "energyCalorieGoal"
    private let defaultGoal = 2000

    init() {
        if defaults.object(forKey: key) == nil {
            calorieGoal = defaultGoal
        } else {
            calorieGoal = defaults.integer(forKey: key)
        }
    }

    func updateGoal(_ value: Int) {
        let safeValue = max(1000, min(value, 5000))
        calorieGoal = safeValue
        defaults.set(safeValue, forKey: key)
    }
}

struct NutritionLogView: View {
    @StateObject private var store = NutritionStore()
    @StateObject private var goalStore = EnergyGoalStore()
    @State private var selectedDate = Date()
    @State private var selectedMeal = ""
    @State private var calorieInput = ""
    @State private var isShowingCalorieSheet = false

    private let burnedCalories = 480

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                dateSelector
                    .padding(.top, 25)

                energySummaryCard

                VStack(spacing: 18) {
                    MealRow(title: "Breakfast", calories: "\(store.breakfast) kcal") {
                        openCalorieSheet(meal: "Breakfast", calories: store.breakfast)
                    }
                    MealRow(title: "Lunch", calories: "\(store.lunch) kcal") {
                        openCalorieSheet(meal: "Lunch", calories: store.lunch)
                    }
                    MealRow(title: "Dinner", calories: "\(store.dinner) kcal") {
                        openCalorieSheet(meal: "Dinner", calories: store.dinner)
                    }
                    MealRow(title: "Snacks", calories: "\(store.snacks) kcal") {
                        openCalorieSheet(meal: "Snacks", calories: store.snacks)
                    }
                }

                dailyInsightCard

                WaterCard(
                    glasses: store.waterGlasses,
                    decrease: {
                        store.updateWaterGlasses(store.waterGlasses - 1)
                    },
                    increase: {
                        store.updateWaterGlasses(store.waterGlasses + 1)
                    },
                    select: { glasses in
                        store.updateWaterGlasses(glasses)
                    }
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .sheet(isPresented: $isShowingCalorieSheet) {
            calorieInputSheet
        }
        .onChange(of: selectedDate) { newDate in
            store.load(for: newDate)
        }
    }

    private var dateSelector: some View {
        HStack {
            Button(action: {
                moveDate(by: -1)
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.fcInk)
                    .frame(width: 42, height: 42)
                    .background(Color.fcSoft)
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 4) {
                Text(relativeDateTitle)
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundColor(.fcInk)
                Text(fullDateTitle)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.fcMuted)
            }

            Spacer()

            Button(action: {
                moveDate(by: 1)
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.fcInk)
                    .frame(width: 42, height: 42)
                    .background(Color.fcSoft)
                    .clipShape(Circle())
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var energySummaryCard: some View {
        VStack(spacing: 22) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 16) {
                    energyMetric(title: "Goal", value: "\(calorieGoal)")
                    energyMetric(title: "Remaining", value: "\(remainingCalories)")
                }

                Spacer()

                RingProgress(progress: eatenProgress, lineWidth: 13) {
                    VStack(spacing: 6) {
                        Text("\(store.totalEaten)")
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundColor(.fcInk)
                        Text("EATEN")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(.fcMuted)
                    }
                }
                .frame(width: 174, height: 174)

                Spacer()

                VStack(alignment: .trailing, spacing: 16) {
                    energyMetric(title: "Burned", value: "\(burnedCalories)")
                    energyMetric(title: "Balance", value: "\(energyBalance)")
                }
            }

            ProgressBar(value: eatenProgress, height: 7)

            HStack {
                Text("Adjust goal by 100 kcal")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.fcMuted)

                Spacer()

                goalAdjustButton(systemName: "minus") {
                    goalStore.updateGoal(calorieGoal - 100)
                }

                goalAdjustButton(systemName: "plus") {
                    goalStore.updateGoal(calorieGoal + 100)
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.fcLine, lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
    }

    private var dailyInsightCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(.fcInk)
                .frame(width: 42, height: 42)
                .background(Color.fcSoft)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text("Daily Insight")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.fcMuted)
                Text(insightText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.fcInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.fcLine, lineWidth: 1))
    }

    private var calorieInputSheet: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(selectedMeal)
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(.fcInk)

            TextField("Calories", text: $calorieInput)
                .keyboardType(.numberPad)
                .font(.system(size: 20, weight: .bold))
                .padding(18)
                .background(Color.fcSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button(action: saveCalories) {
                Text("Save")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.fcInk)
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(24)
    }

    private func openCalorieSheet(meal: String, calories: Int) {
        selectedMeal = meal
        calorieInput = calories == 0 ? "" : "\(calories)"
        isShowingCalorieSheet = true
    }

    private func saveCalories() {
        let calories = Int(calorieInput) ?? 0
        store.update(meal: selectedMeal, calories: calories)
        isShowingCalorieSheet = false
    }

    private var eatenProgress: CGFloat {
        min(CGFloat(store.totalEaten) / CGFloat(calorieGoal), 1.0)
    }

    private var calorieGoal: Int {
        goalStore.calorieGoal
    }

    private var remainingCalories: Int {
        max(calorieGoal - store.totalEaten + burnedCalories, 0)
    }

    private var energyBalance: Int {
        store.totalEaten - burnedCalories
    }

    private var insightText: String {
        if store.totalEaten == 0 {
            return "Start by logging your first meal for this date."
        }

        if remainingCalories > 600 {
            return "You still have room for a balanced meal today."
        }

        if remainingCalories > 150 {
            return "A light snack would still fit your goal."
        }

        return "You are close to your goal. Keep the next meal light."
    }

    private var relativeDateTitle: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today"
        }

        if Calendar.current.isDateInYesterday(selectedDate) {
            return "Yesterday"
        }

        if Calendar.current.isDateInTomorrow(selectedDate) {
            return "Tomorrow"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: selectedDate)
    }

    private var fullDateTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: selectedDate)
    }

    private func energyMetric(title: String, value: String) -> some View {
        VStack(alignment: title == "Burned" || title == "Balance" ? .trailing : .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(.fcInk)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.fcMuted)
        }
    }

    private func goalAdjustButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(.fcInk)
                .frame(width: 34, height: 34)
                .background(Color.fcSoft)
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func moveDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
        }
    }
}

struct ProgressAnalyticsView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center) {
                    Text("Progress")
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundColor(.fcInk)

                    Spacer()

                    Label("14-day streak", systemImage: "flame.fill")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.fcInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.fcSoft)
                        .clipShape(Capsule())
                }
                .padding(.top, 34)

                WeeklyActivityCard()

                WeightCard()

                HStack(spacing: 16) {
                    MetricTile(title: "Total Workouts", value: "124")
                    MetricTile(title: "Calories Burned", value: "48k")
                }

                MetricTile(title: "Avg Session Time", value: "38 min")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
    }
}

final class UserProfileStore: ObservableObject {
    @Published var name: String {
        didSet { defaults.set(name, forKey: nameKey) }
    }
    @Published var fitnessLevel: String {
        didSet { defaults.set(fitnessLevel, forKey: fitnessLevelKey) }
    }
    @Published var goal: String {
        didSet { defaults.set(goal, forKey: goalKey) }
    }
    @Published var units: String {
        didSet { defaults.set(units, forKey: unitsKey) }
    }
    @Published var notifications: Bool {
        didSet { defaults.set(notifications, forKey: notificationsKey) }
    }
    @Published var appleHealth: Bool {
        didSet { defaults.set(appleHealth, forKey: appleHealthKey) }
    }
    @Published var darkMode: Bool {
        didSet { defaults.set(darkMode, forKey: darkModeKey) }
    }

    private let defaults = UserDefaults.standard
    private let nameKey = "profileName"
    private let fitnessLevelKey = "profileFitnessLevel"
    private let goalKey = "profileGoal"
    private let unitsKey = "profileUnits"
    private let notificationsKey = "profileNotifications"
    private let appleHealthKey = "profileAppleHealth"
    private let darkModeKey = "profileDarkMode"

    init() {
        name = defaults.string(forKey: nameKey) ?? "Alex Johnson"
        fitnessLevel = defaults.string(forKey: fitnessLevelKey) ?? "Intermediate Level"
        goal = defaults.string(forKey: goalKey) ?? "Muscle Gain"
        units = defaults.string(forKey: unitsKey) ?? "Metric"
        notifications = defaults.object(forKey: notificationsKey) == nil ? true : defaults.bool(forKey: notificationsKey)
        appleHealth = defaults.object(forKey: appleHealthKey) == nil ? true : defaults.bool(forKey: appleHealthKey)
        darkMode = defaults.object(forKey: darkModeKey) == nil ? false : defaults.bool(forKey: darkModeKey)
    }
}

struct ProfileScreenView: View {
    @StateObject private var profile = UserProfileStore()
    @State private var isShowingNameSheet = false
    @State private var isShowingGoalSheet = false
    @State private var editedName = ""

    private let goalOptions = ["Weight Loss", "Muscle Gain", "Endurance", "General Fitness"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                profileHeader
                    .padding(.top, 18)

                HStack(spacing: 12) {
                    ProfileStatTile(title: "Level", value: profile.fitnessLevel)
                    ProfileStatTile(title: "Goal", value: profile.goal)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SettingsSectionTitle("INSIGHTS")

                    VStack(spacing: 0) {
                        MoreNavigationRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Progress Analytics",
                            value: "Streaks & trends",
                            destination: ProgressAnalyticsView()
                        )
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.fcLine, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 12) {
                    SettingsSectionTitle("GOALS & PREFERENCES")

                    VStack(spacing: 0) {
                        MoreActionRow(
                            icon: "target",
                            title: "Goal Settings",
                            value: profile.goal,
                            action: {
                                isShowingGoalSheet = true
                            }
                        )

                        Divider()
                            .padding(.leading, 56)

                        HStack(spacing: 14) {
                            Image(systemName: "ruler")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.fcInk)
                                .frame(width: 40, height: 40)
                                .background(Color.fcSoft)
                                .clipShape(Circle())

                            Text("Units")
                                .font(.system(size: 17, weight: .heavy))
                                .foregroundColor(.fcInk)

                            Spacer()

                            HStack(spacing: 0) {
                                unitButton("Metric")
                                unitButton("Imperial")
                            }
                            .padding(3)
                            .background(Color.fcSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .padding(16)
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.fcLine, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 12) {
                    SettingsSectionTitle("APP SETTINGS")

                    VStack(spacing: 0) {
                        SettingsToggleRow(icon: "bell", title: "Notifications", isOn: profileBinding(\.notifications))
                        SettingsToggleRow(icon: "heart", title: "Apple Health", isOn: profileBinding(\.appleHealth))
                        SettingsToggleRow(icon: "moon", title: "Dark Mode", isOn: profileBinding(\.darkMode))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.fcLine, lineWidth: 1))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .sheet(isPresented: $isShowingNameSheet) {
            nameSheet
        }
        .sheet(isPresented: $isShowingGoalSheet) {
            goalSheet
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.fcInk)

                Text(initials)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(.white)
            }
            .frame(width: 82, height: 82)

            VStack(alignment: .leading, spacing: 9) {
                Text("Account")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.fcMuted)

                Button(action: openNameSheet) {
                    HStack(spacing: 8) {
                        Text(profile.name)
                            .font(.system(size: 25, weight: .heavy))
                            .foregroundColor(.fcInk)
                            .lineLimit(1)

                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(.fcMuted)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                Text("Manage your fitness profile and app preferences")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.fcMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(20)
        .background(Color.fcSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var initials: String {
        let words = profile.name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }

        let value = String(words)
        return value.isEmpty ? "FC" : value.uppercased()
    }

    private var nameSheet: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Edit Name")
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(.fcInk)

            TextField("Name", text: $editedName)
                .font(.system(size: 20, weight: .bold))
                .padding(18)
                .background(Color.fcSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button(action: saveName) {
                Text("Save")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.fcInk)
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(24)
    }

    private var goalSheet: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Goal")
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(.fcInk)

            Picker("Goal", selection: profileBinding(\.goal)) {
                ForEach(goalOptions, id: \.self) { goal in
                    Text(goal).tag(goal)
                }
            }
            .pickerStyle(WheelPickerStyle())

            Button(action: {
                isShowingGoalSheet = false
            }) {
                Text("Save")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.fcInk)
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(24)
    }

    private func unitButton(_ unit: String) -> some View {
        Button(action: {
            profile.units = unit
        }) {
            Text(unit)
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(profile.units == unit ? .fcInk : .fcMuted)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(profile.units == unit ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .shadow(color: profile.units == unit ? .black.opacity(0.10) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func profileBinding<Value>(_ keyPath: ReferenceWritableKeyPath<UserProfileStore, Value>) -> Binding<Value> {
        Binding(
            get: { profile[keyPath: keyPath] },
            set: { profile[keyPath: keyPath] = $0 }
        )
    }

    private func openNameSheet() {
        editedName = profile.name
        isShowingNameSheet = true
    }

    private func saveName() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            profile.name = trimmedName
        }
        isShowingNameSheet = false
    }
}

private struct HomeGoalSummaryCard: View {
    let snapshot: FitnessDashboardSnapshot?
    let displayedGoal: Int
    let decreaseGoal: () -> Void
    let increaseGoal: () -> Void

    private var activeCalories: Int {
        snapshot?.activeCalories ?? 0
    }

    private var dailyGoal: Int {
        snapshot?.dailyGoal ?? displayedGoal
    }

    private var progress: CGFloat {
        guard dailyGoal > 0 else {
            return 0
        }
        return min(CGFloat(activeCalories) / CGFloat(dailyGoal), 1)
    }

    private var progressPercent: Int {
        Int(progress * 100)
    }

    private var remainingCalories: Int {
        max(dailyGoal - activeCalories, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Calories")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.fcMuted)

                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(activeCalories)")
                            .font(.system(size: 44, weight: .heavy))
                            .foregroundColor(.fcInk)
                        Text("kcal")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundColor(.fcMuted)
                    }
                }

                Spacer()

                Image(systemName: "flame.fill")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(.orange)
                    .frame(width: 48, height: 48)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Circle())
            }

            ProgressBar(value: progress, height: 7)

            HStack(alignment: .top) {
                metricColumn(title: "Daily Goal", value: "\(dailyGoal) kcal")
                Spacer()
                metricColumn(title: "Progress", value: "\(progressPercent)%")
                Spacer()
                metricColumn(title: "Remaining", value: "\(remainingCalories) kcal")
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Daily Goal")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundColor(.fcInk)

                    Spacer()

                    Text("\(dailyGoal) kcal")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(.fcInk)
                }

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.fcLine)

                    GeometryReader { proxy in
                        Capsule()
                            .fill(Color.fcInk)
                            .frame(width: max(26, progress * proxy.size.width))
                    }
                }
                .frame(height: 4)

                HStack {
                    Text("Adjust by 25 kcal")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.fcMuted)

                    Spacer()

                    goalAdjustButton(systemName: "minus", action: decreaseGoal)
                    goalAdjustButton(systemName: "plus", action: increaseGoal)
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.fcLine, lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
    }

    private func metricColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.fcMuted)
            Text(value)
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(.fcInk)
        }
    }

    private func goalAdjustButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(.fcInk)
                .frame(width: 34, height: 34)
                .background(Color.fcSoft)
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct HomeWorkoutRecommendationCard: View {
    let snapshot: FitnessDashboardSnapshot?
    let aiWorkout: WorkoutRecommendation?
    let tag: String

    private var title: String {
        aiWorkout?.title ?? snapshot?.recommendationTitle ?? "Workout Recommendations"
    }

    private var subtitle: String {
        if let aiWorkout = aiWorkout {
            return "\(aiWorkout.duration) - Intermediate"
        }

        return snapshot?.recommendationDetail ?? "Waiting for personalized plans"
    }

    private var exercises: [String] {
        aiWorkout?.exercises ?? []
    }

    var body: some View {
        NavigationLink(destination: WorkoutRecommendationView()) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(.fcInk)
                        .frame(width: 42, height: 42)
                        .background(Color.fcSoft)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Workout Recommendations")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(.fcMuted)

                        Text(title)
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(.fcInk)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.fcMuted)
                }

                Text(subtitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.fcMuted)

                Text(tag)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.fcInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.fcSoft)
                    .clipShape(Capsule())

                if !exercises.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(exercises.prefix(3), id: \.self) { exercise in
                            Text("• \(exercise)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.fcMuted)
                        }
                    }
                }
            }
            .padding(22)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.fcLine, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct HealthStatusCard: View {
    let snapshot: FitnessDashboardSnapshot?
    let isRefreshing: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: snapshot?.isUsingMockData == true ? "bolt.horizontal.circle" : "heart.circle")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.fcInk)
                .frame(width: 46, height: 46)
                .background(Color.white)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text("Health Connection")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(.fcInk)

                Text(statusText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.fcMuted)
            }

            Spacer()

            Text(snapshot?.sourceAgent ?? "A2A")
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(.fcInk)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white)
                .clipShape(Capsule())
        }
        .padding(18)
        .background(Color.fcSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var statusText: String {
        if isRefreshing {
            return "Refreshing via A2A..."
        }

        return snapshot?.healthConnectionStatus ?? "Waiting for A2A sync"
    }
}

private struct DailyGoalCard: View {
    let snapshot: FitnessDashboardSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Daily Goal")
                    .font(.system(size: 17, weight: .heavy))
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.fcMuted)
            }

            HStack(spacing: 22) {
                RingProgress(progress: CGFloat(snapshot?.progress ?? 0), lineWidth: 8) {
                    VStack(spacing: 2) {
                        Text("\(snapshot?.activeCalories ?? 0)")
                            .font(.system(size: 22, weight: .heavy))
                        Text("/ \(snapshot?.dailyGoal ?? 700)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.fcMuted)
                    }
                }
                .frame(width: 116, height: 116)

                VStack(spacing: 15) {
                    MacroRow(name: "Active", value: "\(snapshot?.activeCalories ?? 0)", goal: "\(snapshot?.dailyGoal ?? 700) kcal", progress: CGFloat(snapshot?.progress ?? 0))
                    MacroRow(name: "Resting", value: "\(snapshot?.restingCalories ?? 0)", goal: "kcal", progress: 0.75)
                    MacroRow(name: "Total", value: "\(snapshot?.totalCalories ?? 0)", goal: "kcal", progress: 0.82)
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.fcLine, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 5)
    }
}

private struct ActiveEnergyCard: View {
    let snapshot: FitnessDashboardSnapshot?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 18) {
                Label("Today's Active Calories", systemImage: "flame")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.fcInk)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(snapshot?.activeCalories ?? 0)")
                        .font(.system(size: 28, weight: .heavy))
                    Text("/ \(snapshot?.dailyGoal ?? 700) kcal")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(.fcMuted)
                }

                if let snapshot = snapshot {
                    Text("Updated \(snapshot.updatedAt.shortTimeString)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.fcMuted)
                }
            }

            Spacer()

            MultiRingIcon()
                .frame(width: 78, height: 78)
        }
        .padding(24)
        .background(Color.fcSoft)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ProgressPercentageCard: View {
    let snapshot: FitnessDashboardSnapshot?

    private var percent: Int {
        Int((snapshot?.progress ?? 0) * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Progress Percentage")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.fcInk)

                Spacer()

                Text("\(percent)%")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(.fcInk)
            }

            ProgressBar(value: CGFloat(snapshot?.progress ?? 0), height: 8)

            Text("A2A sync keeps this card updated from AppleHealthAgent data.")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.fcMuted)
        }
        .padding(22)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.fcLine, lineWidth: 1))
    }
}

private struct RecommendationEntryCard: View {
    let snapshot: FitnessDashboardSnapshot?

    var body: some View {
        NavigationLink(destination: WorkoutRecommendationView()) {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Recommendation")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.fcMuted)

                    Text(snapshot?.recommendationTitle ?? "Full Body HIIT")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.white)

                    Text(snapshot?.recommendationDetail ?? "Waiting for A2A recommendation")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.72))
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(.fcInk)
                    .frame(width: 48, height: 48)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .padding(22)
            .background(Color.fcInk)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct WorkoutCard: View {
    let title: String
    let meta: String
    let tag: String
    let isDark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(title)
                        .font(.system(size: 17, weight: .heavy))
                    Text(meta)
                        .font(.system(size: 14, weight: .bold))
                        .opacity(0.65)
                }

                Spacer()

                Image(systemName: "figure.mixed.cardio")
                    .opacity(0.70)
            }

            Spacer()

            Text(tag)
                .font(.system(size: 13, weight: .heavy))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isDark ? Color.white.opacity(0.22) : Color.fcSoft)
                .clipShape(Capsule())
        }
        .foregroundColor(isDark ? .white : .fcInk)
        .padding(22)
        .frame(width: 274, height: 160)
        .background(isDark ? Color.fcInk : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(isDark ? Color.clear : Color.fcLine, lineWidth: 1))
    }
}

struct WorkoutPlanExercise: Identifiable {
    let id = UUID()
    let title: String
    let focus: String
    let target: String
    let detail: String
    let formTip: String
    let cameraMove: WorkoutMove?
}

private struct PlanSummaryTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(.fcMuted)

            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(.fcInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.fcSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct WorkoutPlanRow: View {
    let exercise: WorkoutPlanExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: exercise.cameraMove == nil ? "timer" : "camera.viewfinder")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.fcInk)
                    .frame(width: 42, height: 42)
                    .background(Color.fcSoft)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(exercise.title)
                            .font(.system(size: 19, weight: .heavy))
                            .foregroundColor(.fcInk)

                        Spacer()

                        Text(exercise.target)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(.fcInk)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.fcSoft)
                            .clipShape(Capsule())
                    }

                    Text(exercise.focus)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.fcMuted)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(exercise.detail)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.fcInk)

                Text(exercise.formTip)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.fcMuted)
            }

            if let cameraMove = exercise.cameraMove {
                NavigationLink(destination: CameraFeedbackView(selectedMove: cameraMove)) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start with Camera")
                        Spacer()
                        Text("Count reps")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(.white.opacity(0.72))
                    }
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(Color.fcInk)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                NavigationLink(destination: ActiveWorkoutView()) {
                    HStack {
                        Image(systemName: "timer")
                        Text("Start Timer")
                        Spacer()
                        Text("Timed hold")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(.fcMuted)
                    }
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(.fcInk)
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(Color.fcSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.fcLine, lineWidth: 1))
    }
}

private struct MealRow: View {
    let title: String
    let calories: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(.fcInk)
                    Text(calories)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.fcMuted)
                }
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.fcInk)
                    .frame(width: 38, height: 38)
                    .overlay(Circle().stroke(Color.fcLine, lineWidth: 1))
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.fcLine, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct WaterCard: View {
    let glasses: Int
    let decrease: () -> Void
    let increase: () -> Void
    let select: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Label("Water", systemImage: "drop")
                    .font(.system(size: 18, weight: .heavy))
                Spacer()
                Text("\(glasses) / 8 glasses")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.fcMuted)
            }

            HStack(spacing: 8) {
                ForEach(0..<8) { index in
                    Button(action: {
                        select(index + 1)
                    }) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(index < glasses ? Color.fcInk : Color.white.opacity(0.8))
                            .frame(height: 46)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            HStack {
                Text("Tap a bar or adjust by 1 glass")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.fcMuted)

                Spacer()

                waterButton(systemName: "minus", action: decrease)
                waterButton(systemName: "plus", action: increase)
            }
        }
        .padding(24)
        .background(Color.fcSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func waterButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(.fcInk)
                .frame(width: 34, height: 34)
                .background(Color.white)
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct WeeklyActivityCard: View {
    private let values: [CGFloat] = [0.40, 0.64, 0.30, 0.78, 0.50, 0.22, 0.00]
    private let days = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 34) {
            Text("Weekly Activity")
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(.fcInk)

            HStack(alignment: .bottom, spacing: 14) {
                ForEach(values.indices, id: \.self) { index in
                    VStack(spacing: 16) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.fcSoft)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(index == 3 ? Color.fcInk : Color.fcMedium)
                                .frame(height: 116 * values[index])
                        }
                        .frame(height: 116)

                        Text(days[index])
                            .font(.system(size: 14, weight: index == 3 ? .heavy : .bold))
                            .foregroundColor(index == 3 ? .fcInk : .fcMuted)
                    }
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.fcLine, lineWidth: 1))
    }
}

private struct WeightCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text("Body Weight")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundColor(.fcInk)
                Spacer()
                Text("68.5")
                    .font(.system(size: 21, weight: .heavy))
                Text("kg")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.fcMuted)
            }

            LineChartShape()
                .stroke(Color.fcInk, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .frame(height: 130)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.fcInk)
                        .frame(width: 9, height: 9)
                        .offset(x: -12, y: 38)
                }
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.fcLine, lineWidth: 1))
    }
}

private struct MetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.fcMuted)
            Text(value)
                .font(.system(size: 26, weight: .heavy))
                .foregroundColor(.fcInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.fcSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SettingsSectionTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .heavy))
            .foregroundColor(.fcMedium)
    }
}

private struct ProfileStatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(.fcMuted)

            Text(value)
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(.fcInk)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.fcLine, lineWidth: 1))
    }
}

private struct MoreActionRow: View {
    let icon: String
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.fcInk)
                    .frame(width: 40, height: 40)
                    .background(Color.fcSoft)
                    .clipShape(Circle())

                Text(title)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.fcInk)

                Spacer()

                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.fcMuted)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.fcMuted)
            }
            .padding(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct MoreNavigationRow<Destination: View>: View {
    let icon: String
    let title: String
    let value: String
    let destination: Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.fcInk)
                    .frame(width: 40, height: 40)
                    .background(Color.fcSoft)
                    .clipShape(Circle())

                Text(title)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.fcInk)

                Spacer()

                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.fcMuted)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.fcMuted)
            }
            .padding(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 22)
            Text(title)
                .font(.system(size: 18, weight: .bold))
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(FCSwitchStyle())
        }
        .padding(.vertical, 3)
        .overlay(Divider().offset(y: 21), alignment: .bottom)
    }
}

private struct RingProgress<Content: View>: View {
    let progress: CGFloat
    let lineWidth: CGFloat
    let content: Content

    init(progress: CGFloat, lineWidth: CGFloat, @ViewBuilder content: () -> Content) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.content = content()
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.fcSoft, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.fcInk, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            content
        }
    }
}

private struct ProgressBar: View {
    let value: CGFloat
    let height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.fcSoft)
                Capsule()
                    .fill(Color.fcInk)
                    .frame(width: proxy.size.width * value)
            }
        }
        .frame(height: height)
    }
}

private struct MacroRow: View {
    let name: String
    let value: String
    let goal: String
    let progress: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.fcMuted)
                Spacer()
                Text(value)
                    .font(.system(size: 14, weight: .heavy))
                Text("/ \(goal)")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.fcMedium)
            }
            ProgressBar(value: progress, height: 4)
        }
    }
}

private struct FCSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? Color.fcInk : Color.fcLine)
                    .frame(width: 58, height: 34)

                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                    .padding(4)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(configuration.isOn ? "On" : "Off")
    }
}

private struct CircleIconButton: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.fcInk)
            .frame(width: 48, height: 48)
            .background(Color.white)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.fcLine, lineWidth: 1))
    }
}

private struct BackCircleButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(.fcInk)
                .frame(width: 48, height: 48)
                .background(Color.fcSoft)
                .clipShape(Circle())
        }
    }
}

private struct StickFigureMark: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.fcLine, lineWidth: 2)

            Path { path in
                path.move(to: CGPoint(x: 128, y: 68))
                path.addCurve(to: CGPoint(x: 124, y: 132), control1: CGPoint(x: 120, y: 86), control2: CGPoint(x: 122, y: 108))
                path.addCurve(to: CGPoint(x: 150, y: 173), control1: CGPoint(x: 128, y: 150), control2: CGPoint(x: 138, y: 160))
                path.addCurve(to: CGPoint(x: 188, y: 205), control1: CGPoint(x: 164, y: 189), control2: CGPoint(x: 176, y: 201))
                path.move(to: CGPoint(x: 124, y: 132))
                path.addCurve(to: CGPoint(x: 83, y: 167), control1: CGPoint(x: 108, y: 146), control2: CGPoint(x: 96, y: 156))
                path.addCurve(to: CGPoint(x: 44, y: 206), control1: CGPoint(x: 66, y: 176), control2: CGPoint(x: 51, y: 193))
                path.move(to: CGPoint(x: 128, y: 68))
                path.addCurve(to: CGPoint(x: 198, y: 75), control1: CGPoint(x: 156, y: 88), control2: CGPoint(x: 178, y: 94))
                path.addCurve(to: CGPoint(x: 211, y: 58), control1: CGPoint(x: 205, y: 68), control2: CGPoint(x: 209, y: 61))
                path.move(to: CGPoint(x: 128, y: 68))
                path.addCurve(to: CGPoint(x: 63, y: 104), control1: CGPoint(x: 104, y: 88), control2: CGPoint(x: 84, y: 101))
            }
            .stroke(Color.fcInk, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

            ForEach([CGPoint(x: 128, y: 68), CGPoint(x: 198, y: 75), CGPoint(x: 63, y: 104), CGPoint(x: 44, y: 206), CGPoint(x: 188, y: 205)], id: \.x) { point in
                Circle()
                    .fill(Color.fcInk)
                    .frame(width: point.x == 128 ? 34 : 10, height: point.x == 128 ? 34 : 10)
                    .position(point)
            }
        }
    }
}

private struct MultiRingIcon: View {
    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .trim(from: 0.18, to: 0.92)
                    .stroke(index == 2 ? Color.fcInk : Color.fcMedium.opacity(0.45), style: StrokeStyle(lineWidth: CGFloat(7 - index), lineCap: .round))
                    .rotationEffect(.degrees(Double(index) * 16))
                    .padding(CGFloat(index) * 9)
            }
        }
    }
}

private struct FeedbackBubble: View {
    var body: some View {
        Text("Keep your knees behind your toes!")
            .font(.system(size: 14, weight: .heavy))
            .foregroundColor(.fcInk)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(width: 230, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct PoseSkeleton: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        var path = Path()
        path.move(to: p(0.48, 0.08))
        path.addLine(to: p(0.48, 0.66))
        path.move(to: p(0.48, 0.18))
        path.addLine(to: p(0.70, 0.30))
        path.addLine(to: p(0.66, 0.48))
        path.move(to: p(0.48, 0.66))
        path.addLine(to: p(0.36, 0.82))
        path.addLine(to: p(0.34, 1.00))
        path.move(to: p(0.48, 0.66))
        path.addLine(to: p(0.62, 0.85))
        path.addLine(to: p(0.66, 1.00))
        return path
    }
}

private struct LineChartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 4, y: rect.maxY - 34))
        path.addCurve(to: CGPoint(x: rect.midX - 18, y: rect.midY + 4), control1: CGPoint(x: rect.width * 0.22, y: rect.maxY - 24), control2: CGPoint(x: rect.width * 0.28, y: rect.midY + 2))
        path.addCurve(to: CGPoint(x: rect.maxX - 42, y: rect.maxY - 54), control1: CGPoint(x: rect.width * 0.55, y: rect.midY - 24), control2: CGPoint(x: rect.width * 0.76, y: rect.maxY - 26))
        path.addCurve(to: CGPoint(x: rect.maxX - 8, y: rect.maxY - 70), control1: CGPoint(x: rect.maxX - 24, y: rect.maxY - 48), control2: CGPoint(x: rect.maxX - 14, y: rect.maxY - 54))
        return path
    }
}

extension Color {
    static let fcInk = Color(red: 0.055, green: 0.055, blue: 0.055)
    static let fcMuted = Color(red: 0.43, green: 0.43, blue: 0.43)
    static let fcMedium = Color(red: 0.68, green: 0.68, blue: 0.68)
    static let fcLine = Color(red: 0.90, green: 0.90, blue: 0.90)
    static let fcSoft = Color(red: 0.95, green: 0.95, blue: 0.95)
}

private extension Date {
    var shortTimeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: self)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
