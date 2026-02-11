import SwiftUI

struct PersonalRecordsStep: View {
    @Binding var records: [PersonalRecord]
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var showAddPR = false

    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)

                Text("Add Your Personal Records")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Optional - Skip if you don't have any yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)
            .padding(.horizontal)

            // Records list
            if records.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("No records added yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Tap the button below to add your first PR")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(records) { record in
                            PRRow(record: record, onDelete: {
                                records.removeAll { $0.id == record.id }
                            })
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Spacer()

            // Add PR button
            Button {
                showAddPR = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Personal Record")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundStyle(.blue)
                .fontWeight(.medium)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    onSkip()
                } label: {
                    Text("Skip")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                        .fontWeight(.medium)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    onContinue()
                } label: {
                    HStack {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showAddPR) {
            AddPRSheet(records: $records)
        }
    }
}

struct PRRow: View {
    let record: PersonalRecord
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.exerciseName)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label("\(Int(record.weight))\(record.unit.symbol)", systemImage: "scalemass")
                    if let reps = record.reps {
                        Label("\(reps) reps", systemImage: "repeat")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground).opacity(0.8))
        )
    }
}

struct AddPRSheet: View {
    @Binding var records: [PersonalRecord]
    @Environment(\.dismiss) private var dismiss

    @State private var exerciseName = ""
    @State private var weight = ""
    @State private var unit: WeightUnit = .lbs
    @State private var reps = ""
    @State private var showCustomExercise = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    if showCustomExercise {
                        TextField("Exercise name", text: $exerciseName)
                            .autocapitalization(.words)
                    } else {
                        Picker("Exercise", selection: $exerciseName) {
                            Text("Select exercise").tag("")
                            ForEach(PersonalRecord.commonExercises, id: \.self) { exercise in
                                Text(exercise).tag(exercise)
                            }
                        }
                    }

                    Button {
                        showCustomExercise.toggle()
                        exerciseName = ""
                    } label: {
                        Text(showCustomExercise ? "Choose from common exercises" : "Enter custom exercise")
                    }
                }

                Section("Details") {
                    HStack {
                        TextField("Weight", text: $weight)
                            .keyboardType(.decimalPad)

                        Picker("Unit", selection: $unit) {
                            Text("lbs").tag(WeightUnit.lbs)
                            Text("kg").tag(WeightUnit.kg)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)
                    }

                    TextField("Reps (optional)", text: $reps)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Personal Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addRecord()
                    }
                    .disabled(!canAdd)
                }
            }
        }
    }

    private var canAdd: Bool {
        !exerciseName.isEmpty && Double(weight) != nil
    }

    private func addRecord() {
        guard let weightValue = Double(weight) else { return }

        let pr = PersonalRecord(
            exerciseName: exerciseName,
            weight: weightValue,
            unit: unit,
            reps: Int(reps)
        )

        records.append(pr)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    PersonalRecordsStep(records: .constant([]), onContinue: {}, onSkip: {})
}
