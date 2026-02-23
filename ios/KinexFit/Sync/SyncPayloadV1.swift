import Foundation

/// Explicit sync payload schema for sync_queue entries.
/// Keeps per-operation shapes stable and avoids implicit model decoding assumptions.
struct SyncPayloadV1: Codable {
    let workoutId: String?
    let workout: SyncWorkout?

    static func createOrUpdate(workout: Workout) -> SyncPayloadV1 {
        SyncPayloadV1(workoutId: nil, workout: SyncWorkout(workout: workout))
    }

    static func delete(workoutId: String) -> SyncPayloadV1 {
        SyncPayloadV1(workoutId: workoutId, workout: nil)
    }
}

/// Stable workout payload used by sync operations.
/// Keep this schema backward compatible with server expectations.
struct SyncWorkout: Codable {
    let id: String
    let title: String
    let content: String?
    let source: WorkoutSource
    let createdAt: Date
    let updatedAt: Date

    init(workout: Workout) {
        id = workout.id
        title = workout.title
        content = workout.content
        source = workout.source
        createdAt = workout.createdAt
        updatedAt = workout.updatedAt
    }
}
