import SwiftUI

struct ExperimentCalendarView: View {
    let days: [ExperimentDayRecord]
    @Binding var selectedDayID: String
    var projects: [Project] = []

    @State private var displayMonth: Date = {
        Calendar(identifier: .gregorian).startOfDay(for: Date())
    }()
    @State private var cellScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "zh_CN")
        return c
    }

    private var recordIndex: [String: ExperimentDayRecord] {
        Dictionary(uniqueKeysWithValues: days.map { ($0.id, $0) })
    }

    // All days in the displayed month (padded to start on Monday)
    private var gridDays: [Date?] {
        let comps = cal.dateComponents([.year, .month], from: displayMonth)
        guard let firstOfMonth = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else { return [] }

        // weekday index 0=Mon … 6=Sun
        let firstWeekday = (cal.component(.weekday, from: firstOfMonth) + 5) % 7
        var result: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            result.append(cal.date(byAdding: .day, value: day - 1, to: firstOfMonth))
        }
        // pad to full rows
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    private var monthTitle: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy年M月"
        return fmt.string(from: displayMonth)
    }

    private func dayKey(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.calendar = cal
        fmt.dateFormat = "yyyy-MM-dd"
        return "past-\(fmt.string(from: date))"
    }

    private func isToday(_ date: Date) -> Bool {
        cal.isDateInToday(date)
    }

    private func isFuture(_ date: Date) -> Bool {
        cal.startOfDay(for: date) > cal.startOfDay(for: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Month navigation header
            HStack {
                Button {
                    displayMonth = cal.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.teal)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle)
                    .font(.headline)

                Spacer()

                Button {
                    let next = cal.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
                    // don't navigate past current month
                    if cal.startOfDay(for: next) <= cal.startOfDay(for: Date()) {
                        displayMonth = next
                    }
                } label: {
                    let next = cal.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
                    let canForward = cal.startOfDay(for: next) <= cal.startOfDay(for: Date())
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(canForward ? .teal : .secondary.opacity(0.3))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .disabled({
                    let next = cal.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
                    return cal.startOfDay(for: next) > cal.startOfDay(for: Date())
                }())
            }

            // Weekday header: 一 二 三 四 五 六 日
            let weekdaySymbols = ["一", "二", "三", "四", "五", "六", "日"]
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                // Day cells
                ForEach(Array(gridDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        CalendarGridCell(
                            date: date,
                            record: recordIndex[dayKey(date)],
                            isSelected: selectedDayID == dayKey(date),
                            isToday: isToday(date),
                            isFuture: isFuture(date),
                            cellScale: cellScale,
                            projects: projects
                        ) {
                            let key = dayKey(date)
                            if recordIndex[key] != nil {
                                selectedDayID = key
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: baseCellHeight * cellScale)
                    }
                }
            }

            // Pinch-to-zoom hint
            Text("双指缩放可调整大小")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    let proposed = lastScale * value
                    cellScale = min(max(proposed, 0.6), 1.6)
                }
                .onEnded { value in
                    lastScale = cellScale
                }
        )
        // Jump to the month that contains the selected record when view appears
        .onAppear {
            if let day = days.first(where: { $0.id == selectedDayID }) ?? days.first {
                selectedDayID = day.id
                // parse the date from id "past-yyyy-MM-dd"
                let raw = String(day.id.dropFirst("past-".count))
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "zh_CN")
                fmt.dateFormat = "yyyy-MM-dd"
                if let date = fmt.date(from: raw) {
                    displayMonth = date
                }
            }
        }
    }
}

private let baseCellHeight: CGFloat = 44

private struct CalendarGridCell: View {
    let date: Date
    let record: ExperimentDayRecord?
    let isSelected: Bool
    let isToday: Bool
    let isFuture: Bool
    let cellScale: CGFloat
    var projects: [Project] = []
    let onTap: () -> Void

    private var dayNumber: String {
        let cal = Calendar(identifier: .gregorian)
        return "\(cal.component(.day, from: date))"
    }

    private var hasRecord: Bool { record != nil }

