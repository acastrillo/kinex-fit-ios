import SwiftUI

enum WorkoutSessionTimerType: String, CaseIterable, Identifiable, Codable {
    case standard
    case interval
    case hiit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .interval: return "Interval"
        case .hiit: return "HIIT"
        }
    }

    var iconName: String {
        switch self {
        case .standard: return "clock"
        case .interval: return "timer"
        case .hiit: return "bolt"
        }
    }

    var helperText: String {
        switch self {
        case .standard:
            return "Simple count-up stopwatch."
        case .interval:
            return "Alternates work and rest blocks for a fixed number of rounds."
        case .hiit:
            return "High-intensity intervals with shorter rests and transition alerts."
        }
    }
}

struct WorkoutSessionTimerPreset: Identifiable, Hashable, Codable {
    let id: String
    let type: WorkoutSessionTimerType
    let name: String
    let workSeconds: Int
    let restSeconds: Int
    let rounds: Int

    var protocolLabel: String {
        "\(workSeconds)s / \(restSeconds)s x \(rounds)"
    }
}

extension WorkoutSessionTimerPreset {
    static let intervalPresets: [WorkoutSessionTimerPreset] = [
        WorkoutSessionTimerPreset(
            id: "interval-strength",
            type: .interval,
            name: "Strength Builder",
            workSeconds: 60,
            restSeconds: 30,
            rounds: 10
        ),
        WorkoutSessionTimerPreset(
            id: "interval-conditioning",
            type: .interval,
            name: "Conditioning",
            workSeconds: 45,
            restSeconds: 15,
            rounds: 12
        ),
        WorkoutSessionTimerPreset(
            id: "interval-endurance",
            type: .interval,
            name: "Endurance",
            workSeconds: 90,
            restSeconds: 30,
            rounds: 8
        ),
    ]

    static let hiitPresets: [WorkoutSessionTimerPreset] = [
        WorkoutSessionTimerPreset(
            id: "hiit-tabata",
            type: .hiit,
            name: "Tabata",
            workSeconds: 20,
            restSeconds: 10,
            rounds: 8
        ),
        WorkoutSessionTimerPreset(
            id: "hiit-power",
            type: .hiit,
            name: "Power 40/20",
            workSeconds: 40,
            restSeconds: 20,
            rounds: 10
        ),
        WorkoutSessionTimerPreset(
            id: "hiit-performance",
            type: .hiit,
            name: "Performance 45/15",
            workSeconds: 45,
            restSeconds: 15,
            rounds: 12
        ),
    ]

    static var allPresets: [WorkoutSessionTimerPreset] {
        intervalPresets + hiitPresets
    }

    static func presets(for type: WorkoutSessionTimerType) -> [WorkoutSessionTimerPreset] {
        switch type {
        case .standard:
            return []
        case .interval:
            return intervalPresets
        case .hiit:
            return hiitPresets
        }
    }

    static func defaultPreset(for type: WorkoutSessionTimerType) -> WorkoutSessionTimerPreset? {
        presets(for: type).first
    }

    static func preset(withID id: String?) -> WorkoutSessionTimerPreset? {
        guard let id else { return nil }
        return allPresets.first { $0.id == id }
    }
}

struct WorkoutSessionTimerConfiguration: Equatable, Hashable, Codable {
    static let defaultWorkSeconds = 45
    static let defaultRestSeconds = 15
    static let defaultRounds = 10
    static let standard = WorkoutSessionTimerConfiguration(type: .standard)

    var type: WorkoutSessionTimerType
    var workSeconds: Int
    var restSeconds: Int
    var rounds: Int
    var presetID: String?

    init(
        type: WorkoutSessionTimerType,
        workSeconds: Int = defaultWorkSeconds,
        restSeconds: Int = defaultRestSeconds,
        rounds: Int = defaultRounds,
        presetID: String? = nil
    ) {
        self.type = type
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.rounds = rounds
        self.presetID = presetID
    }

    var usesCountdown: Bool {
        type != .standard
    }

    var clampedWorkSeconds: Int {
        min(max(workSeconds, 5), 600)
    }

    var clampedRestSeconds: Int {
        min(max(restSeconds, 0), 300)
    }

    var clampedRounds: Int {
        min(max(rounds, 1), 60)
    }

    var intervalSummary: String {
        "\(clampedWorkSeconds)s / \(clampedRestSeconds)s x \(clampedRounds)"
    }

