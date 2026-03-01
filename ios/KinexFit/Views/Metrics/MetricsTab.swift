import SwiftUI
import Charts

private enum StatsDestination: Hashable {
    case bodyWeight
    case bodyMeasurements
    case personalRecords
}

private struct ExerciseDrillDownDestination: Hashable {
    let exerciseName: String
}

struct MetricsTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Stats & Progress")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("Track your fitness journey with detailed metrics")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)

                    NavigationLink(value: StatsDestination.bodyWeight) {
                        StatsFeatureCard(
                            title: "Body Weight",
                            subtitle: "Track your weight over time",
                            icon: "scalemass",
                            iconColor: AppTheme.accent
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: StatsDestination.bodyMeasurements) {
                        StatsFeatureCard(
                            title: "Body Metrics",
                            subtitle: "Track body fat % and measurements",
                            icon: "ruler",
                            iconColor: AppTheme.statDumbbell
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: StatsDestination.personalRecords) {
                        StatsFeatureCard(
                            title: "Personal Records",
                            subtitle: "Track your PRs and strength gains",
                            icon: "arrow.up.right",
                            iconColor: AppTheme.statClock
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: StatsDestination.self) { destination in
                switch destination {
                case .bodyWeight:
                    BodyWeightView()
                case .bodyMeasurements:
                    BodyMetricsView()
                case .personalRecords:
                    PersonalRecordsView()
                }
            }
        }
    }
}

// MARK: - Stats Feature Card

private struct StatsFeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(iconColor)

            Text(title)
                .font(.system(size: 33, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Text(subtitle)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .kinexCard(cornerRadius: 16, fill: AppTheme.cardBackgroundElevated)
    }
}

// MARK: - Body Weight View

private struct BodyWeightView: View {
    @EnvironmentObject private var appState: AppState
    @State private var metrics: [APIBodyMetric] = []
    @State private var isLoading = true

    private var weightEntries: [APIBodyMetric] {
        metrics.filter { $0.weight != nil }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Log Weight card
                VStack(alignment: .leading, spacing: 16) {
                    Text("Log Weight")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)

                    AddWeightForm { weight, date, unit, notes in
                        await saveWeight(weight: weight, date: date, unit: unit, notes: notes)
                    }
                }
                .padding(16)
                .kinexCard(cornerRadius: 16, fill: AppTheme.cardBackgroundElevated)

                // Weight Log
                VStack(alignment: .leading, spacing: 12) {
                    Text("Weight Log")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)

                    if isLoading {
                        ProgressView()
                            .tint(AppTheme.accent)
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else if weightEntries.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "scalemass")
                                .font(.system(size: 40))
                                .foregroundStyle(AppTheme.tertiaryText)
                            Text("No weight entries yet. Log your first weight above!")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(weightEntries) { metric in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(metric.date)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(AppTheme.primaryText)
                                    if let notes = metric.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.system(size: 13))
                                            .foregroundStyle(AppTheme.tertiaryText)
                                    }
                                }

                                Spacer()

                                Text(metric.formattedWeight ?? "—")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppTheme.accent)
                            }
                            .padding(.vertical, 8)

                            if metric.id != weightEntries.last?.id {
                                Divider().background(AppTheme.separator)
                            }
                        }
                    }
                }
                .padding(16)
                .kinexCard(cornerRadius: 16, fill: AppTheme.cardBackgroundElevated)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Body Weight")
        .task { await loadMetrics() }
    }

    private func loadMetrics() async {
        isLoading = true
        do {
            let response: BodyMetricsListResponse = try await appState.environment.apiClient.send(
                .getBodyMetrics(limit: 100)
            )
            metrics = response.metrics
        } catch {
            metrics = []
        }
        isLoading = false
    }

    private func saveWeight(weight: Double, date: Date, unit: String, notes: String?) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let payload = BodyMetricPayload(
            date: formatter.string(from: date),
            weight: weight,
            unit: unit,
            notes: notes
        )

        do {
            let _ = try await appState.environment.apiClient.send(
                APIRequest.createBodyMetric(payload)
            )
            await loadMetrics()
        } catch { }
    }
}

// MARK: - Add Weight Form

private struct AddWeightForm: View {
    let onSave: (Double, Date, String, String?) async -> Void

