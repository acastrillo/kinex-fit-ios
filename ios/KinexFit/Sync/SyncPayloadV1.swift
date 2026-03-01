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
    /// Kept for backend compatibility where `workoutId` is expected.
    let workoutId: String
    let title: String
    let content: String?
    let enhancementSourceText: String?
    let source: WorkoutSource
    let durationMinutes: Int?
    let exerciseCount: Int?
    let difficulty: String?
    let imageURL: String?
    let sourceURL: String?
    let sourceAuthor: String?
    let scheduledDate: String?
    let scheduledTime: String?
    let status: WorkoutScheduleStatus?
    let completedDate: String?
    let completedAt: String?
    let durationSeconds: Int?
    let createdAt: Date
    let updatedAt: Date

    init(workout: Workout) {
        id = workout.id
        workoutId = workout.id
        title = workout.title
        content = workout.content
        enhancementSourceText = workout.enhancementSourceText
        source = workout.source
        durationMinutes = workout.durationMinutes
        exerciseCount = workout.exerciseCount
        difficulty = workout.difficulty
        imageURL = workout.imageURL
        sourceURL = workout.sourceURL
        sourceAuthor = workout.sourceAuthor
        scheduledDate = workout.scheduledDate
        scheduledTime = workout.scheduledTime
        status = workout.status
        completedDate = workout.completedDate
        completedAt = workout.completedAt
        durationSeconds = workout.durationSeconds
        createdAt = workout.createdAt
        updatedAt = workout.updatedAt
    }
}