    var totalDurationSeconds: Int {
        guard usesCountdown else { return 0 }
        let totalWork = clampedWorkSeconds * clampedRounds
        let totalRest = clampedRestSeconds * max(clampedRounds - 1, 0)
        return totalWork + totalRest
    }

    var selectionLabel: String {
        switch type {
        case .standard:
            return "Standard"
        case .interval, .hiit:
            if let preset = WorkoutSessionTimerPreset.preset(withID: presetID), matchesPreset(preset) {
                return "\(type.displayName) • \(preset.name)"
            }
            return "\(type.displayName) • \(intervalSummary)"
        }
    }

    var accessibilityLabel: String {
        switch type {
        case .standard:
            return "Standard count-up timer"
        case .interval, .hiit:
            return "\(type.displayName) timer with \(clampedRounds) rounds, \(clampedWorkSeconds) seconds work and \(clampedRestSeconds) seconds rest"
        }
    }

    func normalized() -> WorkoutSessionTimerConfiguration {
        var normalizedType = type
        var normalizedWork = clampedWorkSeconds
        var normalizedRest = clampedRestSeconds
        var normalizedRounds = clampedRounds
        var normalizedPresetID = presetID

        if type == .standard {
            normalizedWork = WorkoutSessionTimerConfiguration.defaultWorkSeconds
            normalizedRest = WorkoutSessionTimerConfiguration.defaultRestSeconds
            normalizedRounds = WorkoutSessionTimerConfiguration.defaultRounds
            normalizedPresetID = nil
        } else if let preset = WorkoutSessionTimerPreset.preset(withID: normalizedPresetID) {
            if preset.type != normalizedType || !matchesPreset(preset) {
                normalizedPresetID = nil
            }
        }

        if normalizedType != .standard,
           WorkoutSessionTimerPreset.presets(for: normalizedType).isEmpty {
            normalizedType = .interval
        }

        return WorkoutSessionTimerConfiguration(
            type: normalizedType,
            workSeconds: normalizedWork,
            restSeconds: normalizedRest,
            rounds: normalizedRounds,
            presetID: normalizedPresetID
        )
    }

    func applyingPreset(_ preset: WorkoutSessionTimerPreset) -> WorkoutSessionTimerConfiguration {
        WorkoutSessionTimerConfiguration(
            type: preset.type,
            workSeconds: preset.workSeconds,
            restSeconds: preset.restSeconds,
            rounds: preset.rounds,
            presetID: preset.id
        ).normalized()
    }

    func matchesPreset(_ preset: WorkoutSessionTimerPreset) -> Bool {
        type == preset.type
            && clampedWorkSeconds == preset.workSeconds
            && clampedRestSeconds == preset.restSeconds
            && clampedRounds == preset.rounds
    }
}