    @State private var date = Date()
    @State private var weightText = ""
    @State private var unit = "lbs"
    @State private var notes = ""
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Date")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .tint(AppTheme.accent)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Weight")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                TextField("185.5", text: $weightText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .padding(12)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .foregroundStyle(AppTheme.primaryText)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Unit")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                Picker("Unit", selection: $unit) {
                    Text("lbs").tag("lbs")
                    Text("kg").tag("kg")
                }
                .pickerStyle(.menu)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .tint(AppTheme.primaryText)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Notes (optional)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                TextField("Morning weight, after breakfast, etc.", text: $notes)
                    .padding(12)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .foregroundStyle(AppTheme.primaryText)
            }

            Button {
                guard let weightValue = Double(weightText), !isSaving else { return }
                isSaving = true
                Task {
                    let unitValue = (unit == "kg") ? "metric" : "imperial"
                    await onSave(weightValue, date, unitValue, notes.isEmpty ? nil : notes)
                    weightText = ""
                    notes = ""
                    isSaving = false
                }
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Log Weight")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(weightText.isEmpty || Double(weightText) == nil || isSaving)
            .opacity((weightText.isEmpty || Double(weightText) == nil) ? 0.5 : 1.0)
        }
    }
}

// MARK: - Body Metrics View

private struct BodyMetricsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var metrics: [APIBodyMetric] = []
    @State private var isLoading = true
    @State private var showingAddSheet = false
    @State private var selectedTab = 0

    private var latestMetric: APIBodyMetric? { metrics.first }

    private var weightEntries: [APIBodyMetric] {
        metrics.filter { $0.weight != nil }
    }

    private var bodyFatEntries: [APIBodyMetric] {
        metrics.filter { $0.bodyFatPercentage != nil }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary cards
                HStack(spacing: 12) {
                    SummaryCard(
                        label: "Current Weight",
                        value: latestMetric?.formattedWeight ?? "N/A",
                        icon: "arrow.up.right",
                        iconColor: AppTheme.accent
                    )
                    SummaryCard(
                        label: "Body Fat",
                        value: latestMetric?.formattedBodyFat ?? "N/A",
                        icon: "arrow.down.right",
                        iconColor: AppTheme.statStreak
                    )
                }

                // Weight change
                if weightEntries.count >= 2,
                   let latest = weightEntries.first?.weight,
                   let previous = weightEntries.dropFirst().first?.weight {
                    let change = latest - previous
                    let unitLabel = (latestMetric?.unit == "metric") ? "kg" : "lbs"
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weight Change")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.secondaryText)
                            Text(String(format: "%@%.1f %@", change >= 0 ? "+" : "", change, unitLabel))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        Spacer()
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 20))
                            .foregroundStyle(change >= 0 ? AppTheme.accent : AppTheme.statStreak)
                    }
                    .padding(16)
                    .kinexCard(cornerRadius: 16, fill: AppTheme.cardBackgroundElevated)
                }

                // Tabs
                Picker("", selection: $selectedTab) {
                    Text("Weight").tag(0)
                    Text("Body Fat").tag(1)
                }
                .pickerStyle(.segmented)

                // History
                VStack(alignment: .leading, spacing: 12) {
                    Text("Measurement History")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("Your recorded body metrics over time")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.secondaryText)

                    if isLoading {
                        ProgressView()
                            .tint(AppTheme.accent)
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else {
                        let entries = selectedTab == 0 ? weightEntries : bodyFatEntries
                        if entries.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 40))
                                    .foregroundStyle(AppTheme.tertiaryText)
                                Text("No metrics yet")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryText)
                                Text("Start tracking your body measurements to see progress over time")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .multilineTextAlignment(.center)
                                Button {
                                    showingAddSheet = true
                                } label: {
                                    HStack {
                                        Image(systemName: "plus")
                                        Text("Add First Entry")
                                    }
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            ForEach(entries) { metric in
                                HStack {
                                    Text(metric.date)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(AppTheme.primaryText)
                                    Spacer()
                                    Text(selectedTab == 0
                                         ? (metric.formattedWeight ?? "—")
                                         : (metric.formattedBodyFat ?? "—"))
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(AppTheme.accent)
                                }
                                .padding(.vertical, 8)

                                if metric.id != entries.last?.id {
                                    Divider().background(AppTheme.separator)
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .kinexCard(cornerRadius: 16, fill: AppTheme.cardBackgroundElevated)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Body Metrics")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add Entry")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddBodyMetricSheet { payload in
                await saveMetric(payload)
            }
        }
        .task { await loadMetrics() }
    }

    private func loadMetrics() async {
        isLoading = true
        do {
            let response: BodyMetricsListResponse = try await appState.environment.apiClient.send(
                .getBodyMetrics(limit: 200)
            )
            metrics = response.metrics
        } catch {
            metrics = []
        }
        isLoading = false
    }

    private func saveMetric(_ payload: BodyMetricPayload) async {
        do {
            let _ = try await appState.environment.apiClient.send(
                APIRequest.createBodyMetric(payload)
            )
            await loadMetrics()
        } catch { }
    }
}

