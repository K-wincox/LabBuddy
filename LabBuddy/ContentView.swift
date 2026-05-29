import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ContentView: View {
    @State private var importedRuns: [LabRun] = []
    @State private var tomorrowRuns: [LabRun] = []
    @State private var inventoryItems: [InventoryItem] = SampleData.inventory

    var body: some View {
        TabView {
            TodayView(importedRuns: importedRuns)
                .environment(\.removeImportedRun, { runID in
                    importedRuns.removeAll { $0.id == runID }
                    tomorrowRuns.removeAll { $0.id == runID }
                })
                .environment(\.tomorrowRuns, tomorrowRuns)
                .environment(\.scheduleProtocolRun, { labProtocol, targetVolume, targetDay, timeLabel in
                    importRun(
                        from: labProtocol,
                        targetVolume: targetVolume,
                        targetDay: targetDay,
                        timeLabel: timeLabel
                    )
                })
                .tabItem {
                    Label("今日", systemImage: "calendar")
                }

            ProtocolsView()
                .tabItem {
                    Label("Protocol", systemImage: "list.clipboard")
                }

            ToolsView()
                .tabItem {
                    Label("工具", systemImage: "function")
                }

            ProfileView(
                items: $inventoryItems,
                resetDemoData: resetDemoData
            )
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
        }
        .tint(.teal)
        .onAppear {
            loadImportedRuns()
            loadTomorrowRuns()
            loadInventoryItems()
        }
        .onChange(of: importedRuns) {
            saveImportedRuns(importedRuns)
        }
        .onChange(of: tomorrowRuns) {
            saveTomorrowRuns(tomorrowRuns)
        }
        .onChange(of: inventoryItems) {
            saveInventoryItems(inventoryItems)
        }
    }

    private func importRun(from labProtocol: LabProtocol, targetVolume: Double, targetDay: PlanTargetDay, timeLabel: String) {
        let factor = targetVolume / labProtocol.baseVolume
        let recipeSummary = labProtocol.ingredients
            .prefix(3)
            .map { "\($0.name) \($0.scaled(by: factor))" }
            .joined(separator: " / ")
        let duration = estimatedMinutes(from: labProtocol.expectedDuration)
        let editableSteps = labProtocol.steps.isEmpty ? [
            LabStep(
                id: "\(labProtocol.id)-execute-\(Int(Date().timeIntervalSince1970))",
                title: "执行 Protocol",
                detail: "按缩放后的用量完成 \(labProtocol.name)",
                durationMinutes: duration,
                isCarryOver: false
            )
        ] : labProtocol.steps
        let run = LabRun(
            id: "import-\(targetDay.rawValue)-\(labProtocol.id)-\(Int(Date().timeIntervalSince1970))",
            title: labProtocol.name,
            area: labProtocol.area,
            timeLabel: timeLabel,
            status: targetDay == .today ? "已排期" : "明日计划",
            protocolName: labProtocol.name,
            scaledVolumeLabel: "\(formattedVolume(targetVolume)) \(labProtocol.volumeUnit) · x\(String(format: "%.2f", factor))",
            steps: [
                LabStep(
                    id: "\(labProtocol.id)-review-\(Int(Date().timeIntervalSince1970))",
                    title: "核对换算配方",
                    detail: recipeSummary,
                    durationMinutes: nil,
                    isCarryOver: false
                )
            ] + editableSteps.map { step in
                LabStep(
                    id: "\(labProtocol.id)-\(step.id)-\(Int(Date().timeIntervalSince1970))",
                    title: step.title,
                    detail: step.detail,
                    durationMinutes: step.durationMinutes ?? duration,
                    isCarryOver: step.isCarryOver
                )
            } + [
                LabStep(
                    id: "\(labProtocol.id)-record-\(Int(Date().timeIntervalSince1970))",
                    title: "记录结果",
                    detail: "完成后生成结果卡片或补充实验备注",
                    durationMinutes: nil,
                    isCarryOver: false
                )
            ]
        )
        switch targetDay {
        case .today:
            importedRuns.insert(run, at: 0)
        case .tomorrow:
            tomorrowRuns.insert(run, at: 0)
        }
    }

    private func loadImportedRuns() {
        guard let data = UserDefaults.standard.data(forKey: "importedLabRuns"),
              let runs = try? JSONDecoder().decode([LabRun].self, from: data) else {
            return
        }
        importedRuns = runs
    }

    private func saveImportedRuns(_ runs: [LabRun]) {
        guard let data = try? JSONEncoder().encode(runs) else {
            return
        }
        UserDefaults.standard.set(data, forKey: "importedLabRuns")
    }

    private func loadTomorrowRuns() {
        guard let data = UserDefaults.standard.data(forKey: "tomorrowLabRuns"),
              let runs = try? JSONDecoder().decode([LabRun].self, from: data) else {
            return
        }
        tomorrowRuns = runs
    }

    private func saveTomorrowRuns(_ runs: [LabRun]) {
        guard let data = try? JSONEncoder().encode(runs) else {
            return
        }
        UserDefaults.standard.set(data, forKey: "tomorrowLabRuns")
    }

    private func loadInventoryItems() {
        guard let data = UserDefaults.standard.data(forKey: "inventoryItems"),
              let items = try? JSONDecoder().decode([InventoryItem].self, from: data) else {
            return
        }
        inventoryItems = items
    }

    private func saveInventoryItems(_ items: [InventoryItem]) {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }
        UserDefaults.standard.set(data, forKey: "inventoryItems")
    }

    private func resetDemoData() {
        importedRuns = []
        inventoryItems = SampleData.inventory
        UserDefaults.standard.removeObject(forKey: "completedStepIDs")
        UserDefaults.standard.removeObject(forKey: "activeLabTimers")
        UserDefaults.standard.removeObject(forKey: "importedLabRuns")
        UserDefaults.standard.removeObject(forKey: "tomorrowLabRuns")
        UserDefaults.standard.removeObject(forKey: "inventoryItems")
    }

    private func estimatedMinutes(from text: String) -> Int? {
        let digits = text.prefix { $0.isNumber }
        guard let minutes = Int(digits), minutes > 0 else {
            return nil
        }
        return minutes
    }

    private func formattedVolume(_ volume: Double) -> String {
        volume.rounded() == volume ? String(format: "%.0f", volume) : String(format: "%.1f", volume)
    }
}

private enum PlanTargetDay: String {
    case today
    case tomorrow
}

private struct TodayView: View {
    let importedRuns: [LabRun]
    @Environment(\.removeImportedRun) private var removeImportedRun
    @Environment(\.tomorrowRuns) private var tomorrowRuns
    @Environment(\.scheduleProtocolRun) private var scheduleProtocolRun
    @AppStorage("completedStepIDs") private var completedStepIDsData = ""
    @State private var activeTimers: [ActiveLabTimer] = []
    @State private var selectedDataCardRun: LabRun?
    @State private var focusedRun: LabRun?
    @State private var selectedMode: TodayMode = .records
    @State private var calendarScale = 0.72
    @State private var selectedRecordDayID = "today"
    @State private var scheduleRequest: ScheduleRequest?

