import SwiftUI

func runMatchesProject(_ run: LabRun, projectFilter: String, projects: [Project]) -> Bool {
    guard let projectID = run.projectID else { return false }
    if projectID == projectFilter { return true }
    guard let project = projects.first(where: { $0.id == projectFilter }) else { return false }
    return projectID == project.name
}

private struct ProjectCalendarDot: Identifiable {
    let projectID: String
    let color: Color

    var id: String { projectID }
}

private func projectForRun(_ run: LabRun, projects: [Project]) -> Project? {
    guard let projectID = run.projectID else { return nil }
    return projects.first { $0.id == projectID || $0.name == projectID }
}

private func projectDots(for runs: [LabRun], projects: [Project]) -> [ProjectCalendarDot] {
    var seen = Set<String>()
    var dots: [ProjectCalendarDot] = []
    for run in runs {
        guard let project = projectForRun(run, projects: projects),
            !seen.contains(project.id)
        else { continue }
        seen.insert(project.id)
        dots.append(ProjectCalendarDot(projectID: project.id, color: Color(hex: project.colorHex)))
    }
    return dots
}

struct ExperimentCalendarView: View {
    let days: [ExperimentDayRecord]
    @Binding var selectedDayID: String
    var projects: [Project] = []
    var projectFilter: String? = nil

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

    private var selectableDays: [ExperimentDayRecord] {
        guard let projectFilter else { return days }
        return days.filter { day in
            projectDots(for: day.runs, projects: projects).contains {
                $0.projectID == projectFilter
            }
        }
    }

    private var selectableRecordIndex: [String: ExperimentDayRecord] {
        Dictionary(uniqueKeysWithValues: selectableDays.map { ($0.id, $0) })
    }

    private var selectedProject: Project? {
        guard let projectFilter else { return nil }
        return projects.first { $0.id == projectFilter }
    }

    // All days in the displayed month (padded to start on Monday)
    private var gridDays: [Date?] {
        let comps = cal.dateComponents([.year, .month], from: displayMonth)
        guard let firstOfMonth = cal.date(from: comps),
            let range = cal.range(of: .day, in: .month, for: firstOfMonth)
        else { return [] }

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

    private func monthStart(_ date: Date) -> Date {
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? cal.startOfDay(for: date)
    }

    private func monthByAdding(_ value: Int) -> Date {
        let start = monthStart(displayMonth)
        return cal.date(byAdding: .month, value: value, to: start) ?? displayMonth
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
                    displayMonth = monthByAdding(-1)
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
                    let next = monthByAdding(1)
                    // don't navigate past current month
                    if monthStart(next) <= monthStart(Date()) {
                        displayMonth = next
                    }
                } label: {
                    let next = monthByAdding(1)
                    let canForward = monthStart(next) <= monthStart(Date())
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(canForward ? .teal : .secondary.opacity(0.3))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(
                    {
                        let next = monthByAdding(1)
                        return monthStart(next) > monthStart(Date())
                    }())
            }

            // Weekday header: 一 二 三 四 五 六 日
            let weekdaySymbols = ["一", "二", "三", "四", "五", "六", "日"]
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4
            ) {
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
                            selectableRecord: selectableRecordIndex[dayKey(date)],
                            isSelected: selectedDayID == dayKey(date),
                            isToday: isToday(date),
                            isFuture: isFuture(date),
                            cellScale: cellScale,
                            projects: projects,
                            projectFilter: projectFilter,
                            selectedProject: selectedProject
                        ) {
                            let key = dayKey(date)
                            if selectableRecordIndex[key] != nil,
                                let record = recordIndex[key],
                                dayContainsSelectedProjectDot(record)
                            {
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
            syncSelectionToFilter()
        }
        .onChange(of: projectFilter) { _, _ in
            syncSelectionToFilter()
        }
    }

    private func syncSelectionToFilter() {
        let nextDay =
            selectableDays.first { $0.id == selectedDayID } ?? selectableDays.first ?? days.first
        guard let nextDay else { return }
        selectedDayID = nextDay.id

        let raw = String(nextDay.id.dropFirst("past-".count))
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy-MM-dd"
        if let date = fmt.date(from: raw) {
            displayMonth = date
        }
    }

    private func dayContainsSelectedProjectDot(_ day: ExperimentDayRecord) -> Bool {
        guard let projectFilter else { return !day.runs.isEmpty }
        return projectDots(for: day.runs, projects: projects).contains {
            $0.projectID == projectFilter
        }
    }
}