// MARK: - Summary Card

private struct SummaryCard: View {
    let label: String
    let value: String
    let icon: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondaryText)
            HStack {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
            }
        }
        .padding(16)
        .kinexCard(cornerRadius: 16, fill: AppTheme.cardBackgroundElevated)
    }
}

// MARK: - Add Body Metric Sheet

private struct AddBodyMetricSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (BodyMetricPayload) async -> Void

    @State private var date = Date()
    @State private var weight = ""
    @State private var bodyFat = ""
    @State private var unit = "imperial"
    @State private var notes = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Weight") {
                    HStack {
                        TextField("185.5", text: $weight)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text(unit == "metric" ? "kg" : "lbs")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Body Fat %") {
                    HStack {
                        TextField("18.5", text: $bodyFat)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("%").foregroundStyle(.secondary)
                    }
                }
                Section("Unit") {
                    Picker("Unit", selection: $unit) {
                        Text("Imperial (lbs)").tag("imperial")
                        Text("Metric (kg)").tag("metric")
                    }
                    .pickerStyle(.segmented)
                }
                Section("Notes") {
                    TextField("Optional notes", text: $notes)
                }
            }
            .navigationTitle("Add Entry")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled((weight.isEmpty && bodyFat.isEmpty) || isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let payload = BodyMetricPayload(
            date: formatter.string(from: date),
            weight: Double(weight),
            bodyFatPercentage: Double(bodyFat),
            unit: unit,
            notes: notes.isEmpty ? nil : notes
        )
        await onSave(payload)
        dismiss()
    }
}

// MARK: - Personal Records View

