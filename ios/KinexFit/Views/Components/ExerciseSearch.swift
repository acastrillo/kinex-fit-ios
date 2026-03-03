import SwiftUI

/// Exercise search and sort controls
struct ExerciseSearchAndSort: View {
    @Binding var searchText: String
    @Binding var sortOption: ExerciseSortOption

    enum SortOption: String, CaseIterable {
        case nameAZ = "A-Z"
        case nameZA = "Z-A"
        case mostUsed = "Most Used"
        case recentlyUsed = "Recently Used"

        var displayName: String {
            self.rawValue
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.secondaryText)

                TextField("Search exercises", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .regular))

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
            .padding(10)
            .background(AppTheme.cardBackgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Sort menu
            Menu {
                ForEach(ExerciseSortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                    } label: {
                        HStack {
                            Text(option.displayName)
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 14, weight: .semibold))
                    Text(sortOption.displayName)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .kinexCard(cornerRadius: 8)
            }
        }
    }
}

enum ExerciseSortOption: String, CaseIterable, Equatable {
    case nameAZ = "A-Z"
    case nameZA = "Z-A"
    case mostUsed = "Most Used"
    case recentlyUsed = "Recently Used"

    var displayName: String {
        self.rawValue
    }
}

// MARK: - Preview

#if DEBUG
struct ExerciseSearchAndSort_Previews: PreviewProvider {
    @State static var searchText = ""
    @State static var sortOption = ExerciseSortOption.nameAZ

    static var previews: some View {
        ExerciseSearchAndSort(
            searchText: $searchText,
            sortOption: $sortOption
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
