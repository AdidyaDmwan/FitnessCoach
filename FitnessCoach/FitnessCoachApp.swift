//
//  FitnessCoachApp.swift
//  FitnessCoach
//
//  Created by 17 on 2026/5/13.
//

import SwiftUI

@main
struct FitnessCoachApp: App {
    @StateObject private var healthKitService = HealthKitService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitService)
        }
    }
}
