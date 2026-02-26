import SwiftUI

private enum StatsDestination: Hashable {
    case bodyWeight
    case bodyMeasurements
    case personalRecords
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
    @State private var isLoading = true
    @State private var showingAddSheet = false
    @State private var selectedTab = 0

    private var totalPRs: Int { personalRecords.count }
    private var totalExercises: Int { Set(personalRecords.map(\.exercise)).count }

    private var recentPRs: [(exercise: String, pr: APIPersonalRecord)] {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return personalRecords.filter { item in
            guard let dateStr = item.pr.date,
                  let date = formatter.date(from: dateStr) else { return false }
            return date >= twoWeeksAgo
        }
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

                if isLoading {
                    ProgressView()
                        .tint(AppTheme.accent)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    let displayRecords = selectedTab == 1 ? recentPRs : personalRecords
                    if displayRecords.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "trophy")
                                .font(.system(size: 40))
                                .foregroundStyle(AppTheme.tertiaryText)
                            Text("No personal records yet")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryText)
                            Text(selectedTab == 1
                                 ? "No PRs set in the last 2 weeks"
                                 : "Add your first PR to start tracking your strength gains")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.secondaryText)
                                .multilineTextAlignment(.center)

                            if selectedTab == 0 {
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
                        ForEach(Array(displayRecords.enumerated()), id: \.offset) { _, item in
                            PersonalRecordRow(exercise: item.exercise, pr: item.pr) {
                                await deletePR(exercise: item.exercise)
                            }
                        }
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
        .task { await loadPRs() }
    }

    private func loadPRs() async {
        isLoading = true
        do {
            let response: TrainingProfileResponse = try await appState.environment.apiClient.send(
                .getTrainingProfile()
            )
            if let records = response.profile?.personalRecords {
                personalRecords = records.map { (exercise: $0.key, pr: $0.value) }
                    .sorted { a, b in
                        let dateA = a.pr.date ?? ""
                        let dateB = b.pr.date ?? ""
                        if dateA != dateB { return dateA > dateB }
                        return a.exercise < b.exercise
                    }
            } else {
                personalRecords = []
            }
        } catch {
            personalRecords = []
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
    let onDelete: () async -> Void

    @State private var showingDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Button { showingDeleteConfirm = true } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
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
        .confirmationDialog("Delete PR", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task { await onDelete() }
            }
        } message: {
            Text("Remove \(exercise) personal record?")
        }
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