private struct PersonalRecordsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var personalRecords: [(exercise: String, pr: APIPersonalRecord)] = []
    @State private var progressionEntries: [ExerciseProgressEntry] = []
    @State private var isLoading = true
    @State private var showingAddSheet = false
    @State private var selectedTab = 0
    @State private var selectedProgressionExercise: String?

    private enum Tab: Int {
        case all = 0
        case recent = 1
        case progression = 2
    }

    private var totalPRs: Int { personalRecords.count }
    private var totalExercises: Int { Set(personalRecords.map(\.exercise)).count }
    private var allPRs: [(exercise: String, pr: APIPersonalRecord)] {
        personalRecords.sorted { lhs, rhs in
            let lhs1RM = lhs.pr.estimated1RM ?? lhs.pr.weight
            let rhs1RM = rhs.pr.estimated1RM ?? rhs.pr.weight
            if lhs1RM != rhs1RM { return lhs1RM > rhs1RM }
            return lhs.exercise.localizedCaseInsensitiveCompare(rhs.exercise) == .orderedAscending
        }
    }

    private var recentPRs: [(exercise: String, pr: APIPersonalRecord)] {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        return personalRecords.filter { item in
            guard let dateStr = item.pr.date,
                  let date = Self.parseDate(dateStr) else { return false }
            return date >= twoWeeksAgo
        }
    }

    private var progressionExercises: [String] {
        Self.exerciseNames(from: progressionEntries)
    }

    private var currentTab: Tab {
        Tab(rawValue: selectedTab) ?? .all
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Stats summary
                HStack(spacing: 12) {
                    PRStatBadge(icon: "trophy.fill", value: "\(totalPRs)", label: "Total PRs", color: AppTheme.accent)
                    PRStatBadge(icon: "dumbbell.fill", value: "\(totalExercises)", label: "Exercises", color: AppTheme.accent)
                    PRStatBadge(icon: "arrow.up.right", value: "\(recentPRs.count)", label: "Recent (2w)", color: AppTheme.statStreak)
                }

                // Tabs
                Picker("", selection: $selectedTab) {
                    Text("All PRs").tag(0)
                    Text("Recent").tag(1)
                    Text("Progression").tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedTab) { _, newValue in
                    guard Tab(rawValue: newValue) == .progression, selectedProgressionExercise == nil else { return }
                    selectedProgressionExercise = progressionExercises.first
                }

                if isLoading {
                    ProgressView()
                        .tint(AppTheme.accent)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    switch currentTab {
                    case .all:
                        recordsList(
                            allPRs,
                            emptyTitle: "No personal records yet",
                            emptySubtitle: "Add your first PR to start tracking your strength gains",
                            showAddButton: true
                        )
                    case .recent:
                        recordsList(
                            recentPRs,
                            emptyTitle: "No recent PRs",
                            emptySubtitle: "No PRs set in the last 2 weeks. Keep pushing.",
                            showAddButton: false
                        )
                    case .progression:
                        progressionTab
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Personal Records")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddPersonalRecordSheet { exercise, pr in
                await savePR(exercise: exercise, pr: pr)
            }
        }
        .navigationDestination(for: ExerciseDrillDownDestination.self) { destination in
            ExerciseDrillDownView(
                exerciseName: destination.exerciseName,
                history: history(for: destination.exerciseName)
            )
        }
        .task { await loadPRs() }
    }

    @ViewBuilder
    private func recordsList(
        _ records: [(exercise: String, pr: APIPersonalRecord)],
        emptyTitle: String,
        emptySubtitle: String,
        showAddButton: Bool
    ) -> some View {
        if records.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "trophy")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.tertiaryText)
                Text(emptyTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(emptySubtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)

                if showAddButton {
                    Button {
                        showingAddSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add First PR")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            ForEach(Array(records.enumerated()), id: \.offset) { _, item in
                NavigationLink(value: ExerciseDrillDownDestination(exerciseName: item.exercise)) {
                    PersonalRecordRow(exercise: item.exercise, pr: item.pr)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await deletePR(exercise: item.exercise) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var progressionTab: some View {
        if progressionExercises.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.tertiaryText)
                Text("No progression data yet")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text("Log workouts with weights and reps to unlock progression charts.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Exercise")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("View strength progression over time")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.secondaryText)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                        ForEach(progressionExercises, id: \.self) { exercise in
                            let selected = selectedProgressionExercise == exercise
                            Button {
                                selectedProgressionExercise = exercise
                            } label: {
                                Text(exercise)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(selected ? Color.white : AppTheme.primaryText)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(selected ? AppTheme.accent : AppTheme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .kinexCard(cornerRadius: 16, fill: AppTheme.cardBackgroundElevated)

                if let selectedExercise = selectedProgressionExercise {
                    let history = history(for: selectedExercise)
                    if history.isEmpty {
                        Text("No progression data available for this exercise")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.secondaryText)
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .kinexCard(cornerRadius: 16, fill: AppTheme.cardBackgroundElevated)
                    } else {
                        progressionCard(for: selectedExercise, history: history)
                    }
                }
            }
        }
    }

    private func progressionCard(for exercise: String, history: [ExerciseProgressEntry]) -> some View {
        let displayUnit = ExerciseProgressEntry.preferredUnit(for: history)
        let chartData = Array(history.suffix(20))
        let historyRows = history.sorted { $0.date > $1.date }

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(exercise) Progression")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Estimated 1RM over time")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                NavigationLink(value: ExerciseDrillDownDestination(exerciseName: exercise)) {
                    Text("Drill Down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }

            Chart(chartData) { entry in
                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("1RM", entry.oneRepMax(in: displayUnit))
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(AppTheme.statClock)
                .lineStyle(StrokeStyle(lineWidth: 2.5))

                PointMark(
                    x: .value("Date", entry.date),
                    y: .value("1RM", entry.oneRepMax(in: displayUnit))
                )
                .foregroundStyle(AppTheme.statClock)
            }
            .frame(height: 220)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(AppTheme.separator)
                    AxisTick().foregroundStyle(AppTheme.separator)
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.month(.abbreviated).day())
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(AppTheme.separator)
                    AxisTick().foregroundStyle(AppTheme.separator)
                    AxisValueLabel {
                        if let numeric = value.as(Double.self) {
                            Text("\(Int(numeric))")
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                }
            }
            .chartOverlay { _ in
                EmptyView()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("PR History")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                ForEach(historyRows) { entry in
                    HStack {
                        Text(entry.date, format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.secondaryText)
                        Spacer()
                        Text("\(entry.formattedWeight(in: displayUnit)) × \(entry.reps)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                        Text("1RM \(entry.formattedOneRepMax(in: displayUnit))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.statClock)
                    }
                    .padding(.vertical, 6)

                    if entry.id != historyRows.last?.id {
                        Divider().background(AppTheme.separator)
                    }
                }
            }
        }
        .padding(16)
        .kinexCard(cornerRadius: 16, fill: AppTheme.cardBackgroundElevated)
    }

    private func loadPRs() async {
        isLoading = true
        var fetchedRecords: [(exercise: String, pr: APIPersonalRecord)] = []

        do {
            let response: TrainingProfileResponse = try await appState.environment.apiClient.send(
                .getTrainingProfile()
            )
            if let records = response.profile?.personalRecords {
                fetchedRecords = records.map { (exercise: $0.key, pr: $0.value) }
                    .sorted { a, b in
                        let dateA = a.pr.date ?? ""
                        let dateB = b.pr.date ?? ""
                        if dateA != dateB { return dateA > dateB }
                        return a.exercise < b.exercise
                    }
            }
        } catch {
            fetchedRecords = []
        }

        do {
            _ = try await appState.environment.workoutRepository.importFromServer(limit: 200, maxPages: 4)
        } catch { }

        let workouts = (try? await appState.environment.workoutRepository.fetchAll()) ?? []
        let parsedProgression = Self.buildProgressionEntries(from: workouts, fallbackRecords: fetchedRecords)

        personalRecords = fetchedRecords
        progressionEntries = parsedProgression

        let availableExercises = Self.exerciseNames(from: parsedProgression)
        if let current = selectedProgressionExercise,
           availableExercises.contains(current) {
            selectedProgressionExercise = current
        } else {
            selectedProgressionExercise = availableExercises.first
        }

        isLoading = false
    }

    private func savePR(exercise: String, pr: PersonalRecordPayload) async {
        do {
            let _ = try await appState.environment.apiClient.send(
                APIRequest.upsertPersonalRecord(exercise: exercise, pr: pr)
            )
            await loadPRs()
        } catch { }
    }

    private func deletePR(exercise: String) async {
        do {
            let _ = try await appState.environment.apiClient.send(
                .deletePersonalRecord(exercise: exercise)
            )
            await loadPRs()
        } catch { }
    }

    private func history(for exercise: String) -> [ExerciseProgressEntry] {
        let normalized = Self.normalizeExerciseName(exercise)
        return progressionEntries
            .filter { Self.normalizeExerciseName($0.exercise) == normalized }
            .sorted { $0.date < $1.date }
    }

    private static func buildProgressionEntries(
        from workouts: [Workout],
        fallbackRecords: [(exercise: String, pr: APIPersonalRecord)]
    ) -> [ExerciseProgressEntry] {
        var entries: [ExerciseProgressEntry] = []
        var seenKeys: Set<String> = []

        for workout in workouts {
            let presentation = WorkoutContentPresentation.from(
                content: workout.content,
                source: workout.source,
                durationMinutes: workout.durationMinutes,
                fallbackExerciseCount: workout.exerciseCount
            )

            for exercise in presentation.exercises {
                guard let reps = exercise.reps, reps > 0,
                      let weightText = exercise.weight,
                      let parsedWeight = parseWeight(weightText) else { continue }

                let entry = ExerciseProgressEntry(
                    exercise: exercise.name,
                    date: workout.createdAt,
                    weight: parsedWeight.value,
                    reps: reps,
                    sets: max(exercise.sets ?? 1, 1),
                    unit: parsedWeight.unit,
                    workoutID: workout.id
                )

                if seenKeys.insert(entry.dedupeKey).inserted {
                    entries.append(entry)
                }
            }
        }

        for item in fallbackRecords {
            let reps = max(item.pr.reps ?? 1, 1)
            let unit = StrengthUnit(rawUnit: item.pr.unit)
            let entry = ExerciseProgressEntry(
                exercise: item.exercise,
                date: parseDate(item.pr.date) ?? Date(),
                weight: item.pr.weight,
                reps: reps,
                sets: 1,
                unit: unit,
                workoutID: nil
            )
            if seenKeys.insert(entry.dedupeKey).inserted {
                entries.append(entry)
            }
        }

        return entries.sorted { $0.date < $1.date }
    }

    private static func exerciseNames(from entries: [ExerciseProgressEntry]) -> [String] {
        var displayByKey: [String: String] = [:]
        for entry in entries {
            let key = normalizeExerciseName(entry.exercise)
            if displayByKey[key] == nil {
                displayByKey[key] = entry.exercise
            }
        }
        return displayByKey.values.sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    private static func parseWeight(_ raw: String) -> (value: Double, unit: StrengthUnit)? {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?i)(\d+(?:\.\d+)?)\s*(lb|lbs|kg|kgs)?"#
        ) else {
            return nil
        }
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        guard let match = regex.firstMatch(in: raw, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: raw),
              let value = Double(raw[valueRange]) else {
            return nil
        }

        let unit: StrengthUnit
        if let unitRange = Range(match.range(at: 2), in: raw) {
            unit = StrengthUnit(rawUnit: String(raw[unitRange]))
        } else {
            unit = .lbs
        }
        return (value, unit)
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: raw)
    }

    private static func normalizeExerciseName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