extension WorkoutSessionTimerConfiguration {
    static func recommended(from presentation: WorkoutContentPresentation) -> WorkoutSessionTimerConfiguration {
        let raw = presentation.rawContent
        let lowered = raw.lowercased()

        if lowered.contains("tabata") {
            if let tabata = WorkoutSessionTimerPreset.preset(withID: "hiit-tabata") {
                return WorkoutSessionTimerConfiguration(type: .hiit).applyingPreset(tabata)
            }
        }

        if let inferredBlock = presentation.blocks.first {
            switch inferredBlock.type {
            case .amrap:
                let basePreset = WorkoutSessionTimerPreset.defaultPreset(for: .hiit)
                var config = basePreset.map {
                    WorkoutSessionTimerConfiguration(type: .hiit).applyingPreset($0)
                } ?? WorkoutSessionTimerConfiguration(type: .hiit)

                if let duration = parseDurationMinutes(from: inferredBlock.value) ?? parseDurationMinutes(from: raw) {
                    // Approximate AMRAP as minute-based rounds with short reset windows.
                    config.rounds = duration
                    config.workSeconds = 45
                    config.restSeconds = 15
                    config.presetID = nil
                }
                return config.normalized()
            case .emom:
                let basePreset = WorkoutSessionTimerPreset.defaultPreset(for: .interval)
                var config = basePreset.map {
                    WorkoutSessionTimerConfiguration(type: .interval).applyingPreset($0)
                } ?? WorkoutSessionTimerConfiguration(type: .interval)

                if let duration = parseDurationMinutes(from: inferredBlock.value) ?? parseDurationMinutes(from: raw) {
                    // EMOM maps to one round per minute.
                    config.rounds = duration
                    config.workSeconds = 45
                    config.restSeconds = 15
                    config.presetID = nil
                }
                return config.normalized()
            }
        }

        let parsedWorkRest = parseWorkRestSeconds(from: raw)
        let parsedRounds = parseRounds(from: raw) ?? presentation.rounds

        if let parsedWorkRest {
            let isHIIT = rawContainsHIIT(lowered)
            let timerType: WorkoutSessionTimerType = isHIIT ? .hiit : .interval
            return WorkoutSessionTimerConfiguration(
                type: timerType,
                workSeconds: parsedWorkRest.work,
                restSeconds: parsedWorkRest.rest,
                rounds: parsedRounds ?? WorkoutSessionTimerConfiguration.defaultRounds,
                presetID: nil
            ).normalized()
        }

        if rawContainsEMOM(lowered) {
            let rounds = parseDurationMinutes(from: raw) ?? parsedRounds ?? WorkoutSessionTimerConfiguration.defaultRounds
            return WorkoutSessionTimerConfiguration(
                type: .interval,
                workSeconds: 45,
                restSeconds: 15,
                rounds: rounds,
                presetID: nil
            ).normalized()
        }

        if rawContainsHIIT(lowered) || rawContainsAMRAP(lowered) {
            if let preset = WorkoutSessionTimerPreset.defaultPreset(for: .hiit) {
                var config = WorkoutSessionTimerConfiguration(type: .hiit).applyingPreset(preset)
                if let parsedRounds {
                    config.rounds = parsedRounds
                    config.presetID = nil
                }
                return config.normalized()
            }
            return WorkoutSessionTimerConfiguration(type: .hiit).normalized()
        }

        if let rounds = presentation.rounds,
           rounds > 1,
           let rest = presentation.restSeconds {
            return WorkoutSessionTimerConfiguration(
                type: .interval,
                workSeconds: 45,
                restSeconds: rest,
                rounds: rounds,
                presetID: nil
            ).normalized()
        }

        return .standard
    }

