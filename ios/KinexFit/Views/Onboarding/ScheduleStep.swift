import SwiftUI

struct ScheduleStep: View {
    @Binding var daysPerWeek: Int?
    @Binding var sessionDuration: Int?
    let onContinue: () -> Void

    private let daysOptions = [1, 2, 3, 4, 5, 6, 7]
    private let durationOptions = [30, 45, 60, 90]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)

                    Text("How often do you train?")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Help us understand your availability")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)
                .padding(.horizontal)

                // Days per week
                VStack(alignment: .leading, spacing: 16) {
                    Text("Training Days Per Week")
                        .font(.headline)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(daysOptions, id: \.self) { days in
                            DayOptionButton(
                                days: days,
                                isSelected: daysPerWeek == days,
                                onSelect: {
                                    daysPerWeek = days
                                }
                            )
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground).opacity(0.8))
                )
                .padding(.horizontal)

                // Session duration
                VStack(alignment: .leading, spacing: 16) {
                    Text("Typical Session Duration")
                        .font(.headline)

                    VStack(spacing: 12) {
                        ForEach(durationOptions, id: \.self) { duration in
                            DurationOptionButton(
                                duration: duration,
                                isSelected: sessionDuration == duration,
                                onSelect: {
                                    sessionDuration = duration
                                }
                            )
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground).opacity(0.8))
                )
                .padding(.horizontal)

                Spacer()
                    .frame(height: 100)
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Continue button
            Button {
                onContinue()
            } label: {
                HStack {
                    Text("Continue")
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canContinue ? Color.blue : Color.gray)
                .foregroundStyle(.white)
                .fontWeight(.semibold)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canContinue)
            .padding(.horizontal)
            .padding(.vertical, 16)
            .background(Color(.systemBackground).opacity(0.95))
        }
    }

    private var canContinue: Bool {
        daysPerWeek != nil && sessionDuration != nil
    }
}

struct DayOptionButton: View {
    let days: Int
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Text("\(days)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(days == 1 ? "day" : "days")
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.systemGray5))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct DurationOptionButton: View {
    let duration: Int
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(isSelected ? .blue : .secondary)

                Text("\(duration) minutes")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ScheduleStep(daysPerWeek: .constant(4), sessionDuration: .constant(60), onContinue: {})
}
