import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ContentView: View {
    @State private var importedRuns: [LabRun] = []
    @State private var tomorrowRuns: [LabRun] = []
    @State private var pastDays: [ExperimentDayRecord] = SampleData.pastDays
    @State private var inventoryItems: [InventoryItem] = SampleData.inventory
    @AppStorage("lastLabBuddyOpenDate") private var lastOpenDate = ""
    @State private var showNewDaySheet = false

    var body: some View {
        NavigationStack {
            TabView {
                TodayView(
                    importedRuns: $importedRuns,
                    tomorrowRuns: $tomorrowRuns,
                    pastDays: $pastDays,
                    onEndDay: endDay
                )
                .tabItem { Label("今日", systemImage: "calendar") }

                ProtocolLibraryView()
                    .tabItem { Label("Protocol", systemImage: "list.clipboard") }

                CalculatorToolkitView()
                    .tabItem { Label("工具", systemImage: "function") }

                NavigationStack {
                    MyWorkspaceView(items: $inventoryItems, resetDemoData: resetDemoData)
                        .navigationTitle("我的")
                }
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
            }
            .tint(.teal)
        }
        .onAppear {
            loadAll()
            checkNewDay()
        }
        .onChange(of: importedRuns) { saveImportedRuns(importedRuns) }
        .onChange(of: tomorrowRuns) { saveTomorrowRuns(tomorrowRuns) }
        .onChange(of: pastDays) { savePastDays(pastDays) }
        .onChange(of: inventoryItems) { saveInventoryItems(inventoryItems) }
        .sheet(isPresented: $showNewDaySheet) {
            NewDayConfirmSheet(
                confirmRollover: {
                    performRollover()
                    showNewDaySheet = false
                },
                dismiss: { showNewDaySheet = false }
            )
        }
    }

    // MARK: - Day rollover

    private func checkNewDay() {
        let todayKey = Self.dayKey(for: Date())
        guard !lastOpenDate.isEmpty, lastOpenDate != todayKey else {
            if lastOpenDate.isEmpty { lastOpenDate = todayKey }
            return
        }
        showNewDaySheet = true
    }

    private func endDay() {
        performRollover()
    }

    private func performRollover() {
        let todayKey = lastOpenDate.isEmpty ? Self.dayKey(for: Date()) : lastOpenDate
        let todaysRuns = (importedRuns + SampleData.runs).sortedByTimeLabel()
        if !todaysRuns.isEmpty {
            let archive = ExperimentDayRecord(
                id: "past-\(todayKey)",
                dateLabel: Self.displayDateLabel(from: todayKey),
                weekday: Self.weekdayLabel(from: todayKey),
                summary: "\(todaysRuns.count) 个实验 · 已归档",
                runs: todaysRuns
            )
            pastDays.removeAll { $0.id == archive.id }
            pastDays.insert(archive, at: 0)
        }
        importedRuns = tomorrowRuns.map {
            LabRun(id: $0.id, title: $0.title, area: $0.area, timeLabel: $0.timeLabel, status: "已排期", protocolName: $0.protocolName, scaledVolumeLabel: $0.scaledVolumeLabel, steps: $0.steps)
        }
        tomorrowRuns = []
        lastOpenDate = Self.dayKey(for: Date())
    }

    // MARK: - Persistence helpers

    private func loadAll() {
        if let data = UserDefaults.standard.data(forKey: "importedLabRuns"),
           let runs = try? JSONDecoder().decode([LabRun].self, from: data) { importedRuns = runs }
        if let data = UserDefaults.standard.data(forKey: "tomorrowLabRuns"),
           let runs = try? JSONDecoder().decode([LabRun].self, from: data) { tomorrowRuns = runs }
        if let data = UserDefaults.standard.data(forKey: "pastExperimentDays"),
           let days = try? JSONDecoder().decode([ExperimentDayRecord].self, from: data) { pastDays = days }
        if let data = UserDefaults.standard.data(forKey: "inventoryItems"),
           let items = try? JSONDecoder().decode([InventoryItem].self, from: data) { inventoryItems = items }
    }

    private func saveImportedRuns(_ runs: [LabRun]) {
        guard let data = try? JSONEncoder().encode(runs) else { return }
        UserDefaults.standard.set(data, forKey: "importedLabRuns")
    }
    private func saveTomorrowRuns(_ runs: [LabRun]) {
        guard let data = try? JSONEncoder().encode(runs) else { return }
        UserDefaults.standard.set(data, forKey: "tomorrowLabRuns")
    }
    private func savePastDays(_ days: [ExperimentDayRecord]) {
        guard let data = try? JSONEncoder().encode(days) else { return }
        UserDefaults.standard.set(data, forKey: "pastExperimentDays")
    }
    private func saveInventoryItems(_ items: [InventoryItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: "inventoryItems")
    }

    private func resetDemoData() {
        importedRuns = []
        inventoryItems = SampleData.inventory
        UserDefaults.standard.removeObject(forKey: "completedStepIDs")
        UserDefaults.standard.removeObject(forKey: "activeLabTimers")
        UserDefaults.standard.removeObject(forKey: "importedLabRuns")
        UserDefaults.standard.removeObject(forKey: "tomorrowLabRuns")
        UserDefaults.standard.removeObject(forKey: "pastExperimentDays")
        UserDefaults.standard.removeObject(forKey: "inventoryItems")
        UserDefaults.standard.removeObject(forKey: "lastLabBuddyOpenDate")
        lastOpenDate = ""
    }

    // MARK: - Date helpers

    static func dayKey(for date: Date) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func displayDateLabel(from key: String) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: key) else { return key }
        f.dateFormat = "M月d日"; return f.string(from: date)
    }

    static func weekdayLabel(from key: String) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: key) else { return "" }
        f.dateFormat = "EEE"; return f.string(from: date)
    }
}

