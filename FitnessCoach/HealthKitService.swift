import Foundation
import HealthKit
import SwiftUI

struct HealthSampleData {
    let steps: Int
    let activeCalories: Int
    let restingCalories: Int
    let heartRate: Int
}

enum HealthConnectionState: String {
    case connected = "Connected"
    case unavailable = "Unavailable"
    case permissionNeeded = "Permission Needed"
    case denied = "Permission Denied"
    case noData = "No Health Data"
}

final class HealthKitService: ObservableObject {
    private let healthStore = HKHealthStore()
        @Published var healthSampleData: HealthSampleData?
        @Published var errorMessage: String?
    
        func sendToBackend() {
            // Implementation for sending data to backend
        }
    
        func mockFallback() {
            // Mock fallback implementation
            healthSampleData = HealthSampleData(steps: 1000, activeCalories: 200, restingCalories: 1500, heartRate: 70)
            errorMessage = nil
        }

    var connectionState: HealthConnectionState {
        guard HKHealthStore.isHealthDataAvailable(),
              let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return .unavailable
        }

        switch healthStore.authorizationStatus(for: activeEnergyType) {
        case .sharingAuthorized:
            return .connected
        case .notDetermined:
            return .permissionNeeded
        case .sharingDenied:
            return .denied
        @unknown default:
            return .permissionNeeded
        }
    }

    func requestPermissionIfNeeded() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }

        let readTypes: Set<HKObjectType> = Set([
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .heartRate)
        ].compactMap { $0 as HKObjectType? })

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        } catch {
            print("HealthKit permission failed: \(error.localizedDescription)")
        }
    }

    func fetchTodaySamples() async -> HealthSampleData? {
        guard HKHealthStore.isHealthDataAvailable() else {
            return nil
        }

        await requestPermissionIfNeeded()

        async let steps = fetchCumulativeQuantity(identifier: .stepCount, unit: .count())
        async let active = fetchCumulativeQuantity(identifier: .activeEnergyBurned, unit: .kilocalorie())
        async let resting = fetchCumulativeQuantity(identifier: .basalEnergyBurned, unit: .kilocalorie())
        async let heartRate = fetchAverageQuantity(identifier: .heartRate, unit: HKUnit.count().unitDivided(by: .minute()))

        let values = await (steps, active, resting, heartRate)

        guard values.0 != nil || values.1 != nil || values.2 != nil || values.3 != nil else {
            return nil
        }

        return HealthSampleData(
            steps: Int(values.0 ?? 0),
            activeCalories: Int(values.1 ?? 0),
            restingCalories: Int(values.2 ?? 0),
            heartRate: Int(values.3 ?? 0)
        )
    }

    private func fetchCumulativeQuantity(identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        await fetchStatistics(identifier: identifier, options: .cumulativeSum) { statistics in
            statistics.sumQuantity()?.doubleValue(for: unit)
        }
    }

    private func fetchAverageQuantity(identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        await fetchStatistics(identifier: identifier, options: .discreteAverage) { statistics in
            statistics.averageQuantity()?.doubleValue(for: unit)
        }
    }

    private func fetchStatistics(
        identifier: HKQuantityTypeIdentifier,
        options: HKStatisticsOptions,
        value: @escaping (HKStatistics) -> Double?
    ) async -> Double? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: Date().startOfDay,
            end: Date().endOfDay,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: options
            ) { _, statistics, error in
                if let error = error {
                    if !Self.isNoDataError(error) {
                        print("HealthKit query failed: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: nil)
                    return
                }

                guard let statistics = statistics else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: value(statistics))
            }

            healthStore.execute(query)
        }
    }

    private static func isNoDataError(_ error: Error) -> Bool {
        if let healthError = error as? HKError, healthError.code == .errorNoData {
            return true
        }

        return (error as NSError).localizedDescription == "No data available for the specified predicate."
    }
}

private extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) ?? self
    }
}