// MARK: - PR Stat Badge

private struct PRStatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .kinexCard(cornerRadius: 12, fill: AppTheme.cardBackgroundElevated)
    }
}

// MARK: - PR Row

private struct PersonalRecordRow: View {
    let exercise: String
    let pr: APIPersonalRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.tertiaryText)
            }

            if let dateStr = pr.date {
                Text(dateStr)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.tertiaryText)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Best Lift")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                    let repsText = pr.reps.map { " x \($0)" } ?? ""
                    Text("\(Int(pr.weight)) \(pr.unit)\(repsText)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                }

                if let est1RM = pr.estimated1RM {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Est. 1RM")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.secondaryText)
                        Text("\(Int(est1RM)) \(pr.unit)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.statStreak)
                    }
                }
            }
        }
        .padding(16)
        .kinexCard(cornerRadius: 12, fill: AppTheme.cardBackgroundElevated)
    }
}

private enum StrengthUnit: String, Hashable {
    case lbs
    case kg

    init(rawUnit: String) {
        let normalized = rawUnit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasPrefix("kg") || normalized.hasPrefix("kilo") {
            self = .kg
        } else {
            self = .lbs
        }
    }

    func toLbs(_ value: Double) -> Double {
        switch self {
        case .lbs:
            value
        case .kg:
            value * 2.20462
        }
    }