    private var completedStepIDs: Set<String> {
        get { Set(completedStepIDsData.split(separator: ",").map(String.init)) }
        nonmutating set { completedStepIDsData = newValue.sorted().joined(separator: ",") }
    }

    private var todayRuns: [LabRun] {
        importedRuns + SampleData.runs
    }

    private var timerPointCount: Int {
        todayRuns.flatMap(\.steps).filter { $0.durationMinutes != nil }.count
    }

    private var carryOverCount: Int {
        todayRuns.flatMap(\.steps).filter(\.isCarryOver).count
    }

    private var historyDays: [ExperimentDay] {
        [
            ExperimentDay(
                id: "tomorrow",
                dateLabel: "明天",
                weekday: "Sat",
                summary: tomorrowRuns.isEmpty ? "暂无计划，从 Protocol 导入后会出现在这里" : "\(tomorrowRuns.count) 个明日实验计划",
                runs: tomorrowRuns
            ),
            ExperimentDay(
                id: "today",
                dateLabel: "今天",
                weekday: "Fri",
                summary: "\(todayRuns.count) 个实验 · \(completedCount(in: todayRuns))/\(todayRuns.flatMap(\.steps).count) 步完成",
                runs: todayRuns
            ),
            ExperimentDay(
                id: "yesterday",
                dateLabel: "昨天",
                weekday: "Thu",
                summary: "细胞换液、双酶切验证、WB 一抗孵育",
                runs: [
                    SampleData.runs[0],
                    SampleData.runs[1],
                    SampleData.runs[2]
                ]
            ),
            ExperimentDay(
                id: "week",
                dateLabel: "周三",
                weekday: "Wed",
                summary: "铺板、质粒转化、SDS-PAGE 胶制备",
                runs: [
                    SampleData.runs[0],
                    SampleData.runs[1]
                ]
            )
        ]
    }

    private var selectedRecordDay: ExperimentDay {
        historyDays.first { $0.id == selectedRecordDayID } ?? historyDays.first { $0.id == "today" } ?? historyDays[0]
    }

    var body: some View {
        ZStack {
            Color.labBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("今日视图", selection: $selectedMode) {
                        ForEach(TodayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch selectedMode {
                    case .records:
                        ExperimentCalendarView(
                            days: historyDays,
                            selectedDayID: $selectedRecordDayID,
                            scale: $calendarScale
                        )
                        ExperimentDayDetailView(
                            day: selectedRecordDay,
                            completedStepIDs: completedStepIDs,
                            emptyTitle: selectedRecordDay.id == "tomorrow" ? "明天还没有计划" : "这一天还没有实验记录",
                            emptySubtitle: selectedRecordDay.id == "tomorrow" ? "在 Protocol 中编辑模板后导入明天。" : "完成实验后会在这里沉淀成记录。"
                        )
                    case .today:
                        TimelineScheduleStrip(
                            title: "今天的空白时间",
                            slots: ["08:30", "11:00", "15:00", "18:30"],
                            action: { timeLabel in
                                scheduleRequest = ScheduleRequest(targetDay: .today, timeLabel: timeLabel)
                            }
                        )

                        if !activeTimers.isEmpty {
                            TimerDock(activeTimers: activeTimers, stopTimer: stopTimer)
                        }

                        ForEach(todayRuns) { run in
                            RunCard(
                                run: run,
                                completedStepIDs: completedStepIDs,
                                activeTimer: activeTimers.first { $0.runID == run.id },
                                toggleStep: { stepID in
                                    var next = completedStepIDs
                                    if next.contains(stepID) {
                                        next.remove(stepID)
                                    } else {
                                        next.insert(stepID)
                                    }
                                    completedStepIDs = next
                                },
                                startTimer: { startTimer(for: run) },
                                showDataCard: { selectedDataCardRun = run },
                                openBenchMode: { focusedRun = run },
                                removeRun: run.id.hasPrefix("import-") ? { removeImportedRun(run.id) } : nil
                            )
                        }
                    case .tomorrow:
                        TomorrowPlanView(
                            runs: tomorrowRuns,
                            completedStepIDs: completedStepIDs,
                            removeRun: { runID in
                                removeImportedRun(runID)
                            },
                            showDataCard: { selectedDataCardRun = $0 },
                            addAtTime: { timeLabel in
                                scheduleRequest = ScheduleRequest(targetDay: .tomorrow, timeLabel: timeLabel)
                            }
                        )
                    }
                }
                .padding(18)
            }
            .sheet(item: $selectedDataCardRun) { run in
                DataCardPreview(run: run, completedStepIDs: completedStepIDs)
            }
            .sheet(item: $scheduleRequest) { request in
                ProtocolScheduleSheet(
                    request: request,
                    schedule: { labProtocol, targetVolume, targetDay, timeLabel in
                        scheduleProtocolRun(labProtocol, targetVolume, targetDay, timeLabel)
                    }
                )
            }
            .sheet(item: $focusedRun) { run in
                BenchModeView(
                    run: run,
                    completedStepIDs: completedStepIDs,
                    activeTimer: activeTimers.first { $0.runID == run.id },
                    toggleStep: { stepID in
                        var next = completedStepIDs
                        if next.contains(stepID) {
                            next.remove(stepID)
                        } else {
                            next.insert(stepID)
                        }
                        completedStepIDs = next
                    },
                    completeRun: {
                        markRunComplete(run)
                        selectedDataCardRun = run
                    },
                    startTimer: { startTimer(for: run) }
                )
            }
            .onAppear(perform: loadTimers)
            .onChange(of: activeTimers) {
                saveTimers(activeTimers)
            }
        }
    }

    private func startTimer(for run: LabRun) {
        guard let step = run.steps.first(where: { step in
            step.durationMinutes != nil && !completedStepIDs.contains(step.id)
        }) ?? run.steps.first(where: { $0.durationMinutes != nil }),
              let durationMinutes = step.durationMinutes else {
            return
        }

        let now = Date()
        let timer = ActiveLabTimer(
            id: "\(run.id)-\(step.id)",
            runID: run.id,
            runTitle: run.title,
            stepTitle: step.title,
            startedAt: now,
            endsAt: now.addingTimeInterval(TimeInterval(durationMinutes * 60))
        )

        activeTimers.removeAll { $0.id == timer.id || $0.runID == run.id }
        activeTimers.append(timer)
        activeTimers.sort { $0.endsAt < $1.endsAt }
    }

    private func stopTimer(_ timer: ActiveLabTimer) {
        activeTimers.removeAll { $0.id == timer.id }
    }

    private func markRunComplete(_ run: LabRun) {
        var next = completedStepIDs
        run.steps.forEach { next.insert($0.id) }
        completedStepIDs = next
        activeTimers.removeAll { $0.runID == run.id }
        focusedRun = nil
    }

