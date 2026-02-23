import SwiftUI

struct WorkoutRowView: View {
    let workout: Workout

    private var cardBackground: Color {
        Color(red: 0.03, green: 0.03, blue: 0.05)
    }

    private var normalizedContent: String? {
        guard let content = workout.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            return nil
        }
        return content
    }

    private var summaryText: String? {
        guard let normalizedContent else { return nil }
        if normalizedContent.count <= 150 {
            return normalizedContent
        }
        return String(normalizedContent.prefix(147)) + "..."
    }

    private var displayDurationMinutes: Int? {
        if let duration = workout.durationMinutes, duration > 0 {
            return duration
        }

        let source = "\(workout.title) \(workout.content ?? "")"
        return firstMatchedNumber(pattern: #"(\d{1,3})\s*(?:min|mins|minute|minutes)\b"#, in: source)
    }

    private var displayExerciseCount: Int? {
        if let exerciseCount = workout.exerciseCount, exerciseCount > 0 {
            return exerciseCount
        }

        guard let normalizedContent else { return nil }
        let lines = normalizedContent
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                !line.isEmpty && !line.hasPrefix("-") && !line.hasPrefix("#")
            }

        guard !lines.isEmpty else { return nil }
        return min(lines.count, 30)
    }

    private var difficultyLabel: String? {
        let normalizedDifficulty = workout.difficulty?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if let normalizedDifficulty, !normalizedDifficulty.isEmpty {
            return normalizedDifficulty
        }

        let source = "\(workout.title) \(workout.content ?? "")".lowercased()
        if source.contains("beginner") { return "beginner" }
        if source.contains("advanced") || source.contains("elite") { return "advanced" }
        if source.contains("intermediate") { return "intermediate" }
        return nil
    }

    private var displayImageURL: URL? {
        guard let rawImageURL = workout.imageURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawImageURL.isEmpty else {
            return nil
        }

        if rawImageURL.hasPrefix("/") {
            return URL(fileURLWithPath: rawImageURL)
        }

        return URL(string: rawImageURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let displayImageURL {
                AsyncImage(url: displayImageURL) { phase in
                    switch phase {
                    case .empty:
                        imagePlaceholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 170)
                            .clipped()
                    case .failure:
                        imagePlaceholder
                    @unknown default:
                        imagePlaceholder
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(workout.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(3)

                if let summaryText {
                    Text(summaryText)
                        .font(.body)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(3)
                }

                HStack(spacing: 18) {
                    if let durationMinutes = displayDurationMinutes {
                        Label {
                            Text("\(durationMinutes) min")
                        } icon: {
                            Image(systemName: "clock")
                        }
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                    }

                    if let exerciseCount = displayExerciseCount {
                        Label {
                            Text("\(exerciseCount) exercises")
                        } icon: {
                            Image(systemName: "figure.strengthtraining.traditional")
                        }
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                    }
                }

                if let difficultyLabel {
                    Text(difficultyLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(red: 0.98, green: 0.82, blue: 0.21))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.28, green: 0.22, blue: 0.02))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                Divider()
                    .overlay(Color.white.opacity(0.18))

                Text("Added \(workout.createdAt.formatted(.dateTime.month(.defaultDigits).day().year()))")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(AppTheme.cardBackground)
            .frame(height: 170)
            .overlay {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(AppTheme.secondaryText)
            }
    }

    private func firstMatchedNumber(pattern: String, in source: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        guard let match = regex.firstMatch(in: source, options: [], range: range),
              let captureRange = Range(match.range(at: 1), in: source) else {
            return nil
        }

        return Int(source[captureRange])
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            WorkoutRowView(workout: Workout(
                title: "This Week's Workout - Endurance Builder",
                content: "A high-intensity conditioning workout combining aerobic intervals with functional strength movements.",
                source: .manual,
                durationMinutes: 55,
                exerciseCount: 9,
                difficulty: "advanced"
            ))

            WorkoutRowView(workout: Workout(
                title: "30-Minute Bodyweight Full Body Blast",
                content: "High-intensity bodyweight circuit targeting all major muscle groups. Perfect for building work capacity.",
                source: .instagram,
                durationMinutes: 30,
                exerciseCount: 7,
                difficulty: "advanced"
            ))
        }
        .padding()
    }
    .background(AppTheme.background)
    .appDarkTheme()
}