    func fromLbs(_ value: Double) -> Double {
        switch self {
        case .lbs:
            value
        case .kg:
            value / 2.20462
        }
    }
}

private struct ExerciseProgressEntry: Identifiable, Hashable {
    let id: String
    let dedupeKey: String
    let exercise: String
    let date: Date
    let weight: Double
    let reps: Int
    let sets: Int
    let unit: StrengthUnit
    let oneRepMaxLbs: Double
    let workoutID: String?

    init(
        exercise: String,
        date: Date,
        weight: Double,
        reps: Int,
        sets: Int,
        unit: StrengthUnit,
        workoutID: String?
    ) {
        let clampedReps = max(reps, 1)
        let clampedSets = max(sets, 1)
        let normalizedExercise = exercise.trimmingCharacters(in: .whitespacesAndNewlines)
        let weightLbs = unit.toLbs(weight)

        self.exercise = normalizedExercise
        self.date = date
        self.weight = weight
        self.reps = clampedReps
        self.sets = clampedSets
        self.unit = unit
        self.oneRepMaxLbs = Self.calculateOneRepMax(weightLbs: weightLbs, reps: clampedReps)
        self.workoutID = workoutID

        let timestamp = Int(date.timeIntervalSince1970)
        self.dedupeKey = "\(normalizedExercise.lowercased())|\(timestamp)|\(Int(weightLbs.rounded()))|\(clampedReps)|\(clampedSets)"
        self.id = "\(self.dedupeKey)|\(workoutID ?? "manual")"
    }

    func weight(in unit: StrengthUnit) -> Double {
        unit.fromLbs(self.unit.toLbs(weight))
    }

    func volume(in unit: StrengthUnit) -> Double {
        let convertedWeight = weight(in: unit)
        return convertedWeight * Double(reps * sets)
    }

    func oneRepMax(in unit: StrengthUnit) -> Double {
        unit.fromLbs(oneRepMaxLbs)
    }

    func formattedWeight(in unit: StrengthUnit) -> String {
        String(format: "%.0f %@", weight(in: unit), unit.rawValue)
    }

    func formattedOneRepMax(in unit: StrengthUnit) -> String {
        String(format: "%.0f %@", oneRepMax(in: unit), unit.rawValue)
    }

    static func preferredUnit(for entries: [ExerciseProgressEntry]) -> StrengthUnit {
        let kgCount = entries.filter { $0.unit == .kg }.count
        return kgCount > entries.count / 2 ? .kg : .lbs
    }

    private static func calculateOneRepMax(weightLbs: Double, reps: Int) -> Double {
        guard weightLbs > 0 else { return 0 }
        if reps <= 1 { return weightLbs }

        let repCount = Double(max(reps, 1))
        let brzycki: Double
        if reps > 12 {
            brzycki = weightLbs
        } else {
            brzycki = weightLbs / (1.0278 - 0.0278 * repCount)
        }
        let epley = weightLbs * (1.0 + repCount / 30.0)
        return ((brzycki + epley) / 2.0).rounded()
    }
}

