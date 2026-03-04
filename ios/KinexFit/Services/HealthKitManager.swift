import Foundation
import HealthKit
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "HealthKit")

/// Manages HealthKit integration for workout and body metrics sync
@MainActor
final class HealthKitManager: NSObject, ObservableObject {
    @Published var isAuthorized: Bool = false
    @Published var authorizationError: Error?
    @Published var lastSyncDate: Date?

    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()

    // MARK: - Authorization

    /// Request HealthKit permissions
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationError = NSError(
                domain: "HealthKitManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available on this device"]
            )
            logger.error("HealthKit not available")
            return
        }

        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
            HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKQuantityType.quantityType(forIdentifier: .leanBodyMass)!,
        ]

        let typesToRead: Set<HKObjectType> = typesToShare

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            isAuthorized = true
            authorizationError = nil
            logger.info("HealthKit authorization granted")
        } catch {
            authorizationError = error
            logger.error("HealthKit authorization failed: \(error.localizedDescription)")
        }
    }

    /// Check if HealthKit is authorized
    func checkAuthorization() {
        let workoutType = HKObjectType.workoutType()
        let status = healthStore.authorizationStatus(for: workoutType)
        isAuthorized = status == .sharingAuthorized
        logger.debug("HealthKit authorization status: \(String(describing: status))")
    }

    // MARK: - Workout Sync

    /// Save workout to HealthKit
    func saveWorkout(
        duration: TimeInterval,
        energyBurned: Double,
        activityType: HKWorkoutActivityType = .mixedCardio,
        metadata: [String: Any]? = nil
    ) async throws {
        guard isAuthorized else {
            throw NSError(domain: "HealthKitManager", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "HealthKit not authorized"
            ])
        }

        let startDate = Date(timeIntervalSinceNow: -duration)
        let endDate = Date()

        let energyQuantity = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: energyBurned)
        var energySamples: [HKSample] = []

        if energyBurned > 0 {
            let energySample = HKQuantitySample(
                type: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
                quantity: energyQuantity,
                start: startDate,
                end: endDate
            )
            energySamples = [energySample]
        }

        let workout = HKWorkout(
            activityType: activityType,
            start: startDate,
            end: endDate,
            duration: duration,
            totalEnergyBurned: energyQuantity,
            totalDistance: nil,
            metadata: metadata
        )

        var samplesToSave: [HKSample] = [workout]
        samplesToSave.append(contentsOf: energySamples)

        try await healthStore.save(samplesToSave)
        lastSyncDate = Date()
        logger.info("Workout saved to HealthKit: \(duration)s, \(energyBurned) kcal")
    }

    // MARK: - Body Metrics Sync

    /// Save body metric to HealthKit
    func saveBodyMetric(
        type: BodyMetricType,
        value: Double,
        unit: HKUnit
    ) async throws {
        guard isAuthorized else {
            throw NSError(domain: "HealthKitManager", code: -2)
        }

        let quantity = HKQuantity(unit: unit, doubleValue: value)
        let sample = HKQuantitySample(
            type: type.hkQuantityType(),
            quantity: quantity,
            start: Date(),
            end: Date()
        )

        try await healthStore.save([sample])
        lastSyncDate = Date()
        logger.info("Body metric saved to HealthKit: \(type.displayName) = \(value)")
    }

    // MARK: - Query Workouts

    /// Fetch recent workouts from HealthKit
    func fetchRecentWorkouts(days: Int = 30) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(
            withStart: Date(timeIntervalSinceNow: -Double(days) * 24 * 3600),
            end: Date(),
            options: .strictStartDate
        )
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [
                    NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
                ]
            ) { _, samples, error in
                if let error = error {
                    logger.error("Failed to fetch workouts: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
                }
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - Body Metric Type

enum BodyMetricType: String, CaseIterable {
    case weight
    case bodyFatPercentage
    case leanBodyMass

    var displayName: String {
        switch self {
        case .weight: return "Weight"
        case .bodyFatPercentage: return "Body Fat %"
        case .leanBodyMass: return "Lean Body Mass"
        }
    }

    func hkQuantityType() -> HKQuantityType {
        switch self {
        case .weight:
            return HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        case .bodyFatPercentage:
            return HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!
        case .leanBodyMass:
            return HKQuantityType.quantityType(forIdentifier: .leanBodyMass)!
        }
    }

    func unit() -> HKUnit {
        switch self {
        case .weight: return HKUnit.pound()
        case .bodyFatPercentage: return HKUnit.percent()
        case .leanBodyMass: return HKUnit.pound()
        }
    }
}