    private static func parseWorkRestSeconds(from source: String) -> (work: Int, rest: Int)? {
        if let slash = capture(in: source, pattern: #"(?i)\b(\d{1,3})\s*[/:-]\s*(\d{1,3})\b"#),
           let work = Int(slash[0]),
           let rest = Int(slash[1]) {
            return (work, rest)
        }

        if let explicit = capture(
            in: source,
            pattern: #"(?i)\b(\d{1,3})\s*(?:s|sec|secs|second|seconds)\s*(?:work|on)\b[^0-9]{0,16}\b(\d{1,3})\s*(?:s|sec|secs|second|seconds)\s*(?:rest|off)\b"#
        ),
           let work = Int(explicit[0]),
           let rest = Int(explicit[1]) {
            return (work, rest)
        }

        if let compact = capture(
            in: source,
            pattern: #"(?i)\bwork\s*(\d{1,3})\s*(?:s|sec|secs|second|seconds)\b[^0-9]{0,16}\brest\s*(\d{1,3})\s*(?:s|sec|secs|second|seconds)\b"#
        ),
           let work = Int(compact[0]),
           let rest = Int(compact[1]) {
            return (work, rest)
        }

        return nil
    }

    private static func parseRounds(from source: String) -> Int? {
        if let multiplier = firstIntegerMatch(in: source, pattern: #"(?i)\bx\s*(\d{1,2})\b"#) {
            return multiplier
        }

        if let rounds = firstIntegerMatch(in: source, pattern: #"(?i)\b(\d{1,2})\s*rounds?\b"#) {
            return rounds
        }

        return nil
    }

    private static func parseDurationMinutes(from source: String?) -> Int? {
        guard let source else { return nil }
        return parseDurationMinutes(from: source)
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

    private static func rawContainsHIIT(_ lowered: String) -> Bool {
        lowered.contains("hiit") || lowered.contains("tabata")
    }

    private static func rawContainsEMOM(_ lowered: String) -> Bool {
        if lowered.contains("every minute on the minute") {
            return true
        }
        return lowered.range(
            of: #"(?i)\bemom\b|\be\d{1,2}mom\b"#,
            options: .regularExpression
        ) != nil
    }

    private static func rawContainsAMRAP(_ lowered: String) -> Bool {
        lowered.range(of: #"(?i)\bamrap\b"#, options: .regularExpression) != nil
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

    @State private var draftConfiguration: WorkoutSessionTimerConfiguration
    @State private var isApplyingPreset = false

    init(
        current: WorkoutSessionTimerConfiguration,
        recommended: WorkoutSessionTimerConfiguration,
        onApply: @escaping (WorkoutSessionTimerConfiguration) -> Void
    ) {
        let normalizedCurrent = current.normalized()
        self.recommended = recommended.normalized()
        self.onApply = onApply
        _draftConfiguration = State(initialValue: normalizedCurrent)
    }

    private var availablePresets: [WorkoutSessionTimerPreset] {
        WorkoutSessionTimerPreset.presets(for: draftConfiguration.type)
    }

    private var selectedPresetID: String? {
        if let preset = availablePresets.first(where: { draftConfiguration.matchesPreset($0) }) {
            return preset.id
        }
        return nil
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
                        presetsCard
                        protocolCard
                    }

                    if recommended != draftConfiguration {
                        Button {
                            draftConfiguration = recommended
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
                        onApply(draftConfiguration.normalized())
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
        let isSelected = draftConfiguration.type == type

        return Button {
            if type == .standard {
                draftConfiguration = .standard
                return
            }

            if draftConfiguration.type == type {
                return
            }

            if let preset = WorkoutSessionTimerPreset.defaultPreset(for: type) {
                applyPreset(preset)
            } else {
                draftConfiguration.type = type
                draftConfiguration.presetID = nil
                draftConfiguration = draftConfiguration.normalized()
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

    private var presetsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Presets")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availablePresets) { preset in
                        let isSelected = selectedPresetID == preset.id
                        Button {
                            applyPreset(preset)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(preset.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(isSelected ? .white : AppTheme.primaryText)
                                Text(preset.protocolLabel)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : AppTheme.secondaryText)
                            }
                            .frame(minWidth: 125, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                            .background(isSelected ? AppTheme.accent : AppTheme.cardBackgroundElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(
                                        isSelected ? AppTheme.accent.opacity(0.6) : AppTheme.cardBorder,
                                        lineWidth: 1
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(12)
        .kinexCard(cornerRadius: 12, fill: AppTheme.cardBackgroundElevated)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        }
    }

    private var protocolCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Protocol")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)

            protocolStepper(
                title: "Work",
                valueText: "\(draftConfiguration.clampedWorkSeconds)s",
                binding: Binding(
                    get: { draftConfiguration.clampedWorkSeconds },
                    set: { updateProtocol(workSeconds: $0) }
                ),
                range: 5...600,
                step: 5
            )

            protocolStepper(
                title: "Rest",
                valueText: "\(draftConfiguration.clampedRestSeconds)s",
                binding: Binding(
                    get: { draftConfiguration.clampedRestSeconds },
                    set: { updateProtocol(restSeconds: $0) }
                ),
                range: 0...300,
                step: 5
            )

            protocolStepper(
                title: "Rounds",
                valueText: "\(draftConfiguration.clampedRounds)",
                binding: Binding(
                    get: { draftConfiguration.clampedRounds },
                    set: { updateProtocol(rounds: $0) }
                ),
                range: 1...60,
                step: 1
            )

            Text("Estimated total: \(formatDuration(draftConfiguration.totalDurationSeconds))")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .padding(12)
        .kinexCard(cornerRadius: 12, fill: AppTheme.cardBackgroundElevated)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        }
    }

    private func protocolStepper(
        title: String,
        valueText: String,
        binding: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)

            Spacer()

            Stepper(value: binding, in: range, step: step) {
                Text(valueText)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .tint(AppTheme.accent)
            .labelsHidden()

            Text(valueText)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(minWidth: 56, alignment: .trailing)
        }
    }

    private func applyPreset(_ preset: WorkoutSessionTimerPreset) {
        isApplyingPreset = true
        draftConfiguration = draftConfiguration.applyingPreset(preset)
        isApplyingPreset = false
    }

    private func updateProtocol(
        workSeconds: Int? = nil,
        restSeconds: Int? = nil,
        rounds: Int? = nil
    ) {
        if let workSeconds {
            draftConfiguration.workSeconds = workSeconds
        }
        if let restSeconds {
            draftConfiguration.restSeconds = restSeconds
        }
        if let rounds {
            draftConfiguration.rounds = rounds
        }

        if !isApplyingPreset {
            draftConfiguration.presetID = nil
        }

        draftConfiguration = draftConfiguration.normalized()
    }

    private func formatDuration(_ totalSeconds: Int) -> String {
        let total = max(totalSeconds, 0)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
