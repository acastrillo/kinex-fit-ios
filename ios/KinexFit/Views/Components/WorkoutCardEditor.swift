import SwiftUI
import UniformTypeIdentifiers

/// Reusable card-based workout exercise editor with drag-to-reorder, inline editing, add/remove.
/// Used by WorkoutFormView, InstagramWorkoutEditView, and InstagramImportReviewView.
struct WorkoutCardEditor: View {
    @Binding var cards: [EditableWorkoutCard]
    var defaultRestSeconds: Int = 60
    var rounds: Int?

    @State private var draggedCard: EditableWorkoutCard?
    @State private var editingCardID: UUID?
    @FocusState private var isFieldFocused: Bool

    private enum Typography {
        static let sectionTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
        static let supportingText = Font.system(.subheadline, design: .rounded).weight(.medium)
        static let cardIndex = Font.system(.footnote, design: .rounded).weight(.bold)
        static let cardTitle = Font.system(.title2, design: .rounded).weight(.semibold)
        static let cardTitleEditing = Font.system(.title3, design: .rounded).weight(.semibold)
        static let actionLabel = Font.system(.headline, design: .rounded).weight(.semibold)
        static let fieldLabel = Font.system(.footnote, design: .rounded).weight(.medium)
        static let metric = Font.system(.body, design: .rounded).weight(.medium)
    }

    var nonEmptyCardsCount: Int {
        cards.filter { !$0.trimmedName.isEmpty }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Cards")
                .font(Typography.sectionTitle)
                .foregroundStyle(AppTheme.primaryText)

            Text("Tap a card to edit; drag the handle to reorder. Empty fields auto-hide.")
                .font(Typography.supportingText)
                .foregroundStyle(AppTheme.secondaryText)

            addButton

            if cards.isEmpty || nonEmptyCardsCount == 0 {
                Text("No exercise rows detected yet.")
                    .font(Typography.supportingText)
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.vertical, 12)
            }