private struct ExerciseDrillDownView: View {
    let exerciseName: String
    let history: [ExerciseProgressEntry]

    private var orderedHistory: [ExerciseProgressEntry] {
        history.sorted { $0.date < $1.date }
    }

    private var recentHistory: [ExerciseProgressEntry] {
        orderedHistory.sorted { $0.date > $1.date }
    }

    private var displayUnit: StrengthUnit {
        ExerciseProgressEntry.preferredUnit(for: orderedHistory)
    }

    private var prMilestones: [ExerciseProgressEntry] {
        var best1RM: Double = 0
        var milestones: [ExerciseProgressEntry] = []

        for entry in orderedHistory {
            if entry.oneRepMaxLbs > best1RM {
                best1RM = entry.oneRepMaxLbs
                milestones.append(entry)
            }
        }

        return milestones.sorted { $0.date > $1.date }
    }

    private var averageWeight: Double {
        guard !orderedHistory.isEmpty else { return 0 }
        let total = orderedHistory.reduce(0.0) { partial, entry in
            partial + entry.weight(in: displayUnit)
        }
        return total / Double(orderedHistory.count)
    }

    private var averageReps: Double {
        guard !orderedHistory.isEmpty else { return 0 }
        let total = orderedHistory.reduce(0) { partial, entry in
            partial + entry.reps
        }
        return Double(total) / Double(orderedHistory.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if orderedHistory.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundStyle(AppTheme.tertiaryText)
                        Text("No data for \(exerciseName)")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .kinexCard(cornerRadius: 16, fill: AppTheme.cardBackgroundElevated)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ExerciseDetailStatCard(
                            label: "Times Performed",
                            value: "\(orderedHistory.count)",
                            icon: "calendar",
                            color: AppTheme.accent
                        )
                        ExerciseDetailStatCard(
                            label: "Average Weight",
                            value: String(format: "%.0f %@", averageWeight, displayUnit.rawValue),
                            icon: "dumbbell.fill",
                            color: AppTheme.statClock
                        )
                        ExerciseDetailStatCard(
                            label: "Average Reps",
                            value: String(format: "%.0f", averageReps),
                            icon: "repeat",
                            color: AppTheme.statStreak
                        )
                        ExerciseDetailStatCard(
                            label: "PR Milestones",
                            value: "\(prMilestones.count)",
                            icon: "trophy.fill",
                            color: AppTheme.accent
                        )
                    }

                    if !prMilestones.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Personal Records")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)

                            ForEach(prMilestones.prefix(5)) { entry in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(entry.formattedWeight(in: displayUnit)) × \(entry.reps)")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(AppTheme.primaryText)
                                        Text("1RM \(entry.formattedOneRepMax(in: displayUnit))")
                                            .font(.system(size: 13))
                                            .foregroundStyle(AppTheme.statClock)
                                    }
                                    Spacer()
                                    Text(entry.date, format: .dateTime.month(.abbreviated).day().year())
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(16)
                        .kinexCard(cornerRadius: 16, fill: AppTheme.cardBackgroundElevated)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Weight Progression")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)

                        Chart(Array(orderedHistory.suffix(20))) { entry in
                            LineMark(
                                x: .value("Date", entry.date),
                                y: .value("Weight", entry.weight(in: displayUnit))
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(AppTheme.accent)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))

                            LineMark(
                                x: .value("Date", entry.date),
                                y: .value("1RM", entry.oneRepMax(in: displayUnit))
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(AppTheme.statClock)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, dash: [6, 4]))