    // Project-color dots for experiments on this day
    private var dotColors: [Color] {
        guard let runs = record?.runs else { return [] }
        let projectIDs = Array(Set(runs.compactMap(\.projectID)))
        return projectIDs.prefix(3).compactMap { pid in
            guard let hex = projects.first(where: { $0.id == pid })?.colorHex else { return nil }
            return Color(hex: hex)
        }
    }

    var body: some View {
        let cellH = baseCellHeight * cellScale
        let isDisabled = isFuture || !hasRecord

        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(dayNumber)
                    .font(.system(size: max(11, 14 * cellScale), weight: isToday ? .bold : hasRecord ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected ? .white :
                        isFuture ? Color.secondary.opacity(0.25) :
                        isToday ? .teal :
                        hasRecord ? .primary : Color.secondary.opacity(0.35)
                    )

                if cellScale > 0.75 && hasRecord {
                    HStack(spacing: 2) {
                        ForEach(Array(dotColors.enumerated()), id: \.offset) { _, color in
                            Circle()
                                .fill(isSelected ? Color.white.opacity(0.9) : color)
                                .frame(width: 4, height: 4)
                        }
                    }
                } else {
                    // minimal: just a thin tint line for days with records
                    if hasRecord && !isSelected {
                        Capsule()
                            .fill(Color.teal.opacity(0.5))
                            .frame(width: 16, height: 2)
                    } else {
                        Color.clear.frame(height: 2)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: cellH)
            .background(
                isSelected ? Color.teal :
                isToday && !isSelected ? Color.teal.opacity(0.1) :
                Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct ExperimentDayDetailView: View {
    let day: ExperimentDayRecord
    let completedStepIDs: Set<String>
    var projects: [Project] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(day.dateLabel).font(.title3.bold())
                    Text(day.summary).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(day.weekday).font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(.secondary)
            }

            if day.runs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "calendar.badge.plus").font(.title2).foregroundStyle(.teal)
                    Text("这一天还没有实验记录").font(.headline)
                    Text("超过今天后，完成或计划的实验会进入这里。").font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 8) {
                    ForEach(day.runs) { run in
                        HStack(spacing: 10) {
                            Text(run.timeLabel)
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .frame(width: 48, alignment: .leading)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(run.title).font(.subheadline.weight(.semibold))
                                Text("\(run.area.rawValue) · \(run.steps.filter { completedStepIDs.contains($0.id) }.count)/\(run.steps.count) 步")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                        }
                        .padding(10)
                        .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Project Days List (past view when project filter active)

struct ProjectDaysListView: View {
    let days: [ExperimentDayRecord]
    let projectFilter: String
    let projects: [Project]
    let completedStepIDs: Set<String>

    private var projectName: String {
        projects.first { $0.id == projectFilter }?.name ?? ""
    }
    private var projectColor: Color {
        if let hex = projects.first(where: { $0.id == projectFilter })?.colorHex {
            return Color(hex: hex)
        }
        return .teal
    }

    private var matchingDays: [(day: ExperimentDayRecord, runs: [LabRun])] {
        days.compactMap { day in
            let matching = day.runs.filter { $0.projectID == projectFilter }
            guard !matching.isEmpty else { return nil }
            return (day, matching)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(projectColor)
                    .frame(width: 10, height: 10)
                Text("\(projectName) · \(matchingDays.count) 天")
                    .font(.headline)
                Spacer()
            }

            if matchingDays.isEmpty {
                Text("暂无实验记录")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical)
            } else {
                ForEach(matchingDays, id: \.day.id) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.day.dateLabel)
                                .font(.subheadline.weight(.semibold))
                            Text(item.day.weekday)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(item.runs.count) 个实验")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(projectColor.opacity(0.12), in: Capsule())
                                .foregroundStyle(projectColor)
                        }
                        ForEach(item.runs) { run in
                            HStack(spacing: 10) {
                                Text(run.timeLabel)
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .frame(width: 48, alignment: .leading)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(run.title).font(.subheadline.weight(.semibold))
                                    Text("\(run.area.rawValue) · \(run.steps.filter { completedStepIDs.contains($0.id) }.count)/\(run.steps.count) 步")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.leading, 8)
                        }
                    }
                    .padding(14)
                    .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Timer Dock
