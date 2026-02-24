import SwiftUI

struct CalendarTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var workouts: [Workout] = []
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var displayedMonth = Calendar.current.startOfDay(for: Date())

    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols
    private var workoutRepository: WorkoutRepository { appState.environment.workoutRepository }
    private var calendar: Calendar { Calendar.current }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                calendarCard
                workoutsForDayCard
                monthlySummaryCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 30)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .refreshable {
            await loadWorkouts()
        }
        .task {
            await loadWorkouts()
            displayedMonth = startOfMonth(for: selectedDate)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Workout\nCalendar")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Text("Track your fitness journey")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer(minLength: 12)

            Button {
                appState.navigateToTab(.add)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "plus")
                    Text("Schedule Workout")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: AppTheme.accent.opacity(0.33), radius: 14, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(monthTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(8)
                }
                .buttonStyle(.plain)

                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }

            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 8) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        calendarDayCell(date)
                    } else {
                        Color.clear
                            .frame(height: 42)
                    }
                }
            }
        }
        .padding(16)
        .kinexCard(cornerRadius: 18)
    }

    private var workoutsForDayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workouts on \(selectedDate.formatted(.dateTime.month(.defaultDigits).day().year()))")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            if workoutsForSelectedDate.isEmpty {
                Text("No workouts scheduled. Tap Schedule Workout to plan your next session.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(workoutsForSelectedDate) { workout in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(workout.title)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryText)
                                .lineLimit(2)

                            Text(workoutMetadata(workout))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                    .padding(12)
                    .kinexCard(cornerRadius: 12, fill: AppTheme.cardBackgroundElevated)
                }
            }
        }
        .padding(16)
        .kinexCard(cornerRadius: 18)
    }

    private var monthlySummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Month")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            HStack {
                Label("Workouts", systemImage: "dumbbell.fill")
                Spacer()
                Text("\(workoutsThisMonth.count)")
                    .fontWeight(.semibold)
            }

            HStack {
                Label("Hours", systemImage: "clock.fill")
                Spacer()
                Text(formattedMonthlyHours)
                    .fontWeight(.semibold)
            }
        }
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(AppTheme.secondaryText)
        .padding(16)
        .kinexCard(cornerRadius: 18, fill: AppTheme.cardBackgroundElevated)
    }

    private func calendarDayCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isInDisplayedMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
        let workoutCount = workoutsOnDate(date).count

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        isSelected ? Color.white :
                            (isInDisplayedMonth ? AppTheme.primaryText : AppTheme.tertiaryText)
                    )

                if workoutCount > 1 {
                    Text("\(workoutCount)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(AppTheme.accent)
                        .clipShape(Capsule())
                } else if workoutCount == 1 {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 5, height: 5)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 42)
            .frame(maxWidth: .infinity)
            .background(isSelected ? AppTheme.accent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var monthDays: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let leadingSpaces = max(0, firstWeekday - 1)
        var results: [Date?] = Array(repeating: nil, count: leadingSpaces)

        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                results.append(date)
            }
        }

        while results.count % 7 != 0 {
            results.append(nil)
        }

        return results
    }

    private var workoutsForSelectedDate: [Workout] {
        workoutsOnDate(selectedDate)
    }

    private var workoutsThisMonth: [Workout] {
        workouts.filter { workout in
            calendar.isDate(workout.createdAt, equalTo: displayedMonth, toGranularity: .month)
        }
    }

    private var formattedMonthlyHours: String {
        let totalMinutes = workoutsThisMonth.reduce(0) { partialResult, workout in
            partialResult + (workout.durationMinutes ?? 45)
        }
        let hours = Double(totalMinutes) / 60.0
        return String(format: "%.1fh", hours)
    }

    private func workoutsOnDate(_ date: Date) -> [Workout] {
        workouts.filter { workout in
            calendar.isDate(workout.createdAt, inSameDayAs: date)
        }
    }

    private func workoutMetadata(_ workout: Workout) -> String {
        let exercises = workout.exerciseCount ?? estimateExerciseCount(from: workout.content)
        let duration = workout.durationMinutes ?? estimateDurationMinutes(from: workout)
        return "\(exercises) exercises • \(duration) min"
    }

    private func estimateDurationMinutes(from workout: Workout) -> Int {
        if let duration = workout.durationMinutes, duration > 0 {
            return duration
        }
        return 45
    }

    private func estimateExerciseCount(from content: String?) -> Int {
        guard let content, !content.isEmpty else { return 6 }
        let lines = content
            .split(whereSeparator: \.isNewline)
            .filter { !String($0).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return min(max(lines.count, 1), 20)
    }

    private func startOfMonth(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func loadWorkouts() async {
        workouts = (try? await workoutRepository.fetchAll()) ?? []
    }
}

#Preview {
    CalendarTab()
        .environmentObject(AppState(environment: .preview))
        .appDarkTheme()
}
