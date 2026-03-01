import SwiftUI

enum WorkoutSessionTimerType: String, CaseIterable, Identifiable, Codable {
    case standard
    case emom
    case amrap

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .emom: return "EMOM"
        case .amrap: return "AMRAP"
        }
    }

    var iconName: String {
        switch self {
        case .standard: return "clock"
        case .emom: return "clock.badge.checkmark"
        case .amrap: return "flame"
        }
    }

    var helperText: String {
        switch self {
        case .standard: return "Simple count-up stopwatch."
        case .emom: return "Every minute starts a new interval."
        case .amrap: return "Complete as many rounds as possible in a fixed time."
        }
    }
}

struct WorkoutSessionTimerConfiguration: Equatable, Hashable, Codable {
    static let defaultDurationMinutes = 20
    static let standard = WorkoutSessionTimerConfiguration(
        type: .standard,
        durationMinutes: defaultDurationMinutes
    )

    var type: WorkoutSessionTimerType
    var durationMinutes: Int

    var usesCountdown: Bool {
        type != .standard
    }

    var clampedDurationMinutes: Int {
        min(max(durationMinutes, 1), 240)
    }

    var selectionLabel: String {
        if usesCountdown {
            return "\(type.displayName) • \(clampedDurationMinutes)m"
        }
        return "Standard"
    }

    var accessibilityLabel: String {
        if usesCountdown {
            return "\(type.displayName) timer set for \(clampedDurationMinutes) minutes"
        }
        return "Standard count-up timer"
    }

    func normalized() -> WorkoutSessionTimerConfiguration {
        WorkoutSessionTimerConfiguration(type: type, durationMinutes: clampedDurationMinutes)
    }
}

extension WorkoutSessionTimerConfiguration {
    static func recommended(from presentation: WorkoutContentPresentation) -> WorkoutSessionTimerConfiguration {
        let fallbackDuration = inferredDurationFallback(from: presentation)

        if let firstBlock = presentation.blocks.first {
            switch firstBlock.type {
            case .emom:
                return WorkoutSessionTimerConfiguration(
                    type: .emom,
                    durationMinutes: parseDurationMinutes(from: firstBlock.value) ?? fallbackDuration
                ).normalized()
            case .amrap:
                return WorkoutSessionTimerConfiguration(
                    type: .amrap,
                    durationMinutes: parseDurationMinutes(from: firstBlock.value) ?? fallbackDuration
                ).normalized()
            }
        }

        if rawContentContainsEMOM(presentation.rawContent) {
            return WorkoutSessionTimerConfiguration(
                type: .emom,
                durationMinutes: parseDurationMinutes(from: presentation.rawContent) ?? fallbackDuration
            ).normalized()
        }

        if rawContentContainsAMRAP(presentation.rawContent) {
            return WorkoutSessionTimerConfiguration(
                type: .amrap,
                durationMinutes: parseDurationMinutes(from: presentation.rawContent) ?? fallbackDuration
            ).normalized()
        }

        return .standard
    }

    private static func inferredDurationFallback(from presentation: WorkoutContentPresentation) -> Int {
        let estimated = presentation.estimatedDurationMinutes ?? defaultDurationMinutes
        return min(max(estimated, 1), 240)
    }

    private static func parseDurationMinutes(from rawValue: String?) -> Int? {
        guard let rawValue else { return nil }
        return parseDurationMinutes(from: rawValue)
    }