// MARK: - New Day Confirm Sheet (Phase 4 D-08, D-09)

private struct NewDayConfirmSheet: View {
    let confirmRollover: () -> Void
    let dismiss: () -> Void

    private let messages = [
        "新的一天，继续加油 💪",
        "昨天的实验已归档，今天从头开始",
        "保持节奏，今天也会顺利的",
        "每一天的数据都值得被好好记录"
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "sunrise.fill")
                .font(.system(size: 52))
                .foregroundStyle(.teal)

            VStack(spacing: 8) {
                Text("检测到新的一天")
                    .font(.title2.bold())
                Text("是否将昨天的实验归档，并将明天的计划移入今天？")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text(messages.randomElement() ?? messages[0])
                .font(.body.italic())
                .foregroundStyle(.teal)
                .padding(.horizontal, 32)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                Button(action: confirmRollover) {
                    Text("开始新的一天")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: dismiss) {
                    Text("暂时保持现状")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(24)
        .presentationDetents([.medium])
    }
}

// MARK: - Today View (Phase 4 三段式)

private struct TodayView: View {
    @Binding var importedRuns: [LabRun]
    @Binding var tomorrowRuns: [LabRun]
    @Binding var pastDays: [ExperimentDayRecord]
    let onEndDay: () -> Void

    @AppStorage("completedStepIDs") private var completedStepIDsData = ""
    @State private var activeTimers: [ActiveLabTimer] = []
    @State private var selectedDataCardRun: LabRun?
    @State private var focusedRun: LabRun?
    @State private var selectedMode: TodayMode = .today
    @State private var selectedRecordDayID = SampleData.pastDays.first?.id ?? ""
    @State private var scheduleRequest: ScheduleRequest?
    @State private var showEndDayConfirm = false

    private var completedStepIDs: Set<String> {
        get { Set(completedStepIDsData.split(separator: ",").map(String.init)) }
        nonmutating set { completedStepIDsData = newValue.sorted().joined(separator: ",") }
    }

    private var todayRuns: [LabRun] {
        (importedRuns + SampleData.runs).sortedByTimeLabel()
    }

    private var historyDays: [ExperimentDayRecord] { pastDays }