struct FuturePlanCalendarView: View {
    let runs: [LabRun]
    @Binding var selectedDate: Date
    var projects: [Project] = []
    var projectFilter: String? = nil

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

    private var tomorrow: Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: Date()) ?? Date())
    }

    private var selectedProject: Project? {
        guard let projectFilter else { return nil }
        return projects.first { $0.id == projectFilter }
    }

    private var monthTitle: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy年M月"
        return fmt.string(from: displayMonth)
    }

    private var gridDays: [Date?] {
        let comps = cal.dateComponents([.year, .month], from: displayMonth)
        guard let firstOfMonth = cal.date(from: comps),
            let range = cal.range(of: .day, in: .month, for: firstOfMonth)
        else { return [] }

        let firstWeekday = (cal.component(.weekday, from: firstOfMonth) + 5) % 7
        var result: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            result.append(cal.date(byAdding: .day, value: day - 1, to: firstOfMonth))
        }
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    private func monthStart(_ date: Date) -> Date {
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? cal.startOfDay(for: date)
    }

    private func monthByAdding(_ value: Int) -> Date {
        let start = monthStart(displayMonth)
        return cal.date(byAdding: .month, value: value, to: start) ?? displayMonth
    }

    private func dayKey(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.calendar = cal
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    private func runs(for date: Date) -> [LabRun] {
        let key = dayKey(date)
        let fallback = dayKey(tomorrow)
        let dayRuns = runs.filter { ($0.planDateKey ?? fallback) == key }
        guard let projectFilter else { return dayRuns }
        return dayRuns.filter {
            runMatchesProject($0, projectFilter: projectFilter, projects: projects)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button {
                    displayMonth = monthByAdding(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.teal)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(monthStart(monthByAdding(-1)) < monthStart(tomorrow))

                Spacer()

                Text(monthTitle)
                    .font(.headline)

                Spacer()

                Button {
                    displayMonth = monthByAdding(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.teal)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }

            let weekdaySymbols = ["一", "二", "三", "四", "五", "六", "日"]
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4
            ) {
                ForEach(weekdaySymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(gridDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let planRuns = runs(for: date)
                        FutureCalendarGridCell(
                            date: date,
                            runs: planRuns,
                            isSelected: cal.isDate(date, inSameDayAs: selectedDate),
                            isToday: cal.isDateInToday(date),
                            isBeforeTomorrow: cal.startOfDay(for: date) < tomorrow,
                            cellScale: cellScale,
                            projects: projects,
                            projectFilter: projectFilter,
                            selectedProject: selectedProject
                        ) {
                            selectedDate = cal.startOfDay(for: date)
                        }
                    } else {
                        Color.clear
                            .frame(height: baseCellHeight * cellScale)
                    }
                }
            }

            Text("选择未来日期，提前安排实验计划")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.65))
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
                .onEnded { _ in
                    lastScale = cellScale
                }
        )
        .onAppear {
            displayMonth = monthStart(selectedDate)
        }
        .onChange(of: selectedDate) { _, newValue in
            displayMonth = monthStart(newValue)
        }
    }
}

private let baseCellHeight: CGFloat = 44

private struct CalendarGridCell: View {
    let date: Date
    let record: ExperimentDayRecord?
    let selectableRecord: ExperimentDayRecord?
    let isSelected: Bool
    let isToday: Bool
    let isFuture: Bool
    let cellScale: CGFloat
    var projects: [Project] = []
    var projectFilter: String? = nil
    var selectedProject: Project? = nil
    let onTap: () -> Void

    private var dayNumber: String {
        let cal = Calendar(identifier: .gregorian)
        return "\(cal.component(.day, from: date))"
    }

    private var hasRecord: Bool { record != nil }
    private var isSelectable: Bool { selectableRecord != nil }
    private var activeColor: Color {
        if let selectedProject {
            return Color(hex: selectedProject.colorHex)
        }
        return .teal
    }
    private var inactiveRecordOpacity: Double {
        projectFilter == nil ? 0.35 : 0.16
    }

    // Project-color dots for experiments on this day
    private var dotColors: [Color] {
        visibleProjectDots.prefix(3).map(\.color)
    }

    private var allProjectDots: [ProjectCalendarDot] {
        projectDots(for: record?.runs ?? [], projects: projects)
    }

