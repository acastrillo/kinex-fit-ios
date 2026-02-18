import SwiftUI

struct MetricsTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var metrics: [BodyMetric] = []
    @State private var isLoading = true
    @State private var showingAddMetric = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading metrics...")
                } else if metrics.isEmpty {
                    EmptyMetricsView(onAddTapped: { showingAddMetric = true })
                } else {
                    MetricsListView(metrics: metrics)
                }
            }
            .navigationTitle("Metrics")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddMetric = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddMetric) {
                AddMetricView()
            }
        }
        .task {
            await loadMetrics()
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
            // Handle error
        }
        isLoading = false
    }
}

// MARK: - Empty State

private struct EmptyMetricsView: View {
    let onAddTapped: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Metrics", systemImage: "chart.line.uptrend.xyaxis")
        } description: {
            Text("Track your weight and body measurements")
        } actions: {
            Button("Add Measurement") {
                onAddTapped()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Metrics List

private struct MetricsListView: View {
    let metrics: [BodyMetric]

    var body: some View {
        List(metrics) { metric in
            MetricRow(metric: metric)
        }
    }
}

// MARK: - Metric Row

private struct MetricRow: View {
    let metric: BodyMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(metric.date, style: .date)
                    .font(.headline)

                Spacer()

                if let weight = metric.formattedWeight {
                    Text(weight)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
            }

            if let notes = metric.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Metric

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
            // Handle error
        }
        isSaving = false
    }
}

// MARK: - Preview

#Preview {
    MetricsTab()
        .environmentObject(AppState(environment: .preview))
}