    private var selectedRecordDay: ExperimentDayRecord {
        historyDays.first { $0.id == selectedRecordDayID }
            ?? historyDays.first
            ?? ExperimentDayRecord(id: "empty", dateLabel: "过去", weekday: "", summary: "还没有记录", runs: [])
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
                    case .past:
                        ExperimentCalendarView(
                            days: historyDays,
                            selectedDayID: $selectedRecordDayID
                        )
                        ExperimentDayDetailView(day: selectedRecordDay, completedStepIDs: completedStepIDs)

                    case .today:
                        if !activeTimers.isEmpty {
                            TimerDock(activeTimers: activeTimers, stopTimer: stopTimer)
                        }

                        EditableScheduleTimelineView(
                            title: "今天",
                            subtitle: "\(todayRuns.count) 个实验",
                            emptyTitle: "今天还没有实验",
                            emptySubtitle: "从 09:00 开始新建第一个实验。",
                            targetDay: .today,
                            runs: todayRuns,
                            completedStepIDs: completedStepIDs,
                            activeTimers: activeTimers,
                            addAtTime: { timeLabel in
                                scheduleRequest = ScheduleRequest(targetDay: .today, timeLabel: timeLabel)
                            },
                            toggleStep: toggleStepCompletion,
                            startTimer: { run in startTimer(for: run) },
                            showDataCard: { selectedDataCardRun = $0 },
                            openBenchMode: { focusedRun = $0 },
                            removeRun: { run in
                                if run.id.hasPrefix("import-") {
                                    importedRuns.removeAll { $0.id == run.id }
                                }
                            }
                        )

                        // End day button
                        Button {
                            showEndDayConfirm = true
                        } label: {
                            Label("结束今天", systemImage: "moon.stars")
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .foregroundStyle(.secondary)

                    case .tomorrow:
                        TomorrowPlanView(
                            runs: tomorrowRuns.sortedByTimeLabel(),
                            completedStepIDs: completedStepIDs,
                            removeRun: { id in tomorrowRuns.removeAll { $0.id == id } },
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
                DataCardSheet(run: run, completedStepIDs: completedStepIDs)
            }
            .sheet(item: $scheduleRequest) { request in
                AddExperimentSheet(request: request) { run in
                    switch request.targetDay {
                    case .today: importedRuns.insert(run, at: 0)
                    case .tomorrow: tomorrowRuns.insert(run, at: 0)
                    }
                }
            }
            .sheet(item: $focusedRun) { run in
                BenchModeView(
                    run: run,
                    completedStepIDs: completedStepIDs,
                    activeTimer: activeTimers.first { $0.runID == run.id },
                    toggleStep: { stepID in
                        var next = completedStepIDs
                        if next.contains(stepID) { next.remove(stepID) } else { next.insert(stepID) }
                        completedStepIDs = next
                    },
                    completeRun: {
                        markRunComplete(run)
                        selectedDataCardRun = run
                    },
                    startTimer: { startTimer(for: run) }
                )
            }
            .confirmationDialog("结束今天", isPresented: $showEndDayConfirm, titleVisibility: .visible) {
                Button("归档今天并开始新的一天", role: .destructive) {
                    onEndDay()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("今天所有实验（含未完成）将归档到「过去」，明天的计划移入今天。")
            }
            .onAppear(perform: loadTimers)
            .onChange(of: activeTimers) { saveTimers(activeTimers) }
        }
    }

    private func startTimer(for run: LabRun) {
        guard let step = run.steps.first(where: { $0.durationMinutes != nil && !completedStepIDs.contains($0.id) })
                ?? run.steps.first(where: { $0.durationMinutes != nil }),
              let dur = step.durationMinutes else { return }
        let now = Date()
        let timer = ActiveLabTimer(id: "\(run.id)-\(step.id)", runID: run.id, runTitle: run.title, stepTitle: step.title, startedAt: now, endsAt: now.addingTimeInterval(TimeInterval(dur * 60)))
        activeTimers.removeAll { $0.id == timer.id || $0.runID == run.id }
        activeTimers.append(timer)
        activeTimers.sort { $0.endsAt < $1.endsAt }
    }

    private func stopTimer(_ timer: ActiveLabTimer) {
        activeTimers.removeAll { $0.id == timer.id }
    }

    private func toggleStepCompletion(_ stepID: String) {
        var next = completedStepIDs
        if next.contains(stepID) { next.remove(stepID) } else { next.insert(stepID) }
        completedStepIDs = next
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
              let timers = try? JSONDecoder().decode([ActiveLabTimer].self, from: data) else { return }
        activeTimers = timers.sorted { $0.endsAt < $1.endsAt }
    }

    private func saveTimers(_ timers: [ActiveLabTimer]) {
        guard let data = try? JSONEncoder().encode(timers) else { return }
        UserDefaults.standard.set(data, forKey: "activeLabTimers")
    }
}

// MARK: - Three-path Add Experiment Sheet (Phase 4 D-13)

enum PlanTargetDay: String {
    case today
    case tomorrow
}

struct ScheduleRequest: Identifiable {
    let id = UUID()
    let targetDay: PlanTargetDay
    let timeLabel: String
}

private enum AddExperimentPath: String, CaseIterable, Identifiable {
    case importProtocol = "导入 Protocol"
    case manual = "手动实验"
    case carryOver = "顺延占位"
    var id: String { rawValue }
}

struct AddExperimentSheet: View {
    let request: ScheduleRequest
    let onAdd: (LabRun) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var path: AddExperimentPath = .importProtocol
    @State private var selectedProtocolID = SampleData.protocols.first?.id ?? ""
    @State private var targetVolume = 50.0
    @State private var manualTitle = ""
    @State private var manualArea: WorkflowArea = .cell
    @State private var manualNote = ""
    @State private var carryOverTitle = ""