    private func loadTimers() {
        guard let data = UserDefaults.standard.data(forKey: "activeLabTimers"),
              let timers = try? JSONDecoder().decode([ActiveLabTimer].self, from: data) else {
            return
        }
        activeTimers = timers.sorted { $0.endsAt < $1.endsAt }
    }

    private func saveTimers(_ timers: [ActiveLabTimer]) {
        guard let data = try? JSONEncoder().encode(timers) else {
            return
        }
        UserDefaults.standard.set(data, forKey: "activeLabTimers")
    }

    private func completedCount(in runs: [LabRun]) -> Int {
        runs.flatMap(\.steps).filter { completedStepIDs.contains($0.id) }.count
    }
}

private struct ScheduleRequest: Identifiable {
    let id = UUID()
    let targetDay: PlanTargetDay
    let timeLabel: String
}

private enum TodayMode: String, CaseIterable, Identifiable {
    case records
    case today
    case tomorrow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .records:
            return "实验记录"
        case .today:
            return "今天"
        case .tomorrow:
            return "明天"
        }
    }
}

private struct ExperimentDay: Identifiable {
    let id: String
    let dateLabel: String
    let weekday: String
    let summary: String
    let runs: [LabRun]
}

private struct ExperimentCalendarView: View {
    let days: [ExperimentDay]
    @Binding var selectedDayID: String
    @Binding var scale: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("实验记录")
                        .font(.title2.bold())
                    Text("按天回看实验，也可以放大缩小查看密度")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(scale > 0.9 ? "大" : scale < 0.62 ? "小" : "中")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.teal.opacity(0.12), in: Capsule())
                    .foregroundStyle(.teal)
            }

            HStack(spacing: 10) {
                Image(systemName: "minus.magnifyingglass")
                    .foregroundStyle(.secondary)
                Slider(value: $scale, in: 0.48...1.08)
                Image(systemName: "plus.magnifyingglass")
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(days) { day in
                        CalendarDayCell(
                            day: day,
                            isSelected: selectedDayID == day.id,
                            scale: scale
                        ) {
                            selectedDayID = day.id
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct CalendarDayCell: View {
    let day: ExperimentDay
    let isSelected: Bool
    let scale: Double
    let select: () -> Void

    private var width: Double {
        76 + scale * 46
    }

    private var height: Double {
        102 + scale * 58
    }

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 8) {
                Text(day.weekday)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(day.dateLabel)
                    .font(.headline.bold())
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: max(3, 7 * scale)) {
                    ForEach(0..<max(day.runs.count, 1), id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(day.runs.isEmpty ? Color.secondary.opacity(0.18) : color(for: index).opacity(isSelected ? 0.92 : 0.58))
                            .frame(width: max(22, width - 30), height: max(5, 7 * scale))
                    }
                }

                Text(day.runs.isEmpty ? "空" : "\(day.runs.count) 项")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(isSelected ? .white : .secondary)
            }
            .padding(12)
            .frame(width: width, height: height, alignment: .leading)
            .background(isSelected ? Color.teal : Color.labInset, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func color(for index: Int) -> Color {
        switch index % 3 {
        case 0:
            return .teal
        case 1:
            return .blue
        default:
            return .orange
        }
    }
}

private struct ExperimentDayDetailView: View {
    let day: ExperimentDay
    let completedStepIDs: Set<String>
    let emptyTitle: String
    let emptySubtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(day.dateLabel)
                        .font(.title3.bold())
                    Text(day.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(day.weekday)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if day.runs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.teal)
                    Text(emptyTitle)
                        .font(.headline)
                    Text(emptySubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                                Text(run.title)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(run.area.rawValue) · \(completedSteps(for: run))/\(run.steps.count) 步")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
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

    private func completedSteps(for run: LabRun) -> Int {
        run.steps.filter { completedStepIDs.contains($0.id) }.count
    }
}

private struct HeaderPanel: View {
    let runCount: Int
    let timerPointCount: Int
    let carryOverCount: Int
    let activeTimers: [ActiveLabTimer]

    private var urgentTimerLabel: String {
        guard let timer = activeTimers.sorted(by: { $0.endsAt < $1.endsAt }).first else {
            return "无"
        }
        return timer.isFinished ? "已到点" : formatDuration(timer.remainingSeconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今天")
                        .font(.title.bold())
                    Text("\(runCount) 个实验 · \(timerPointCount) 个计时点 · \(carryOverCount) 个顺延占位")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("本地模式")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.teal.opacity(0.14), in: Capsule())
                    .foregroundStyle(.teal)
            }

            HStack(spacing: 10) {
                MetricPill(value: urgentTimerLabel, label: "最近倒计时")
                MetricPill(value: "50 ml", label: "培养基用量")
                MetricPill(value: "低库存", label: "FBS 预警")
            }
        }
        .padding(18)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct TimerDock: View {
    let activeTimers: [ActiveLabTimer]
    let stopTimer: (ActiveLabTimer) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("运行中的计时器")
                .font(.headline)

            ForEach(activeTimers.sorted(by: { $0.endsAt < $1.endsAt })) { timer in
                TimelineView(.periodic(from: Date(), by: 1)) { _ in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(timer.stepTitle)
                                .font(.subheadline.weight(.semibold))
                            Text(timer.runTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(timer.isFinished ? "完成" : formatDuration(timer.remainingSeconds))
                            .font(.title3.monospacedDigit().weight(.bold))
                            .foregroundStyle(timer.isFinished ? .orange : .teal)
                            .contentTransition(.numericText())

                        Button {
                            stopTimer(timer)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("结束计时器")
                    }
                    .padding(12)
                    .background(timer.isFinished ? Color.orange.opacity(0.12) : Color.labInset, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MetricPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct RunCard: View {
    let run: LabRun
    let completedStepIDs: Set<String>
    let activeTimer: ActiveLabTimer?
    let toggleStep: (String) -> Void
    let startTimer: () -> Void
    let showDataCard: () -> Void
    let openBenchMode: () -> Void
    let removeRun: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(run.timeLabel)
                        .font(.title2.monospacedDigit().bold())
                    Text(run.status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(run.status == "顺延占位" ? .orange : .teal)
                }
                .frame(width: 76, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text(run.title)
                        .font(.headline)
                    Text("\(run.area.rawValue) · \(run.protocolName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(run.scaledVolumeLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            VStack(spacing: 10) {
                ForEach(run.steps) { step in
                    StepRow(
                        step: step,
                        isDone: completedStepIDs.contains(step.id),
                        toggle: { toggleStep(step.id) }
                    )
                }
            }

            HStack(spacing: 10) {
                Button(action: openBenchMode) {
                    Label("实验台", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(action: startTimer) {
                    Label(activeTimer == nil ? "启动计时" : "重新计时", systemImage: activeTimer == nil ? "play.fill" : "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if let activeTimer {
                    TimelineView(.periodic(from: Date(), by: 1)) { _ in
                        Text(activeTimer.isFinished ? "到点" : formatDuration(activeTimer.remainingSeconds))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(activeTimer.isFinished ? .orange : .teal)
                            .frame(width: 82, height: 44)
                            .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                Button(action: showDataCard) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 46, height: 28)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityLabel("生成结果卡片")

                if let removeRun {
                    Button(action: removeRun) {
                        Image(systemName: "trash")
                            .frame(width: 46, height: 28)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .foregroundStyle(.red)
                    .accessibilityLabel("移除导入实验")
                }
            }
        }
        .padding(16)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct TimelineScheduleStrip: View {
    let title: String
    let slots: [String]
    let action: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(slots, id: \.self) { slot in
                        Button {
                            action(slot)
                        } label: {
                            VStack(spacing: 6) {
                                Text(slot)
                                    .font(.headline.monospacedDigit())
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                            }
                            .frame(width: 88, height: 72)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ProtocolScheduleSheet: View {
    let request: ScheduleRequest
    let schedule: (LabProtocol, Double, PlanTargetDay, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var targetVolume = 50.0
    @State private var selectedProtocolID = SampleData.protocols.first?.id ?? ""

    private var selectedProtocol: LabProtocol {
        SampleData.protocols.first { $0.id == selectedProtocolID } ?? SampleData.protocols[0]
    }

    private var destinationTitle: String {
        request.targetDay == .today ? "今天 \(request.timeLabel)" : "明天 \(request.timeLabel)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("空白时间") {
                    Label(destinationTitle, systemImage: "calendar.badge.plus")
                        .font(.headline)
                }

                Section("选择 Protocol") {
                    Picker("Protocol", selection: $selectedProtocolID) {
                        ForEach(SampleData.protocols) { labProtocol in
                            Text(labProtocol.name).tag(labProtocol.id)
                        }
                    }
                    HStack {
                        Text("目标体积")
                        Spacer()
                        Text("\(Int(targetVolume)) \(selectedProtocol.volumeUnit)")
                            .font(.headline.monospacedDigit())
                    }
                    Slider(value: $targetVolume, in: 10...200, step: 10)
                }

                Section("排期预览") {
                    MetadataRow(label: "实验类型", value: selectedProtocol.area.rawValue)
                    MetadataRow(label: "预计时长", value: selectedProtocol.expectedDuration)
                    MetadataRow(label: "变量检查", value: protocolConsistencyIssues(selectedProtocol).isEmpty ? "一致" : "需复核")
                    ForEach(selectedProtocol.steps.prefix(3)) { step in
                        Label(step.title, systemImage: step.durationMinutes == nil ? "circle" : "timer")
                    }
                }

                Section {
                    Button {
                        schedule(selectedProtocol, targetVolume, request.targetDay, request.timeLabel)
                        dismiss()
                    } label: {
                        Label("加入时间流", systemImage: "calendar.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("添加实验")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct TomorrowPlanView: View {
    let runs: [LabRun]
    let completedStepIDs: Set<String>
    let removeRun: (String) -> Void
    let showDataCard: (LabRun) -> Void
    let addAtTime: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TimelineScheduleStrip(
                title: "明天的空白时间",
                slots: ["09:00", "10:30", "14:00", "16:30", "20:00"],
                action: addAtTime
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("明天计划")
                            .font(.title2.bold())
                        Text(runs.isEmpty ? "从 Protocol 导入明天要做的实验" : "\(runs.count) 个实验已安排")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "calendar.badge.clock")
                        .font(.title2)
                        .foregroundStyle(.teal)
                }
            }
            .padding(16)
            .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

            if runs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "list.clipboard")
                        .font(.title2)
                        .foregroundStyle(.teal)
                    Text("还没有明日实验")
                        .font(.headline)
                    Text("去 Protocol 里选择模板，修改参数后导入，计划会自动出现在这里。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(runs) { run in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            Text(run.timeLabel)
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.teal)
                                .frame(width: 58, alignment: .leading)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(run.title)
                                    .font(.headline)
                                Text("\(run.area.rawValue) · \(run.protocolName)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(run.scaledVolumeLabel)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }

                        ForEach(run.steps.prefix(3)) { step in
                            TomorrowStepPreview(step: step)
                        }

                        HStack(spacing: 10) {
                            Button {
                                showDataCard(run)
                            } label: {
                                Label("预览卡片", systemImage: "rectangle.on.rectangle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)

                            Button(role: .destructive) {
                                removeRun(run.id)
                            } label: {
                                Image(systemName: "trash")
                                    .frame(width: 44, height: 28)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .accessibilityLabel("移除明天计划")
                        }
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private struct TomorrowStepPreview: View {
    let step: LabStep

    private var iconName: String {
        step.durationMinutes == nil ? "circle" : "timer"
    }

    private var iconColor: Color {
        step.durationMinutes == nil ? .secondary : .blue
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
            Text(step.title)
                .font(.caption.weight(.semibold))
            Spacer()
            if let duration = step.durationMinutes {
                Text("\(duration)m")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct BenchModeView: View {
    let run: LabRun
    let completedStepIDs: Set<String>
    let activeTimer: ActiveLabTimer?
    let toggleStep: (String) -> Void
    let completeRun: () -> Void
    let startTimer: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var doneCount: Int {
        run.steps.filter { completedStepIDs.contains($0.id) }.count
    }

    private var currentStep: LabStep? {
        run.steps.first { !completedStepIDs.contains($0.id) } ?? run.steps.last
    }

    private var completionText: String {
        return "\(doneCount)/\(run.steps.count)"
    }

    private var isRunComplete: Bool {
        doneCount == run.steps.count
    }

    var body: some View {
        ZStack {
            Color.labBackground.ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(run.timeLabel)
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(run.title)
                            .font(.largeTitle.bold())
                            .lineLimit(2)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 34))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("退出实验台模式")
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("当前步骤")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(completionText)
                            .font(.headline.monospacedDigit())
                    }

                    if let currentStep {
                        Text(currentStep.title)
                            .font(.system(size: 34, weight: .bold))
                            .minimumScaleFactor(0.75)
                        Text(currentStep.detail)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let duration = currentStep.durationMinutes {
                            Label("\(duration) min", systemImage: "timer")
                                .font(.title3.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Color.blue.opacity(0.12), in: Capsule())
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                if let activeTimer {
                    BenchTimerPanel(timer: activeTimer)
                } else {
                    Button(action: startTimer) {
                        Label("为当前实验启动计时", systemImage: "play.fill")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 62)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                VStack(spacing: 10) {
                    ForEach(run.steps) { step in
                        BenchStepRow(
                            step: step,
                            isDone: completedStepIDs.contains(step.id),
                            toggle: { toggleStep(step.id) }
                        )
                    }
                }

                Button(action: completeRun) {
                    Label(isRunComplete ? "生成结果卡片" : "完成本实验并生成卡片", systemImage: isRunComplete ? "rectangle.on.rectangle.angled" : "checkmark.seal.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 58)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }
}

private struct BenchTimerPanel: View {
    let timer: ActiveLabTimer

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { _ in
            VStack(spacing: 8) {
                Text(timer.stepTitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(timer.isFinished ? "完成" : formatDuration(timer.remainingSeconds))
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                    .foregroundStyle(timer.isFinished ? .orange : .teal)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(timer.isFinished ? Color.orange.opacity(0.12) : Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct BenchStepRow: View {
    let step: LabStep
    let isDone: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 14) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 30))
                    .foregroundStyle(isDone ? .teal : .secondary)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(.headline)
                        .strikethrough(isDone)
                    Text(step.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(14)
            .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct StepRow: View {
    let step: LabStep
    let isDone: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isDone ? .teal : .secondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(isDone ? "标记未完成" : "标记完成")

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(isDone)
                Text(step.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let duration = step.durationMinutes {
                Label("\(duration)m", systemImage: "timer")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.12), in: Capsule())
                    .foregroundStyle(.blue)
            }
        }
        .padding(10)
        .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ProtocolsView: View {
    @State private var targetVolume = 50.0
    @State private var editableProtocols = SampleData.protocols
    @State private var selectedProtocol: LabProtocol?
    @State private var extractionSource: ProtocolSourceType?
    @State private var sharedProtocolName: String?

    var body: some View {
        ZStack {
            Color.labBackground.ignoresSafeArea()

            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("目标体积")
                            Spacer()
                            Text("\(Int(targetVolume)) ml")
                                .font(.headline.monospacedDigit())
                        }
                        Slider(value: $targetVolume, in: 20...200, step: 10)
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Button {
                                selectedProtocol = emptyProtocol()
                            } label: {
                                Label("新建", systemImage: "plus.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)

                            Menu {
                                ForEach(ProtocolSourceType.allCases) { sourceType in
                                    Button(sourceType.rawValue) {
                                        extractionSource = sourceType
                                    }
                                }
                            } label: {
                                Label("提取", systemImage: "doc.text.viewfinder")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                ForEach(editableProtocols) { labProtocol in
                    ProtocolCard(
                        labProtocol: labProtocol,
                        targetVolume: targetVolume,
                        editProtocol: {
                            selectedProtocol = labProtocol
                        },
                        shareProtocol: {
                            sharedProtocolName = labProtocol.name
                        }
                    )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
        }
        .sheet(item: $selectedProtocol) { labProtocol in
            ProtocolEditorView(
                labProtocol: labProtocol,
                targetVolume: targetVolume,
                saveProtocol: { updatedProtocol in
                    upsert(updatedProtocol)
                }
            )
        }
        .sheet(item: $extractionSource) { sourceType in
            ProtocolExtractionView(sourceType: sourceType) { extracted in
                upsert(extracted)
                selectedProtocol = extracted
            }
        }
        .alert("Protocol 已准备分享", isPresented: Binding(
            get: { sharedProtocolName != nil },
            set: { if !$0 { sharedProtocolName = nil } }
        )) {
            Button("完成", role: .cancel) {
                sharedProtocolName = nil
            }
        } message: {
            Text(sharedProtocolName ?? "")
        }
    }

    private func upsert(_ labProtocol: LabProtocol) {
        if let index = editableProtocols.firstIndex(where: { $0.id == labProtocol.id }) {
            editableProtocols[index] = labProtocol
        } else {
            editableProtocols.insert(labProtocol, at: 0)
        }
    }

    private func emptyProtocol() -> LabProtocol {
        LabProtocol(
            id: "custom-\(Int(Date().timeIntervalSince1970))",
            name: "新 Protocol",
            area: .cell,
            baseVolume: targetVolume,
            volumeUnit: "ml",
            expectedDuration: "15 min",
            ingredients: [
                ProtocolIngredient(name: "成分 A", standardAmount: targetVolume, unit: "ml")
            ],
            steps: [
                LabStep(id: UUID().uuidString, title: "第一步", detail: "填写操作条件", durationMinutes: nil, isCarryOver: false)
            ],
            variables: [
                ProtocolVariable(symbol: "V_total", name: "总体积", value: targetVolume, unit: "ml", formula: "baseVolume")
            ],
            source: ProtocolSource(type: .sop, title: "手动创建", confidence: 1.0)
        )
    }
}

private struct ProtocolCard: View {
    let labProtocol: LabProtocol
    let targetVolume: Double
    let editProtocol: () -> Void
    let shareProtocol: () -> Void

    private var scaleFactor: Double {
        targetVolume / labProtocol.baseVolume
    }

    private var consistencyIssues: [String] {
        protocolConsistencyIssues(labProtocol)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(labProtocol.name)
                        .font(.headline)
                    Text("\(labProtocol.area.rawValue) · 基准 \(Int(labProtocol.baseVolume)) \(labProtocol.volumeUnit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("x\(scaleFactor, specifier: "%.2f")")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.teal.opacity(0.12), in: Capsule())
                        .foregroundStyle(.teal)
                    Label(consistencyIssues.isEmpty ? "一致" : "\(consistencyIssues.count) 项检查", systemImage: consistencyIssues.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(consistencyIssues.isEmpty ? .teal : .orange)
                }
            }

            if let source = labProtocol.source {
                Label("\(source.type.rawValue) · \(source.title)", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !labProtocol.variables.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(labProtocol.variables) { variable in
                            Text("\(variable.symbol)=\(formatDecimal(variable.value)) \(variable.unit)")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(Color.labInset, in: Capsule())
                        }
                    }
                }
            }

            ForEach(labProtocol.ingredients) { ingredient in
                HStack {
                    Text(ingredient.name)
                    Spacer()
                    Text(ingredient.scaled(by: scaleFactor))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }

            if !consistencyIssues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(consistencyIssues.prefix(2), id: \.self) { issue in
                        Label(issue, systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(10)
                .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 10) {
                Button(action: editProtocol) {
                    Label("编辑", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: shareProtocol) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 46, height: 28)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityLabel("分享 Protocol")
            }
        }
        .padding(16)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ProtocolEditorView: View {
    @State private var draft: LabProtocol
    let targetVolume: Double
    let saveProtocol: (LabProtocol) -> Void
    @Environment(\.dismiss) private var dismiss

    init(
        labProtocol: LabProtocol,
        targetVolume: Double,
        saveProtocol: @escaping (LabProtocol) -> Void
    ) {
        _draft = State(initialValue: labProtocol)
        self.targetVolume = targetVolume
        self.saveProtocol = saveProtocol
    }

    private var scaleFactor: Double {
        guard draft.baseVolume > 0 else {
            return 1
        }
        return targetVolume / draft.baseVolume
    }

    private var consistencyIssues: [String] {
        protocolConsistencyIssues(draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基础信息") {
                    TextField("Protocol 名称", text: $draft.name)
                    Picker("实验类型", selection: $draft.area) {
                        ForEach(WorkflowArea.allCases) { area in
                            Text(area.rawValue).tag(area)
                        }
                    }
                    HStack {
                        Text("基准体积")
                        Spacer()
                        TextField("0", value: $draft.baseVolume, format: .number)
                            .multilineTextAlignment(TextAlignment.trailing)
                            .frame(width: 90)
                        TextField("单位", text: $draft.volumeUnit)
                            .multilineTextAlignment(TextAlignment.trailing)
                            .frame(width: 54)
                    }
                    TextField("预计时长", text: $draft.expectedDuration)
                }

                Section("来源与一致性") {
                    if let source = draft.source {
                        HStack {
                            Label(source.type.rawValue, systemImage: "doc.text.viewfinder")
                            Spacer()
                            Text("\(Int(source.confidence * 100))%")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Text(source.title)
                            .font(.subheadline)
                    } else {
                        Text("无来源信息")
                            .foregroundStyle(.secondary)
                    }

                    if consistencyIssues.isEmpty {
                        Label("变量、成分和步骤参数一致", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.teal)
                    } else {
                        ForEach(consistencyIssues, id: \.self) { issue in
                            Label(issue, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section("公式变量") {
                    ForEach($draft.variables) { $variable in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                TextField("符号", text: $variable.symbol)
                                    .frame(width: 88)
                                TextField("名称", text: $variable.name)
                            }
                            HStack {
                                TextField("数值", value: $variable.value, format: .number)
                                TextField("单位", text: $variable.unit)
                                    .frame(width: 70)
                            }
                            TextField("公式定义", text: $variable.formula)
                                .font(.body.monospaced())
                        }
                    }
                    .onDelete { offsets in
                        draft.variables.remove(atOffsets: offsets)
                    }

                    Button {
                        draft.variables.append(ProtocolVariable(symbol: "x", name: "新变量", value: 1, unit: draft.volumeUnit, formula: ""))
                    } label: {
                        Label("增加变量", systemImage: "plus.circle")
                    }
                }

                Section("成分参数") {
                    ForEach($draft.ingredients) { $ingredient in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("成分名称", text: $ingredient.name)
                            HStack {
                                TextField("基准用量", value: $ingredient.standardAmount, format: .number)
                                TextField("单位", text: $ingredient.unit)
                                    .frame(width: 70)
                                Spacer()
                                Text(ingredient.scaled(by: scaleFactor))
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(.teal)
                            }
                        }
                    }
                    .onDelete { offsets in
                        draft.ingredients.remove(atOffsets: offsets)
                    }

                    Button {
                        draft.ingredients.append(ProtocolIngredient(name: "新成分", standardAmount: 1, unit: draft.volumeUnit))
                    } label: {
                        Label("增加成分", systemImage: "plus.circle")
                    }
                }

                Section("实验步骤") {
                    ForEach($draft.steps) { $step in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("步骤名称", text: $step.title)
                            TextField("操作条件", text: $step.detail)
                            HStack {
                                Text("计时")
                                Spacer()
                                Stepper(
                                    step.durationMinutes == nil ? "无" : "\(step.durationMinutes ?? 0) min",
                                    value: Binding(
                                        get: { step.durationMinutes ?? 0 },
                                        set: { step.durationMinutes = $0 == 0 ? nil : $0 }
                                    ),
                                    in: 0...240,
                                    step: 5
                                )
                            }
                            VariableRefPicker(step: $step, variables: draft.variables)
                            Toggle("顺延占位", isOn: $step.isCarryOver)
                        }
                    }
                    .onDelete { offsets in
                        draft.steps.remove(atOffsets: offsets)
                    }

                    Button {
                        draft.steps.append(LabStep(id: UUID().uuidString, title: "新步骤", detail: "填写操作条件", durationMinutes: nil, isCarryOver: false))
                    } label: {
                        Label("增加步骤", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("编辑 Protocol")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveProtocol(draft)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct VariableRefPicker: View {
    @Binding var step: LabStep
    let variables: [ProtocolVariable]

    var body: some View {
        if !variables.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("关联变量")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                FlowVariableChips(variables: variables, selectedSymbols: $step.variableRefs)
            }
        }
    }
}

private struct FlowVariableChips: View {
    let variables: [ProtocolVariable]
    @Binding var selectedSymbols: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 8)], spacing: 8) {
            ForEach(variables) { variable in
                Button {
                    toggle(variable.symbol)
                } label: {
                    Text(variable.symbol)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.bordered)
                .tint(selectedSymbols.contains(variable.symbol) ? .teal : .secondary)
            }
        }
    }

    private func toggle(_ symbol: String) {
        if selectedSymbols.contains(symbol) {
            selectedSymbols.removeAll { $0 == symbol }
        } else {
            selectedSymbols.append(symbol)
        }
    }
}

private struct ProtocolExtractionView: View {
    let sourceType: ProtocolSourceType
    let accept: (LabProtocol) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var sourceTitle = ""
    @State private var extractedName = ""
    @State private var extractedVolume = 50.0
    @State private var confidence = 0.86

    private var previewProtocol: LabProtocol {
        LabProtocol(
            id: "extracted-\(sourceType.rawValue)-\(Int(Date().timeIntervalSince1970))",
            name: extractedName.isEmpty ? "\(sourceType.rawValue) 提取 Protocol" : extractedName,
            area: sourceType == .kitManual ? .cloning : .cell,
            baseVolume: extractedVolume,
            volumeUnit: sourceType == .kitManual ? "ul" : "ml",
            expectedDuration: sourceType == .literature ? "45 min" : "20 min",
            ingredients: [
                ProtocolIngredient(name: "提取成分 A", standardAmount: extractedVolume * 0.8, unit: sourceType == .kitManual ? "ul" : "ml"),
                ProtocolIngredient(name: "提取成分 B", standardAmount: extractedVolume * 0.2, unit: sourceType == .kitManual ? "ul" : "ml")
            ],
            steps: [
                LabStep(id: UUID().uuidString, title: "核对来源参数", detail: "检查温度、时间、转速和体积", durationMinutes: nil, isCarryOver: false, variableRefs: ["V_total"]),
                LabStep(id: UUID().uuidString, title: "执行提取方法", detail: "按来源方法完成关键步骤", durationMinutes: 20, isCarryOver: false, variableRefs: ["t_core"])
            ],
            variables: [
                ProtocolVariable(symbol: "V_total", name: "总体积", value: extractedVolume, unit: sourceType == .kitManual ? "ul" : "ml", formula: "source.totalVolume"),
                ProtocolVariable(symbol: "t_core", name: "核心反应时间", value: 20, unit: "min", formula: "source.incubationTime")
            ],
            source: ProtocolSource(type: sourceType, title: sourceTitle.isEmpty ? "待补充来源标题" : sourceTitle, confidence: confidence)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("来源") {
                    Text(sourceType.rawValue)
                        .font(.headline)
                    TextField("文献题名 / 手册名称 / SOP 编号", text: $sourceTitle)
                    TextField("提取后的 Protocol 名称", text: $extractedName)
                }

                Section("提取结果预览") {
                    HStack {
                        Text("基准体积")
                        Spacer()
                        TextField("0", value: $extractedVolume, format: .number)
                            .multilineTextAlignment(TextAlignment.trailing)
                            .frame(width: 92)
                    }
                    HStack {
                        Text("置信度")
                        Spacer()
                        Text("\(Int(confidence * 100))%")
                            .font(.headline.monospacedDigit())
                    }
                    Slider(value: $confidence, in: 0.55...0.98)

                    ForEach(previewProtocol.variables) { variable in
                        MetadataRow(label: variable.symbol, value: "\(formatDecimal(variable.value)) \(variable.unit) · \(variable.formula)")
                    }
                }

                Section {
                    Button {
                        accept(previewProtocol)
                        dismiss()
                    } label: {
                        Label("接受并继续编辑", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("提取 Protocol")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ToolsView: View {
    @State private var selectedCalculator: CalculatorMode = .mass
    @State private var molecularWeight = 121.14
    @State private var targetMolarity = 0.5
    @State private var massVolumeML = 100.0
    @State private var stockConcentration = 1.0
    @State private var finalConcentration = 0.05
    @State private var dilutionVolumeML = 100.0
    @State private var percentValue = 5.0
    @State private var percentVolumeML = 20.0
    @State private var copiedResult: String?

    private var massResult: Double {
        molecularWeight * targetMolarity * (massVolumeML / 1000.0)
    }

    private var stockVolumeML: Double {
        guard stockConcentration > 0 else {
            return 0
        }
        return finalConcentration * dilutionVolumeML / stockConcentration
    }

    private var solventVolumeML: Double {
        max(0, dilutionVolumeML - stockVolumeML)
    }

    private var percentMassG: Double {
        percentValue / 100.0 * percentVolumeML
    }

    private var resultText: String {
        switch selectedCalculator {
        case .mass:
            return "称量 \(formatDecimal(massResult)) g"
        case .dilution:
            return "取母液 \(formatDecimal(stockVolumeML)) ml + 溶剂 \(formatDecimal(solventVolumeML)) ml"
        case .percent:
            return "称量/量取 \(formatDecimal(percentMassG)) g 或 ml，定容至 \(formatDecimal(percentVolumeML)) ml"
        }
    }

    var body: some View {
        ZStack {
            Color.labBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("计算模式", selection: $selectedCalculator) {
                        ForEach(CalculatorMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(selectedCalculator.title)
                                    .font(.headline)
                                Text(selectedCalculator.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: selectedCalculator.icon)
                                .font(.title2)
                                .foregroundStyle(.teal)
                        }

                        switch selectedCalculator {
                        case .mass:
                            CalculatorNumberField(title: "分子量", value: $molecularWeight, unit: "g/mol")
                            CalculatorNumberField(title: "目标浓度", value: $targetMolarity, unit: "M")
                            CalculatorNumberField(title: "总体积", value: $massVolumeML, unit: "ml")
                        case .dilution:
                            CalculatorNumberField(title: "母液浓度 C1", value: $stockConcentration, unit: "M")
                            CalculatorNumberField(title: "目标浓度 C2", value: $finalConcentration, unit: "M")
                            CalculatorNumberField(title: "总体积 V2", value: $dilutionVolumeML, unit: "ml")
                        case .percent:
                            CalculatorNumberField(title: "百分比浓度", value: $percentValue, unit: "%")
                            CalculatorNumberField(title: "总体积", value: $percentVolumeML, unit: "ml")
                        }

                        Text(resultText)
                            .font(.title3.monospacedDigit().weight(.bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))

                        Button {
                            Clipboard.copy(resultText)
                            copiedResult = resultText
                        } label: {
                            Label(copiedResult == resultText ? "已复制结果" : "复制计算结果", systemImage: copiedResult == resultText ? "checkmark.circle.fill" : "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    ForEach(SampleData.calculatorExamples) { example in
                        CalculatorExampleCard(example: example)
                    }
                }
                .padding(18)
            }
        }
    }
}

private struct InventoryView: View {
    @Binding var items: [InventoryItem]
    let resetDemoData: () -> Void

    private var lowStockCount: Int {
        items.filter(\.isLowStock).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("个人库存")
                            .font(.title2.bold())
                        Text("\(items.count) 项 · \(lowStockCount) 项低库存")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: lowStockCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(lowStockCount > 0 ? .orange : .teal)
                }
            }
            .padding(16)
            .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

            ForEach($items) { $item in
                InventoryItemCard(item: $item)
            }

            Button(role: .destructive, action: resetDemoData) {
                Label("重置本地体验数据", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}

private struct InventoryItemCard: View {
    @Binding var item: InventoryItem

    private var progress: Double {
        guard item.threshold > 0 else {
            return 1
        }
        return min(1, item.quantity / (item.threshold * 3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.name)
                        .font(.headline)
                    Text("\(item.category) · \(item.storage)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(item.isLowStock ? "低库存" : "充足")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background((item.isLowStock ? Color.orange : Color.teal).opacity(0.14), in: Capsule())
                    .foregroundStyle(item.isLowStock ? .orange : .teal)
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(formatDecimal(item.quantity))
                    .font(.title2.monospacedDigit().bold())
                Text(item.unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("阈值 \(formatDecimal(item.threshold)) \(item.unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .tint(item.isLowStock ? .orange : .teal)

            HStack(spacing: 10) {
                Button {
                    item.quantity = max(0, item.quantity - defaultDeduction(for: item.unit))
                } label: {
                    Label("扣减", systemImage: "minus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    item.quantity += defaultRestock(for: item.unit)
                } label: {
                    Label("补货", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(16)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ProfileView: View {
    @Binding var items: [InventoryItem]
    let resetDemoData: () -> Void
    @AppStorage("profileDisplayName") private var displayName = "未登录用户"
    @AppStorage("profileLabName") private var labName = "个人本地工作区"
    @AppStorage("profileLargeBenchMode") private var largeBenchMode = true
    @AppStorage("profileLocalOnly") private var localOnly = true
    @AppStorage("profileDataCardWatermark") private var dataCardWatermark = true

    var body: some View {
        ZStack {
            Color.labBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.teal.opacity(0.18))
                                Image(systemName: "person.fill")
                                    .font(.title)
                                    .foregroundStyle(.teal)
                            }
                            .frame(width: 62, height: 62)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayName)
                                    .font(.title3.bold())
                                Text(labName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(localOnly ? "本地个人工具" : "账号能力预留")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(Color.teal.opacity(0.12), in: Capsule())
                                    .foregroundStyle(.teal)
                            }
                            Spacer()
                        }

                        TextField("显示名称", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                        TextField("实验室/项目空间", text: $labName)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("实验台偏好")
                            .font(.headline)
                        Toggle("大字号实验台模式", isOn: $largeBenchMode)
                        Toggle("数据只保存在本机", isOn: $localOnly)
                        Toggle("结果卡片显示 LabBuddy 水印", isOn: $dataCardWatermark)
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("未来账号能力")
                            .font(.headline)
                        ProfileActionRow(icon: "person.badge.key", title: "登录与身份", subtitle: "为之后的 Pro 和云备份预留")
                        ProfileActionRow(icon: "bell.badge", title: "通知设置", subtitle: "计时器、顺延实验和库存提醒")
                        ProfileActionRow(icon: "icloud", title: "实验资产同步", subtitle: "v1 保持关闭，本地优先")
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    InventoryView(
                        items: $items,
                        resetDemoData: resetDemoData
                    )
                }
                .padding(18)
            }
        }
    }
}

private struct ProfileActionRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.teal)
                .frame(width: 34, height: 34)
                .background(Color.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct RemoveImportedRunKey: EnvironmentKey {
    static let defaultValue: (String) -> Void = { _ in }
}

private struct TomorrowRunsKey: EnvironmentKey {
    static let defaultValue: [LabRun] = []
}

private struct ScheduleProtocolRunKey: EnvironmentKey {
    static let defaultValue: (LabProtocol, Double, PlanTargetDay, String) -> Void = { _, _, _, _ in }
}

private extension EnvironmentValues {
    var removeImportedRun: (String) -> Void {
        get { self[RemoveImportedRunKey.self] }
        set { self[RemoveImportedRunKey.self] = newValue }
    }

    var tomorrowRuns: [LabRun] {
        get { self[TomorrowRunsKey.self] }
        set { self[TomorrowRunsKey.self] = newValue }
    }

    var scheduleProtocolRun: (LabProtocol, Double, PlanTargetDay, String) -> Void {
        get { self[ScheduleProtocolRunKey.self] }
        set { self[ScheduleProtocolRunKey.self] = newValue }
    }
}

private enum CalculatorMode: String, CaseIterable, Identifiable {
    case mass = "质量"
    case dilution = "稀释"
    case percent = "%"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mass:
            return "质量浓度"
        case .dilution:
            return "液体稀释"
        case .percent:
            return "百分比浓度"
        }
    }

    var subtitle: String {
        switch self {
        case .mass:
            return "MW × M × L"
        case .dilution:
            return "C1V1 = C2V2"
        case .percent:
            return "w/v 或 v/v"
        }
    }

    var icon: String {
        switch self {
        case .mass:
            return "scalemass"
        case .dilution:
            return "drop.triangle"
        case .percent:
            return "percent"
        }
    }
}

private struct CalculatorNumberField: View {
    let title: String
    @Binding var value: Double
    let unit: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            TextField("0", value: $value, format: .number)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .frame(width: 92)
                .textFieldStyle(.roundedBorder)
            Text(unit)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
        }
    }
}

private struct DataCardPreview: View {
    let run: LabRun
    let completedStepIDs: Set<String>
    @Environment(\.dismiss) private var dismiss

    private var doneCount: Int {
        run.steps.filter { completedStepIDs.contains($0.id) }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(run.title)
                                .font(.title2.bold())
                            Text(run.area.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(run.timeLabel)
                            .font(.headline.monospacedDigit())
                    }

                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [.teal.opacity(0.26), .cyan.opacity(0.14), .indigo.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(height: 220)
                        .overlay {
                            VStack(spacing: 12) {
                                HStack(spacing: 10) {
                                    ForEach(0..<5) { index in
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(index == 2 ? Color.teal.opacity(0.72) : Color.primary.opacity(0.22))
                                            .frame(width: 18, height: CGFloat(46 + index * 17))
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 120)

                                Text("结果图 / 标注区")
                                    .font(.headline)
                                Text("拍照后可替换为跑胶、WB 或细胞图片")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.teal)
                        }

                    VStack(alignment: .leading, spacing: 10) {
                        MetadataRow(label: "Protocol", value: run.protocolName)
                        MetadataRow(label: "用量/规模", value: run.scaledVolumeLabel)
                        MetadataRow(label: "实验类型", value: run.area.rawValue)
                        MetadataRow(label: "步骤完成", value: "\(doneCount)/\(run.steps.count)")
                        MetadataRow(label: "生成时间", value: Date.now.formatted(date: .abbreviated, time: .shortened))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("关键实验条件")
                            .font(.headline)
                        ForEach(run.steps.prefix(4)) { step in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: step.durationMinutes == nil ? "checkmark.circle" : "timer")
                                    .foregroundStyle(step.durationMinutes == nil ? .teal : .blue)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(conditionText(for: step))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))

                    Text("Powered by LabBuddy")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(18)
                .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                Button {
                    Clipboard.copy("\(run.title) · \(run.protocolName) · \(run.scaledVolumeLabel)")
                } label: {
                    Label("复制实验条件", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                }
                .padding(18)
            }
            .background(Color.labBackground)
            .navigationTitle("结果卡片")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func conditionText(for step: LabStep) -> String {
        if let duration = step.durationMinutes {
            return "\(step.detail) · \(duration) min"
        }
        return step.detail
    }
}

private struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

private struct CalculatorExampleCard: View {
    let example: CalculatorExample

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(example.title)
                .font(.headline)
            Text(example.input)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(example.result)
                .font(.title3.monospacedDigit().weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
    }
}

private enum Clipboard {
    static func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

private func formatDuration(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let seconds = seconds % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

private func formatDecimal(_ value: Double) -> String {
    if value >= 100 {
        return String(format: "%.0f", value)
    }
    if value >= 10 {
        return String(format: "%.1f", value)
    }
    return String(format: "%.2f", value)
}

private func defaultDeduction(for unit: String) -> Double {
    switch unit {
    case "ul":
        return 1
    case "sheets":
        return 1
    default:
        return 10
    }
}

private func defaultRestock(for unit: String) -> Double {
    switch unit {
    case "ul":
        return 5
    case "sheets":
        return 1
    default:
        return 50
    }
}

private func protocolConsistencyIssues(_ labProtocol: LabProtocol) -> [String] {
    var issues: [String] = []
    let ingredientTotal = labProtocol.ingredients.reduce(0) { $0 + $1.standardAmount }
    if abs(ingredientTotal - labProtocol.baseVolume) > max(0.2, labProtocol.baseVolume * 0.08) {
        issues.append("成分总量与基准体积不一致")
    }

    let symbols = Set(labProtocol.variables.map(\.symbol))
    let missingRefs = labProtocol.steps
        .flatMap(\.variableRefs)
        .filter { !symbols.contains($0) }
    if let firstMissing = missingRefs.first {
        issues.append("步骤引用了未定义变量 \(firstMissing)")
    }

    for variable in labProtocol.variables where variable.formula.contains("step.duration") {
        let hasTimedStep = labProtocol.steps.contains { step in
            step.variableRefs.contains(variable.symbol) && step.durationMinutes != nil
        }
        if !hasTimedStep {
            issues.append("\(variable.symbol) 缺少计时步骤")
        }
    }

    let duplicateSymbols = Dictionary(grouping: labProtocol.variables.map(\.symbol), by: { $0 })
        .filter { $0.value.count > 1 }
        .map(\.key)
    if let duplicate = duplicateSymbols.first {
        issues.append("变量 \(duplicate) 重复定义")
    }

    return issues
}

private extension Color {
    static let labBackground = Color(red: 0.95, green: 0.97, blue: 0.97)
    static let labPanel = Color(red: 1.0, green: 1.0, blue: 0.99)
    static let labInset = Color(red: 0.90, green: 0.95, blue: 0.95)
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