                            PointMark(
                                x: .value("Date", entry.date),
                                y: .value("Weight", entry.weight(in: displayUnit))
                            )
                            .foregroundStyle(AppTheme.accent)
                        }
                        .frame(height: 230)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                                AxisGridLine().foregroundStyle(AppTheme.separator)
                                AxisTick().foregroundStyle(AppTheme.separator)
                                AxisValueLabel {
                                    if let date = value.as(Date.self) {
                                        Text(date, format: .dateTime.month(.abbreviated).day())
                                            .foregroundStyle(AppTheme.secondaryText)
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisGridLine().foregroundStyle(AppTheme.separator)
                                AxisTick().foregroundStyle(AppTheme.separator)
                                AxisValueLabel {
                                    if let numeric = value.as(Double.self) {
                                        Text("\(Int(numeric))")
                                            .foregroundStyle(AppTheme.secondaryText)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .kinexCard(cornerRadius: 16, fill: AppTheme.cardBackgroundElevated)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Volume Progression")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)

                        Chart(Array(orderedHistory.suffix(20))) { entry in
                            BarMark(
                                x: .value("Date", entry.date),
                                y: .value("Volume", entry.volume(in: displayUnit))
                            )
                            .foregroundStyle(AppTheme.accent)
                        }
                        .frame(height: 220)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                                AxisGridLine().foregroundStyle(AppTheme.separator)
                                AxisTick().foregroundStyle(AppTheme.separator)
                                AxisValueLabel {
                                    if let date = value.as(Date.self) {
                                        Text(date, format: .dateTime.month(.abbreviated).day())
                                            .foregroundStyle(AppTheme.secondaryText)
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisGridLine().foregroundStyle(AppTheme.separator)
                                AxisTick().foregroundStyle(AppTheme.separator)
                                AxisValueLabel {
                                    if let numeric = value.as(Double.self) {
                                        Text("\(Int(numeric))")
                                            .foregroundStyle(AppTheme.secondaryText)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .kinexCard(cornerRadius: 16, fill: AppTheme.cardBackgroundElevated)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Workout History")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)

                        ForEach(recentHistory.prefix(10)) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
                                        .font(.system(size: 13))
                                        .foregroundStyle(AppTheme.secondaryText)
                                    Spacer()
                                    Text("1RM \(entry.formattedOneRepMax(in: displayUnit))")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(AppTheme.statClock)
                                }

                                Text("\(entry.formattedWeight(in: displayUnit)) × \(entry.reps) reps")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryText)

                                Text("Volume \(Int(entry.volume(in: displayUnit))) \(displayUnit.rawValue)·reps")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.tertiaryText)
                            }
                            .padding(12)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding(16)
                    .kinexCard(cornerRadius: 16, fill: AppTheme.cardBackgroundElevated)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(exerciseName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

private struct ExerciseDetailStatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 95, alignment: .leading)
        .padding(12)
        .kinexCard(cornerRadius: 12, fill: AppTheme.cardBackgroundElevated)
    }
}

// MARK: - Add PR Sheet

private struct AddPersonalRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, PersonalRecordPayload) async -> Void

    @State private var exercise = ""
    @State private var weightText = ""
    @State private var repsText = ""
    @State private var unit = "lbs"
    @State private var date = Date()
    @State private var notes = ""
    @State private var isSaving = false
    @State private var showingSuggestions = false

    private let commonExercises = [
        "Bench Press", "Squat", "Deadlift", "Overhead Press",
        "Barbell Row", "Pull-ups", "Clean", "Snatch",
        "Incline Bench Press", "Front Squat", "Romanian Deadlift",
        "Leg Press", "Dumbbell Bench Press", "Lat Pulldown",
        "Barbell Curl", "Dips"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Exercise name", text: $exercise)
                        .onChange(of: exercise) { _, _ in
                            showingSuggestions = !exercise.isEmpty
                        }

                    if showingSuggestions {
                        let filtered = commonExercises.filter {
                            $0.localizedCaseInsensitiveContains(exercise) && $0 != exercise
                        }
                        if !filtered.isEmpty {
                            ForEach(filtered.prefix(5), id: \.self) { suggestion in
                                Button {
                                    exercise = suggestion
                                    showingSuggestions = false
                                } label: {
                                    Text(suggestion)
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                        }
                    }
                }

                Section("Performance") {
                    HStack {
                        TextField("Weight", text: $weightText)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Picker("", selection: $unit) {
                            Text("lbs").tag("lbs")
                            Text("kg").tag("kg")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)
                    }

                    HStack {
                        TextField("Reps", text: $repsText)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                        Text("reps").foregroundStyle(.secondary)
                    }
                }

                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes)
                }
            }
            .navigationTitle("Add Personal Record")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(exercise.isEmpty || weightText.isEmpty || repsText.isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let weight = Double(weightText), let reps = Int(repsText) else { return }
        isSaving = true

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let payload = PersonalRecordPayload(
            weight: weight,
            reps: reps,
            unit: unit,
            date: formatter.string(from: date),
            notes: notes.isEmpty ? nil : notes
        )
        await onSave(exercise, payload)
        dismiss()
    }
}

#Preview {
    MetricsTab()
        .environmentObject(AppState(environment: .preview))
}