    private var visibleProjectDots: [ProjectCalendarDot] {
        if let projectFilter {
            return allProjectDots.filter { $0.projectID == projectFilter }
        } else {
            return allProjectDots
        }
    }

    private var containsSelectedProjectDot: Bool {
        guard let projectFilter else { return hasRecord }
        return allProjectDots.contains { $0.projectID == projectFilter }
    }

    private var shouldLightDate: Bool {
        isSelectable && containsSelectedProjectDot
    }

    var body: some View {
        let cellH = baseCellHeight * cellScale
        let isDisabled = isFuture || !shouldLightDate

        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(dayNumber)
                    .font(
                        .system(
                            size: max(11, 14 * cellScale),
                            weight: isToday ? .bold : hasRecord ? .semibold : .regular)
                    )
                    .foregroundStyle(
                        isSelected
                            ? .white
                            : isFuture
                                ? Color.secondary.opacity(0.25)
                                : isToday
                                    ? activeColor
                                    : shouldLightDate
                                        ? activeColor
                                        : hasRecord
                                            ? Color.secondary.opacity(inactiveRecordOpacity)
                                            : Color.secondary.opacity(0.25)
                    )

                if cellScale > 0.75 && shouldLightDate {
                    HStack(spacing: 2) {
                        ForEach(Array(dotColors.enumerated()), id: \.offset) { _, color in
                            Circle()
                                .fill(isSelected ? Color.white.opacity(0.9) : color)
                                .frame(width: 4, height: 4)
                        }
                        if dotColors.isEmpty {
                            Circle()
                                .fill(isSelected ? Color.white.opacity(0.9) : activeColor)
                                .frame(width: 4, height: 4)
                        }
                    }
                } else {
                    // minimal: just a thin tint line for days with records
                    if shouldLightDate && !isSelected {
                        Capsule()
                            .fill(activeColor.opacity(0.5))
                            .frame(width: 16, height: 2)
                    } else {
                        Color.clear.frame(height: 2)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: cellH)
            .background(
                isSelected
                    ? activeColor
                    : isToday && !isSelected
                        ? activeColor.opacity(0.10)
                        : shouldLightDate
                            ? activeColor.opacity(0.08)
                            : hasRecord && projectFilter == nil
                                ? Color.teal.opacity(0.04) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        shouldLightDate && !isSelected ? activeColor.opacity(0.18) : Color.clear,
                        lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

private struct FutureCalendarGridCell: View {
    let date: Date
    let runs: [LabRun]
    let isSelected: Bool
    let isToday: Bool
    let isBeforeTomorrow: Bool
    let cellScale: CGFloat
    var projects: [Project] = []
    var projectFilter: String? = nil
    var selectedProject: Project? = nil
    let onTap: () -> Void

    private var dayNumber: String {
        "\(Calendar(identifier: .gregorian).component(.day, from: date))"
    }

    private var hasPlans: Bool { !runs.isEmpty }

    private var activeColor: Color {
        if let selectedProject {
            return Color(hex: selectedProject.colorHex)
        }
        return .teal
    }

    private var dotColors: [Color] {
        let dots = projectDots(for: runs, projects: projects)
        let visible = projectFilter == nil ? dots : dots.filter { $0.projectID == projectFilter }
        return visible.prefix(3).map(\.color)
    }

    var body: some View {
        let cellH = baseCellHeight * cellScale

        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(dayNumber)
                    .font(
                        .system(
                            size: max(11, 14 * cellScale),
                            weight: isSelected || hasPlans ? .semibold : .regular)
                    )
                    .foregroundStyle(
                        isSelected
                            ? .white
                            : isBeforeTomorrow
                                ? Color.secondary.opacity(0.24)
                                : isToday
                                    ? activeColor
                                    : hasPlans ? activeColor : Color.secondary.opacity(0.62)
                    )

                if cellScale > 0.75 && hasPlans {
                    HStack(spacing: 2) {
                        ForEach(Array(dotColors.enumerated()), id: \.offset) { _, color in
                            Circle()
                                .fill(isSelected ? Color.white.opacity(0.9) : color)
                                .frame(width: 4, height: 4)
                        }
                        if dotColors.isEmpty {
                            Circle()
                                .fill(isSelected ? Color.white.opacity(0.9) : activeColor)
                                .frame(width: 4, height: 4)
                        }
                    }
                } else {
                    Color.clear.frame(height: 2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: cellH)
            .background(
                isSelected
                    ? activeColor
                    : hasPlans
                        ? activeColor.opacity(0.10)
                        : isToday ? activeColor.opacity(0.06) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        hasPlans && !isSelected ? activeColor.opacity(0.18) : Color.clear,
                        lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isBeforeTomorrow)
    }
}

struct ExperimentDayDetailView: View {
    let day: ExperimentDayRecord
    let completedStepIDs: Set<String>
    var projects: [Project] = []
    var projectFilter: String? = nil
    @State private var selectedRun: LabRun?

    private var filteredRuns: [LabRun] {
        guard let projectFilter else { return day.runs }
        return day.runs.filter {
            runMatchesProject($0, projectFilter: projectFilter, projects: projects)
        }
    }

    private var selectedProject: Project? {
        guard let projectFilter else { return nil }
        return projects.first { $0.id == projectFilter }
    }

    private var headerTitle: String {
        if let selectedProject {
            return "\(day.dateLabel) · \(selectedProject.name)"
        }
        return day.dateLabel
    }

    private var headerSummary: String {
        if let selectedProject {
            return "\(selectedProject.name) · \(filteredRuns.count) 个实验"
        }
        return day.summary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(headerTitle).font(.title3.bold())
                    Text(headerSummary).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(day.weekday).font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(
                        .secondary)
            }

            if filteredRuns.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "calendar.badge.plus").font(.title2).foregroundStyle(.teal)
                    Text(projectFilter == nil ? "这一天还没有实验记录" : "这一天没有该项目实验").font(.headline)
                    Text(projectFilter == nil ? "超过今天后，完成或计划的实验会进入这里。" : "切换到「全部」可查看当天其他项目。").font(
                        .subheadline
                    ).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredRuns) { run in
                        Button {
                            selectedRun = run
                        } label: {
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(projectColor(for: run))
                                    .frame(width: 4)
                                Text(run.timeLabel)
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .frame(width: 48, alignment: .leading)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(run.title).font(.subheadline.weight(.semibold))
                                    Text(
                                        "\(run.area.rawValue) · \(run.steps.filter { completedStepIDs.contains($0.id) }.count)/\(run.steps.count) 步"
                                    )
                                    .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.weight(.bold))
                                    .foregroundStyle(
                                        .tertiary)
                            }
                            .padding(10)
                            .background(
                                projectColor(for: run).opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(projectColor(for: run).opacity(0.18), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
        .sheet(item: $selectedRun) { run in
            PastRunDetailSheet(
                run: run, completedStepIDs: completedStepIDs, project: project(for: run))
        }
    }

    private func project(for run: LabRun) -> Project? {
        projectForRun(run, projects: projects)
    }

    private func projectColor(for run: LabRun) -> Color {
        guard let hex = project(for: run)?.colorHex else { return .teal }
        return Color(hex: hex)
    }
}

private struct PastRunDetailSheet: View {
    let run: LabRun
    let completedStepIDs: Set<String>
    let project: Project?
    @Environment(\.dismiss) private var dismiss
    @State private var showDataCard = false

    private var projectColor: Color {
        if let hex = project?.colorHex { return Color(hex: hex) }
        return .teal
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(projectColor)
                                .frame(width: 5, height: 56)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(run.title)
                                    .font(.title2.bold())
                                Text("\(run.area.rawValue) · \(run.timeLabel)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let project {
                                    Text(project.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(projectColor)
                                }
                            }
                            Spacer()
                        }
                        Text(run.scaledVolumeLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(projectColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("实验步骤")
                            .font(.headline)
                        ForEach(Array(run.steps.enumerated()), id: \.element.id) { index, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.subheadline.monospacedDigit().weight(.bold))
                                    .foregroundStyle(projectColor)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(step.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(step.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let minutes = step.durationMinutes {
                                        Text("\(minutes) min")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(projectColor)
                                    }
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(18)
            }
            .background(Color.labBackground)
            .navigationTitle("实验记录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showDataCard = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showDataCard) {
                DataCardSheet(run: run, completedStepIDs: completedStepIDs)
            }
        }
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
            let matching = day.runs.filter {
                runMatchesProject($0, projectFilter: projectFilter, projects: projects)
            }
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
                                    Text(
                                        "\(run.area.rawValue) · \(run.steps.filter { completedStepIDs.contains($0.id) }.count)/\(run.steps.count) 步"
                                    )
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