    private var selectedProtocol: LabProtocol {
        SampleData.protocols.first { $0.id == selectedProtocolID } ?? SampleData.protocols[0]
    }

    private var destinationTitle: String {
        request.targetDay == .today ? "今天 \(request.timeLabel)" : "明天 \(request.timeLabel)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("添加方式", selection: $path) {
                        ForEach(AddExperimentPath.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("插入位置") {
                    Label(destinationTitle, systemImage: "calendar.badge.plus").font(.headline)
                }

                switch path {
                case .importProtocol:
                    Section("选择 Protocol") {
                        Picker("Protocol", selection: $selectedProtocolID) {
                            ForEach(SampleData.protocols) { p in Text(p.name).tag(p.id) }
                        }
                        HStack {
                            Text("目标体积")
                            Spacer()
                            Text("\(Int(targetVolume)) \(selectedProtocol.volumeUnit)").font(.headline.monospacedDigit())
                        }
                        Slider(value: $targetVolume, in: 10...200, step: 10)
                    }
                    Section("预览") {
                        LabeledContent("实验类型", value: selectedProtocol.area.rawValue)
                        LabeledContent("预计时长", value: selectedProtocol.expectedDuration)
                    }

                case .manual:
                    Section("手动实验") {
                        TextField("实验名称", text: $manualTitle)
                        Picker("实验类型", selection: $manualArea) {
                            ForEach(WorkflowArea.allCases) { area in Text(area.rawValue).tag(area) }
                        }
                        TextField("备注（可选）", text: $manualNote)
                    }

                case .carryOver:
                    Section("顺延占位") {
                        TextField("实验名称（如：WB 一抗孵育中）", text: $carryOverTitle)
                    }
                    Section {
                        Label("顺延占位代表跨夜或长时间实验，不计入今日完成计数。", systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        let run = buildRun()
                        onAdd(run)
                        dismiss()
                    } label: {
                        Label("加入时间流", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(path == .manual && manualTitle.isEmpty || path == .carryOver && carryOverTitle.isEmpty)
                }
            }
            .navigationTitle("添加实验")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
    }

    private func buildRun() -> LabRun {
        let ts = Int(Date().timeIntervalSince1970)
        switch path {
        case .importProtocol:
            let factor = targetVolume / selectedProtocol.baseVolume
            let recipeSummary = selectedProtocol.ingredients.prefix(3).map { "\($0.name) \($0.scaled(by: factor))" }.joined(separator: " / ")
            let dur = estimatedMinutes(from: selectedProtocol.expectedDuration)
            let steps: [LabStep] = [
                LabStep(id: "review-\(ts)", title: "核对换算配方", detail: recipeSummary, durationMinutes: nil, isCarryOver: false)
            ] + (selectedProtocol.steps.isEmpty ? [LabStep(id: "exec-\(ts)", title: "执行 Protocol", detail: selectedProtocol.name, durationMinutes: dur, isCarryOver: false)] : selectedProtocol.steps.map { s in
                LabStep(id: "\(s.id)-\(ts)", title: s.title, detail: s.detail, durationMinutes: s.durationMinutes ?? dur, isCarryOver: s.isCarryOver)
            }) + [LabStep(id: "record-\(ts)", title: "记录结果", detail: "完成后生成结果卡片", durationMinutes: nil, isCarryOver: false)]

            return LabRun(
                id: "import-\(request.targetDay.rawValue)-\(selectedProtocol.id)-\(ts)",
                title: selectedProtocol.name,
                area: selectedProtocol.area,
                timeLabel: request.timeLabel,
                status: request.targetDay == .today ? "已排期" : "明日计划",
                protocolName: selectedProtocol.name,
                scaledVolumeLabel: "\(formatVol(targetVolume)) \(selectedProtocol.volumeUnit) · x\(String(format: "%.2f", factor))",
                steps: steps
            )

        case .manual:
            return LabRun(
                id: "manual-\(ts)",
                title: manualTitle,
                area: manualArea,
                timeLabel: request.timeLabel,
                status: request.targetDay == .today ? "手动" : "明日手动",
                protocolName: "手动实验",
                scaledVolumeLabel: "",
                steps: [
                    LabStep(id: "manual-step-\(ts)", title: manualTitle, detail: manualNote.isEmpty ? "手动实验" : manualNote, durationMinutes: nil, isCarryOver: false)
                ]
            )

        case .carryOver:
            return LabRun(
                id: "carryover-\(ts)",
                title: carryOverTitle,
                area: .cell,
                timeLabel: request.timeLabel,
                status: "顺延占位",
                protocolName: "顺延占位",
                scaledVolumeLabel: "",
                steps: [
                    LabStep(id: "co-step-\(ts)", title: carryOverTitle, detail: "跨夜或长时间进行中", durationMinutes: nil, isCarryOver: true)
                ]
            )
        }
    }

    private func estimatedMinutes(from text: String) -> Int? {
        let digits = text.prefix { $0.isNumber }
        guard let m = Int(digits), m > 0 else { return nil }
        return m
    }

    private func formatVol(_ v: Double) -> String {
        v.rounded() == v ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}

// MARK: - Today Mode

private enum TodayMode: String, CaseIterable, Identifiable {
    case past, today, tomorrow
    var id: String { rawValue }
    var title: String {
        switch self {
        case .past: return "过去"
        case .today: return "今天"
        case .tomorrow: return "明天"
        }
    }
}

// MARK: - Monthly Calendar Grid

private struct ExperimentCalendarView: View {
    let days: [ExperimentDayRecord]
    @Binding var selectedDayID: String

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
                            cellScale: cellScale
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
    let onTap: () -> Void

    private var dayNumber: String {
        let cal = Calendar(identifier: .gregorian)
        return "\(cal.component(.day, from: date))"
    }

    private var hasRecord: Bool { record != nil }
    private var runCount: Int { record?.runs.count ?? 0 }

    // colour dots for experiment types present
    private var dotColors: [Color] {
        guard let runs = record?.runs else { return [] }
        let areas = Array(Set(runs.map(\.area)))
        return areas.prefix(3).map { area -> Color in
            switch area {
            case .cell: return .teal
            case .cloning: return .blue
            case .blot: return .purple
            }
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

private struct ExperimentDayDetailView: View {
    let day: ExperimentDayRecord
    let completedStepIDs: Set<String>

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

// MARK: - Timer Dock

private struct TimerDock: View {
    let activeTimers: [ActiveLabTimer]
    let stopTimer: (ActiveLabTimer) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("运行中的计时器").font(.headline)
            ForEach(activeTimers.sorted(by: { $0.endsAt < $1.endsAt })) { timer in
                TimelineView(.periodic(from: Date(), by: 1)) { _ in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(timer.stepTitle).font(.subheadline.weight(.semibold))
                            Text(timer.runTitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(timer.isFinished ? "完成" : formatDuration(timer.remainingSeconds))
                            .font(.title3.monospacedDigit().weight(.bold))
                            .foregroundStyle(timer.isFinished ? .orange : .teal)
                            .contentTransition(.numericText())
                        Button { stopTimer(timer) } label: {
                            Image(systemName: "xmark.circle.fill").font(.title3)
                        }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
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

// MARK: - Editable Schedule Timeline

private struct EditableScheduleTimelineView: View {
    let title: String
    let subtitle: String
    let emptyTitle: String
    let emptySubtitle: String
    let targetDay: PlanTargetDay
    let runs: [LabRun]
    let completedStepIDs: Set<String>
    let activeTimers: [ActiveLabTimer]
    let addAtTime: (String) -> Void
    let toggleStep: (String) -> Void
    let startTimer: (LabRun) -> Void
    let showDataCard: (LabRun) -> Void
    let openBenchMode: (LabRun) -> Void
    let removeRun: (LabRun) -> Void

    private var sorted: [LabRun] { runs.sortedByTimeLabel() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title2.bold())
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

            TimelineInsertButton(timeLabel: suggestedTime(before: sorted.first, after: nil), title: runs.isEmpty ? "新建第一个实验" : "在最前面新建") {
                addAtTime(suggestedTime(before: sorted.first, after: nil))
            }

            if sorted.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "calendar.badge.plus").font(.title2).foregroundStyle(.teal)
                    Text(emptyTitle).font(.headline)
                    Text(emptySubtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, run in
                    RunCard(
                        run: run,
                        completedStepIDs: completedStepIDs,
                        activeTimer: activeTimers.first { $0.runID == run.id },
                        toggleStep: toggleStep,
                        startTimer: { startTimer(run) },
                        showDataCard: { showDataCard(run) },
                        openBenchMode: { openBenchMode(run) },
                        removeRun: (run.id.hasPrefix("import-") || run.id.hasPrefix("manual-") || run.id.hasPrefix("carryover-")) ? { removeRun(run) } : nil
                    )
                    TimelineInsertButton(
                        timeLabel: suggestedTime(before: sorted[safe: index + 1], after: run),
                        title: index == sorted.count - 1 ? "在后面新建" : "在两个实验之间新建"
                    ) {
                        addAtTime(suggestedTime(before: sorted[safe: index + 1], after: run))
                    }
                }
            }
        }
    }

    private func suggestedTime(before nextRun: LabRun?, after previousRun: LabRun?) -> String {
        if let prev = previousRun, let prevMin = minutes(prev.timeLabel) {
            if let next = nextRun, let nextMin = minutes(next.timeLabel), nextMin > prevMin {
                return timeLabel(prevMin + max(15, (nextMin - prevMin) / 2))
            }
            return timeLabel(min(prevMin + 60, 23 * 60 + 30))
        }
        if let next = nextRun, let nextMin = minutes(next.timeLabel) {
            return timeLabel(max(nextMin - 60, 7 * 60))
        }
        return targetDay == .today ? "09:00" : "09:30"
    }

    private func minutes(_ label: String) -> Int? {
        let parts = label.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }

    private func timeLabel(_ totalMin: Int) -> String {
        let c = min(max(totalMin, 0), 23 * 60 + 59)
        return String(format: "%02d:%02d", c / 60, c % 60)
    }
}

private struct TimelineInsertButton: View {
    let timeLabel: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(timeLabel).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tomorrow Plan View

private struct TomorrowPlanView: View {
    let runs: [LabRun]
    let completedStepIDs: Set<String>
    let removeRun: (String) -> Void
    let showDataCard: (LabRun) -> Void
    let addAtTime: (String) -> Void

    var body: some View {
        EditableScheduleTimelineView(
            title: "明天", subtitle: runs.isEmpty ? "为明天安排实验" : "\(runs.count) 个实验已安排",
            emptyTitle: "还没有明日实验", emptySubtitle: "从 09:30 开始新建第一个实验。",
            targetDay: .tomorrow, runs: runs, completedStepIDs: completedStepIDs, activeTimers: [],
            addAtTime: addAtTime, toggleStep: { _ in }, startTimer: { _ in },
            showDataCard: showDataCard, openBenchMode: { _ in },
            removeRun: { run in removeRun(run.id) }
        )
    }
}

// MARK: - Run Card

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
                    Text(run.timeLabel).font(.title2.monospacedDigit().bold())
                    Text(run.status).font(.caption.weight(.semibold))
                        .foregroundStyle(run.status == "顺延占位" ? .orange : .teal)
                }
                .frame(width: 76, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text(run.title).font(.headline)
                    Text("\(run.area.rawValue) · \(run.protocolName)").font(.subheadline).foregroundStyle(.secondary)
                    if !run.scaledVolumeLabel.isEmpty {
                        Text(run.scaledVolumeLabel).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            VStack(spacing: 10) {
                ForEach(run.steps) { step in
                    StepRow(step: step, isDone: completedStepIDs.contains(step.id), toggle: { toggleStep(step.id) })
                }
            }

            HStack(spacing: 10) {
                Button(action: openBenchMode) {
                    Label("实验台", systemImage: "rectangle.portrait.and.arrow.right").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)

                Button(action: startTimer) {
                    Label(activeTimer == nil ? "启动计时" : "重新计时", systemImage: activeTimer == nil ? "play.fill" : "arrow.clockwise").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)

                if let t = activeTimer {
                    TimelineView(.periodic(from: Date(), by: 1)) { _ in
                        Text(t.isFinished ? "到点" : formatDuration(t.remainingSeconds))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(t.isFinished ? .orange : .teal)
                            .frame(width: 82, height: 44)
                            .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                Button(action: showDataCard) {
                    Image(systemName: "square.and.arrow.up").frame(width: 46, height: 28)
                }
                .buttonStyle(.bordered).controlSize(.large).accessibilityLabel("生成结果卡片")

                if let removeRun {
                    Button(action: removeRun) {
                        Image(systemName: "trash").frame(width: 46, height: 28)
                    }
                    .buttonStyle(.bordered).controlSize(.large).foregroundStyle(.red).accessibilityLabel("移除实验")
                }
            }
        }
        .padding(16)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Step Row

private struct StepRow: View {
    let step: LabStep
    let isDone: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundStyle(isDone ? .teal : .secondary).frame(width: 44, height: 44)
            }
            .accessibilityLabel(isDone ? "标记未完成" : "标记完成")

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title).font(.subheadline.weight(.semibold)).strikethrough(isDone)
                Text(step.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let dur = step.durationMinutes {
                Label("\(dur)m", systemImage: "timer")
                    .font(.caption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Color.blue.opacity(0.12), in: Capsule()).foregroundStyle(.blue)
            }
        }
        .padding(10)
        .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Bench Mode

private struct BenchModeView: View {
    let run: LabRun
    let completedStepIDs: Set<String>
    let activeTimer: ActiveLabTimer?
    let toggleStep: (String) -> Void
    let completeRun: () -> Void
    let startTimer: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var doneCount: Int { run.steps.filter { completedStepIDs.contains($0.id) }.count }
    private var currentStep: LabStep? { run.steps.first { !completedStepIDs.contains($0.id) } ?? run.steps.last }
    private var isRunComplete: Bool { doneCount == run.steps.count }

    var body: some View {
        ZStack {
            Color.labBackground.ignoresSafeArea()
            VStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(run.timeLabel).font(.headline.monospacedDigit()).foregroundStyle(.secondary)
                        Text(run.title).font(.largeTitle.bold()).lineLimit(2)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 34))
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("退出实验台模式")
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("当前步骤").font(.headline).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(doneCount)/\(run.steps.count)").font(.headline.monospacedDigit())
                    }
                    if let step = currentStep {
                        Text(step.title).font(.system(size: 34, weight: .bold)).minimumScaleFactor(0.75)
                        Text(step.detail).font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        if let dur = step.durationMinutes {
                            Label("\(dur) min", systemImage: "timer")
                                .font(.title3.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9)
                                .background(Color.blue.opacity(0.12), in: Capsule()).foregroundStyle(.blue)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                if let timer = activeTimer {
                    BenchTimerPanel(timer: timer)
                } else {
                    Button(action: startTimer) {
                        Label("为当前实验启动计时", systemImage: "play.fill")
                            .font(.title3.weight(.bold)).frame(maxWidth: .infinity, minHeight: 62)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                }

                VStack(spacing: 10) {
                    ForEach(run.steps) { step in
                        BenchStepRow(step: step, isDone: completedStepIDs.contains(step.id), toggle: { toggleStep(step.id) })
                    }
                }

                Button(action: completeRun) {
                    Label(isRunComplete ? "生成结果卡片" : "完成本实验并生成卡片",
                          systemImage: isRunComplete ? "rectangle.on.rectangle.angled" : "checkmark.seal.fill")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 58)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)

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
                Text(timer.stepTitle).font(.headline).foregroundStyle(.secondary)
                Text(timer.isFinished ? "完成" : formatDuration(timer.remainingSeconds))
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                    .foregroundStyle(timer.isFinished ? .orange : .teal)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity).padding(20)
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
                    .font(.system(size: 30)).foregroundStyle(isDone ? .teal : .secondary).frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title).font(.headline).strikethrough(isDone)
                    Text(step.detail).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared helpers

private func formatDuration(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

private extension Array where Element == LabRun {
    func sortedByTimeLabel() -> [LabRun] {
        sorted { lhs, rhs in minutes(lhs.timeLabel) < minutes(rhs.timeLabel) }
    }
    private func minutes(_ label: String) -> Int {
        let parts = label.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return Int.max }
        return h * 60 + m
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