            LazyVStack(spacing: 10) {
                ForEach(cards) { card in
                    if let cardBinding = binding(for: card.id) {
                        VStack(alignment: .leading, spacing: 8) {
                            if shouldShowBlockHeader(for: card), let block = card.block {
                                blockHeader(block, order: blockOrder(for: card))
                            }

                            exerciseCardRow(card: cardBinding, index: indexForCard(id: card.id) + 1)
                                .onDrag {
                                    draggedCard = card
                                    return NSItemProvider(object: card.id.uuidString as NSString)
                                }
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: CardReorderDropDelegate(
                                        item: card,
                                        cards: $cards,
                                        draggedCard: $draggedCard
                                    )
                                )
                        }
                    }
                }
            }
            .onDrop(
                of: [UTType.text],
                delegate: CardReorderDropDelegate(
                    item: nil,
                    cards: $cards,
                    draggedCard: $draggedCard
                )
            )
        }
        .padding(14)
        .kinexCard(cornerRadius: 16)
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button("Done") {
                        isFieldFocused = false
                        editingCardID = nil
                    }
                }
            }
        }
    }

    // MARK: - Card Row

    private func exerciseCardRow(card: Binding<EditableWorkoutCard>, index: Int) -> some View {
        let isEditing = editingCardID == card.wrappedValue.id
        let name = card.wrappedValue.trimmedName
        let reps = card.wrappedValue.reps.trimmingCharacters(in: .whitespacesAndNewlines)
        let sets = card.wrappedValue.sets.trimmingCharacters(in: .whitespacesAndNewlines)
        let weight = card.wrappedValue.weight.trimmingCharacters(in: .whitespacesAndNewlines)
        let rest = card.wrappedValue.restSeconds.trimmingCharacters(in: .whitespacesAndNewlines)

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.tertiaryText)
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text("\(index)")
                        .font(Typography.cardIndex)
                        .foregroundStyle(AppTheme.accent)

                    if isEditing {
                        TextField("Exercise Name", text: card.name)
                            .textInputAutocapitalization(.words)
                            .foregroundStyle(AppTheme.primaryText)
                            .font(Typography.cardTitleEditing)
                            .focused($isFieldFocused)
                    } else {
                        Text(name.isEmpty ? "Untitled exercise" : name)
                            .font(Typography.cardTitle)
                            .foregroundStyle(name.isEmpty ? AppTheme.tertiaryText : AppTheme.primaryText)
                    }

                    Spacer(minLength: 8)

                    Button {
                        editingCardID = isEditing ? nil : card.wrappedValue.id
                    } label: {
                        Image(systemName: isEditing ? "checkmark.circle" : "pencil")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .buttonStyle(.plain)

                    Button {
                        removeCard(id: card.wrappedValue.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }

                if isEditing {
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            cardInputField(title: "Set", text: card.sets, keyboard: .numberPad)
                            cardInputField(title: "Reps", text: card.reps, keyboard: .numberPad)
                        }
                        HStack(spacing: 10) {
                            cardInputField(title: "Weight", text: card.weight, keyboard: .default)
                            cardInputField(title: "Rest (s)", text: card.restSeconds, keyboard: .numberPad)
                        }
                    }
                } else {
                    HStack(spacing: 16) {
                        if !sets.isEmpty {
                            metricText("Set: \(sets)")
                        }
                        if !reps.isEmpty {
                            metricText("Reps: \(reps)")
                        }
                    }

                    if !weight.isEmpty {
                        metricText("Weight: \(weight)")
                    }
                    if !rest.isEmpty {
                        metricText("Rest: \(rest)s")
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .kinexCard(cornerRadius: 12, fill: AppTheme.cardBackground)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if editingCardID != card.wrappedValue.id {
                editingCardID = card.wrappedValue.id
            }
        }
    }

    // MARK: - Helpers

    private var addButton: some View {
        Button(action: addCard) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("+ Add")
            }
            .font(Typography.actionLabel)
            .foregroundStyle(AppTheme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [5, 5]))
                    .foregroundStyle(AppTheme.cardBorder)
            }
        }
        .buttonStyle(.plain)
    }

    private func cardInputField(
        title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Typography.fieldLabel)
                .foregroundStyle(AppTheme.tertiaryText)
            TextField(title, text: text)
                .keyboardType(keyboard)
                .foregroundStyle(AppTheme.primaryText)
                .font(Typography.actionLabel)
                .focused($isFieldFocused)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .kinexCard(cornerRadius: 8, fill: AppTheme.cardBackgroundElevated)
        }
    }

    private func metricText(_ value: String) -> some View {
        Text(value)
            .font(Typography.metric)
            .foregroundStyle(AppTheme.secondaryText)
    }

    private func blockHeader(_ block: WorkoutBlockContext, order: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: block.type.iconName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
            Text("Block \(order): \(block.title)")
                .font(Typography.fieldLabel)
                .foregroundStyle(AppTheme.secondaryText)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .kinexCard(cornerRadius: 10, fill: AppTheme.cardBackgroundElevated)
    }

    private func binding(for id: UUID) -> Binding<EditableWorkoutCard>? {
        guard let index = cards.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return $cards[index]
    }

    private func indexForCard(id: UUID) -> Int {
        cards.firstIndex(where: { $0.id == id }) ?? 0
    }

    private func shouldShowBlockHeader(for card: EditableWorkoutCard) -> Bool {
        guard let block = card.block,
              let currentIndex = cards.firstIndex(where: { $0.id == card.id }) else {
            return false
        }

        guard currentIndex > 0 else { return true }
        return cards[currentIndex - 1].block?.identityKey != block.identityKey
    }

    private func blockOrder(for card: EditableWorkoutCard) -> Int {
        guard let currentIndex = cards.firstIndex(where: { $0.id == card.id }) else {
            return 1
        }

        var order = 0
        var lastIdentity: String?

        for candidate in cards.prefix(currentIndex + 1) {
            guard let identity = candidate.block?.identityKey else {
                lastIdentity = nil
                continue
            }
            if identity != lastIdentity {
                order += 1
                lastIdentity = identity
            }
        }

        return max(order, 1)
    }

    private func addCard() {
        let inheritedBlock = cards.last?.block
        let defaultSets = (rounds != nil || inheritedBlock != nil) ? "1" : ""
        let newCard = EditableWorkoutCard(
            name: "",
            sets: defaultSets,
            reps: "",
            weight: "",
            restSeconds: "\(defaultRestSeconds)",
            block: inheritedBlock
        )
        cards.append(newCard)
        editingCardID = newCard.id
    }

    private func removeCard(id: UUID) {
        cards.removeAll { $0.id == id }
        if editingCardID == id {
            editingCardID = nil
        }
    }
}

// MARK: - Drop Delegate

struct CardReorderDropDelegate: DropDelegate {
    let item: EditableWorkoutCard?
    @Binding var cards: [EditableWorkoutCard]
    @Binding var draggedCard: EditableWorkoutCard?

    func dropEntered(info: DropInfo) {
        guard let draggedCard else { return }
        guard let fromIndex = cards.firstIndex(of: draggedCard) else { return }

        if let item {
            guard item != draggedCard else { return }
            guard let toIndex = cards.firstIndex(of: item) else { return }
            if cards[toIndex] != draggedCard {
                withAnimation {
                    cards.move(
                        fromOffsets: IndexSet(integer: fromIndex),
                        toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
                    )
                }
            }
        } else {
            let targetIndex = cards.count - 1
            guard targetIndex >= 0, fromIndex != targetIndex else { return }
            withAnimation {
                cards.move(
                    fromOffsets: IndexSet(integer: fromIndex),
                    toOffset: cards.count
                )
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedCard = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
