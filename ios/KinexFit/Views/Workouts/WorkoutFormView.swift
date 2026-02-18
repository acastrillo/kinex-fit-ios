import SwiftUI

struct WorkoutFormView: View {
    enum Mode {
        case create
        case edit(Workout)

        var title: String {
            switch self {
            case .create: return "New Workout"
            case .edit: return "Edit Workout"
            }
        }

        var saveButtonTitle: String {
            switch self {
            case .create: return "Create"
            case .edit: return "Save"
            }
        }
    }

    let mode: Mode
    let onSave: (String, String?) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var content: String
    @State private var isSaving = false
    @State private var error: Error?
    @State private var showingError = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case content
    }

    init(mode: Mode, onSave: @escaping (String, String?) async throws -> Void) {
        self.mode = mode
        self.onSave = onSave

        switch mode {
        case .create:
            _title = State(initialValue: "")
            _content = State(initialValue: "")
        case .edit(let workout):
            _title = State(initialValue: workout.title)
            _content = State(initialValue: workout.content ?? "")
        }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Workout Title", text: $title)
                        .focused($focusedField, equals: .title)
                        .autocorrectionDisabled(false)
                        .textInputAutocapitalization(.words)
                } footer: {
                    Text("Give your workout a descriptive name")
                }

                Section {
                    TextEditor(text: $content)
                        .focused($focusedField, equals: .content)
                        .frame(minHeight: 200)
                        .overlay(alignment: .topLeading) {
                            if content.isEmpty {
                                Text("Add exercises, sets, reps, notes...")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                } header: {
                    Text("Details")
                } footer: {
                    Text("Enter your workout details - exercises, sets, reps, weights, and any notes")
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.saveButtonTitle) {
                        Task { await save() }
                    }
                    .disabled(!isValid || isSaving)
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(error?.localizedDescription ?? "Failed to save workout")
            }
            .overlay {
                if isSaving {
                    savingOverlay
                }
            }
        }
        .onAppear {
            if case .create = mode {
                focusedField = .title
            }
        }
    }

    private var savingOverlay: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                Text("Saving...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func save() async {
        focusedField = nil
        isSaving = true

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await onSave(trimmedTitle, trimmedContent.isEmpty ? nil : trimmedContent)
            dismiss()
        } catch {
            self.error = error
            showingError = true
        }

        isSaving = false
    }
}

// MARK: - Preview

#Preview("Create") {
    WorkoutFormView(mode: .create) { title, content in
        print("Creating: \(title), \(content ?? "no content")")
    }
}

#Preview("Edit") {
    WorkoutFormView(
        mode: .edit(Workout(
            title: "Push Day",
            content: "Bench Press 4x8\nOverhead Press 3x10",
            source: .manual
        ))
    ) { title, content in
        print("Updating: \(title), \(content ?? "no content")")
    }
}
