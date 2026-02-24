import SwiftUI

private enum StatsDestination: Hashable {
    case bodyWeight
    case bodyMeasurements
    case personalRecords
}

struct MetricsTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var metrics: [BodyMetric] = []
    @State private var isLoading = true
    @State private var showingAddMetric = false

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
                            title: "Body Measurements",
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
                    BodyWeightHistoryView(
                        metrics: metrics,
                        isLoading: isLoading,
                        onAddTapped: { showingAddMetric = true }
                    )
                case .bodyMeasurements:
                    MetricsPlaceholderDetailView(
                        title: "Body Measurements",
                        subtitle: "Track body fat and measurements over time"
                    )
                case .personalRecords:
                    MetricsPlaceholderDetailView(
                        title: "Personal Records",
                        subtitle: "Save your best lifts and performance milestones"
                    )
                }
            }
            .sheet(isPresented: $showingAddMetric) {
                AddMetricView()
            }
            .task {
                await loadMetrics()
            }
        }
    }

    private func loadMetrics() async {
        do {
            metrics = try await appState.environment.database.dbQueue.read { db in
                try BodyMetric
                    .order(BodyMetric.Columns.date.desc)
                    .fetchAll(db)
            }
        } catch {
            metrics = []
        }
        isLoading = false
    }
}

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

private struct BodyWeightHistoryView: View {
    let metrics: [BodyMetric]
    let isLoading: Bool
    let onAddTapped: () -> Void

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading metrics...")
                    .tint(AppTheme.accent)
            } else if metrics.isEmpty {
                VStack(spacing: 14) {
                    Text("No weight entries yet")
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryText)

                    Text("Add your first body weight to start tracking progress.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)

                    Button("Add Measurement") {
                        onAddTapped()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                }
                .padding(24)
            } else {
                List(metrics) { metric in
                    HStack {
                        Text(metric.date, style: .date)
                            .foregroundStyle(AppTheme.primaryText)

                        Spacer()

                        Text(metric.formattedWeight ?? "—")
                            .fontWeight(.semibold)
                            .foregroundStyle(AppTheme.statClock)
                    }
                    .listRowBackground(AppTheme.cardBackground)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(AppTheme.background)
            }
        }
        .navigationTitle("Body Weight")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onAddTapped()
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
    }
}

private struct MetricsPlaceholderDetailView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 14) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.primaryText)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(title)
    }
}

struct AddMetricView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var date = Date()
    @State private var weight = ""
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
                        TextField("Weight", text: $weight)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("lbs")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes)
                }
            }
            .navigationTitle("Add Measurement")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveMetric() }
                    }
                    .disabled(weight.isEmpty || isSaving)
                }
            }
        }
    }

    private func saveMetric() async {
        guard let weightValue = Double(weight) else { return }

        isSaving = true
        let metric = BodyMetric(
            date: date,
            weight: weightValue,
            notes: notes.isEmpty ? nil : notes
        )

        do {
            let metricToSave = metric
            try await appState.environment.database.dbQueue.write { db in
                try metricToSave.insert(db)
            }
            dismiss()
        } catch {
            // No-op fallback for now. Keeping UX non-blocking during visual redesign.
        }
        isSaving = false
    }
}

#Preview {
    MetricsTab()
        .environmentObject(AppState(environment: .preview))
}
