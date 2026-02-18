import SwiftUI

struct WorkoutRowView: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(workout.title)
                    .font(.headline)
                    .lineLimit(2)

                Spacer()

                SourceBadge(source: workout.source)
            }

            if let content = workout.content, !content.isEmpty {
                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Text(workout.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if !Calendar.current.isDateInToday(workout.createdAt) {
                    Text(workout.createdAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Source Badge

private struct SourceBadge: View {
    let source: WorkoutSource

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: source.iconName)
            Text(source.displayName)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.secondary.opacity(0.15))
        .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview {
    List {
        WorkoutRowView(workout: Workout(
            title: "Push Day - Chest and Triceps",
            content: "Bench Press 4x8\nIncline DB Press 3x10\nCable Flyes 3x12\nTricep Pushdowns 3x15",
            source: .manual
        ))

        WorkoutRowView(workout: Workout(
            title: "HIIT Session",
            content: "20 min AMRAP",
            source: .instagram
        ))

        WorkoutRowView(workout: Workout(
            title: "CrossFit WOD - Fran",
            content: "21-15-9\nThrusters 95/65\nPull-ups",
            source: .ocr
        ))

        WorkoutRowView(workout: Workout(
            title: "Quick Core Workout",
            content: nil,
            source: .imported
        ))
    }
}