    private static func parseDurationMinutes(from source: String) -> Int? {
        if let minuteMatch = firstIntegerMatch(
            in: source,
            pattern: #"(?i)\b(\d{1,3})\s*(?:m|min|mins|minute|minutes)\b"#
        ) {
            return minuteMatch
        }

        if let compactMinuteMatch = firstIntegerMatch(
            in: source,
            pattern: #"(?i)\b(\d{1,3})m\b"#
        ) {
            return compactMinuteMatch
        }

        if let clockMatch = capture(in: source, pattern: #"(?i)\b(\d{1,2}):(\d{2})\b"#),
           let minutes = Int(clockMatch[0]) {
            return max(minutes, 1)
        }

        return nil
    }

    private static func rawContentContainsEMOM(_ source: String) -> Bool {
        let lowered = source.lowercased()
        if lowered.contains("every minute on the minute") {
            return true
        }
        return lowered.range(
            of: #"(?i)\bemom\b|\be\d{1,2}mom\b"#,
            options: .regularExpression
        ) != nil
    }

    private static func rawContentContainsAMRAP(_ source: String) -> Bool {
        source.range(of: #"(?i)\bamrap\b"#, options: .regularExpression) != nil
    }

    private static func firstIntegerMatch(in source: String, pattern: String) -> Int? {
        capture(in: source, pattern: pattern).flatMap { Int($0[0]) }
    }

    private static func capture(in source: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        guard let match = regex.firstMatch(in: source, options: [], range: range) else {
            return nil
        }

        var captures: [String] = []
        for index in 1..<match.numberOfRanges {
            let captureRange = match.range(at: index)
            guard let swiftRange = Range(captureRange, in: source) else {
                captures.append("")
                continue
            }
            captures.append(String(source[swiftRange]))
        }
        return captures
    }
}

struct WorkoutTimerSelectionSheet: View {
    let recommended: WorkoutSessionTimerConfiguration
    let onApply: (WorkoutSessionTimerConfiguration) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var draftType: WorkoutSessionTimerType
    @State private var draftDurationMinutes: Int

    init(
        current: WorkoutSessionTimerConfiguration,
        recommended: WorkoutSessionTimerConfiguration,
        onApply: @escaping (WorkoutSessionTimerConfiguration) -> Void
    ) {
        let normalizedCurrent = current.normalized()
        self.recommended = recommended.normalized()
        self.onApply = onApply
        _draftType = State(initialValue: normalizedCurrent.type)
        _draftDurationMinutes = State(initialValue: normalizedCurrent.clampedDurationMinutes)
    }

    private var draftConfiguration: WorkoutSessionTimerConfiguration {
        WorkoutSessionTimerConfiguration(
            type: draftType,
            durationMinutes: draftDurationMinutes
        ).normalized()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose the timer that matches this session.")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.secondaryText)

                    VStack(spacing: 10) {
                        ForEach(WorkoutSessionTimerType.allCases) { type in
                            timerTypeCard(type)
                        }
                    }

                    if draftConfiguration.usesCountdown {
                        durationCard
                    }

                    if recommended != draftConfiguration {
                        Button {
                            draftType = recommended.type
                            draftDurationMinutes = recommended.clampedDurationMinutes
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                Text("Use Recommended: \(recommended.selectionLabel)")
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                            }
                            .padding(12)
                            .kinexCard(cornerRadius: 12, fill: AppTheme.cardBackgroundElevated)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Workout Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.secondaryText)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        onApply(draftConfiguration)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func timerTypeCard(_ type: WorkoutSessionTimerType) -> some View {
        let isSelected = draftType == type

        return Button {
            draftType = type
            if !typeIsCountdown(type) {
                draftDurationMinutes = WorkoutSessionTimerConfiguration.defaultDurationMinutes
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: type.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.secondaryText)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(type.helperText)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.accent)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }
            .padding(12)
            .kinexCard(cornerRadius: 12, fill: AppTheme.cardBackgroundElevated)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.35) : AppTheme.cardBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.displayName)
        .accessibilityHint(type.helperText)
    }

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Duration")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)

            HStack(spacing: 10) {
                Stepper(value: $draftDurationMinutes, in: 1...240) {
                    Text("\(draftDurationMinutes) min")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .tint(AppTheme.accent)
            }
        }
        .padding(12)
        .kinexCard(cornerRadius: 12, fill: AppTheme.cardBackgroundElevated)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        }
    }

    private func typeIsCountdown(_ type: WorkoutSessionTimerType) -> Bool {
        type != .standard
    }
}

