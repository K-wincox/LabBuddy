import SwiftUI
#if os(iOS)
import UIKit
import AVFoundation
import AudioToolbox
#endif

struct ContentView: View {
    @State private var importedRuns: [LabRun] = []
    @State private var tomorrowRuns: [LabRun] = []
    @State private var pastDays: [ExperimentDayRecord] = []
    @State private var inventoryItems: [InventoryItem] = []
    @State private var projects: [Project] = []
    @AppStorage("lastLabBuddyOpenDate") private var lastOpenDate = ""
    @State private var showNewDaySheet = false

    var body: some View {
        NavigationStack {
            TabView {
                TodayView(
                    importedRuns: $importedRuns,
                    tomorrowRuns: $tomorrowRuns,
                    pastDays: $pastDays,
                    projects: projects,
                    onEndDay: endDay
                )
                .tabItem { Label("今日", systemImage: "calendar") }

                ProtocolLibraryView()
                    .tabItem { Label("Protocol", systemImage: "list.clipboard") }

                CalculatorToolkitView()
                    .tabItem { Label("工具", systemImage: "function") }

                NavigationStack {
                    MyWorkspaceView(items: $inventoryItems, projects: $projects, resetDemoData: resetDemoData)
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
        .onChange(of: importedRuns) { _, newValue in saveImportedRuns(newValue) }
        .onChange(of: tomorrowRuns) { _, newValue in saveTomorrowRuns(newValue) }
        .onChange(of: pastDays) { _, newValue in savePastDays(newValue) }
        .onChange(of: inventoryItems) { _, newValue in saveInventoryItems(newValue) }
        .onChange(of: projects) { _, newValue in saveProjects(newValue) }
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
        guard !importedRuns.isEmpty || !tomorrowRuns.isEmpty else {
            lastOpenDate = todayKey
            return
        }
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
        let todaysRuns = importedRuns.sortedByTimeLabel()
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
            LabRun(id: $0.id, title: $0.title, area: $0.area, timeLabel: $0.timeLabel, status: "已排期", protocolName: $0.protocolName, scaledVolumeLabel: $0.scaledVolumeLabel, projectID: $0.projectID, steps: $0.steps)
        }
        tomorrowRuns = []
        lastOpenDate = Self.dayKey(for: Date())
    }

    // MARK: - Persistence helpers

    private func loadAll() {
        if let data = UserDefaults.standard.data(forKey: "importedLabRuns"),
           let runs = try? JSONDecoder().decode([LabRun].self, from: data) {
            importedRuns = runs
        } else {
            importedRuns = []
        }
        if let data = UserDefaults.standard.data(forKey: "tomorrowLabRuns"),
           let runs = try? JSONDecoder().decode([LabRun].self, from: data) { tomorrowRuns = runs }
        if let data = UserDefaults.standard.data(forKey: "pastExperimentDays"),
           let days = try? JSONDecoder().decode([ExperimentDayRecord].self, from: data) {
            pastDays = days
        } else {
            pastDays = []
        }
        if let data = UserDefaults.standard.data(forKey: "inventoryItems"),
           let items = try? JSONDecoder().decode([InventoryItem].self, from: data) {
            inventoryItems = items
        } else {
            inventoryItems = []
        }
        if let data = UserDefaults.standard.data(forKey: "userProjects"),
           let projs = try? JSONDecoder().decode([Project].self, from: data), !projs.isEmpty { projects = projs }
        migrateLegacyProjects()
    }

    private func migrateLegacyProjects() {
        var needsSave = false
        let allRuns = importedRuns + tomorrowRuns + pastDays.flatMap(\.runs)
        for run in allRuns {
            if let ctx = run.projectID, !ctx.isEmpty, !projects.contains(where: { $0.id == ctx }) {
                // Legacy free-text projectContext — create a Project from it
                let newProject = Project(name: ctx, colorHex: Project.palette.randomElement()?.hex ?? "#4ECDC4", description: "")
                projects.append(newProject)
                needsSave = true
            }
        }
        // Migrate runs with legacy projectContext to projectID
        for i in importedRuns.indices {
            if let ctx = importedRuns[i].projectID, !ctx.isEmpty, projects.contains(where: { $0.id == ctx || $0.name == ctx }) {
                if let project = projects.first(where: { $0.name == ctx }) {
                    importedRuns[i].projectID = project.id
                    needsSave = true
                }
            }
        }
        if needsSave {
            saveImportedRuns(importedRuns)
            saveProjects(projects)
        }
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
    private func saveProjects(_ projs: [Project]) {
        guard let data = try? JSONEncoder().encode(projs) else { return }
        UserDefaults.standard.set(data, forKey: "userProjects")
    }

    private func resetDemoData() {
        importedRuns = []
        tomorrowRuns = []
        pastDays = []
        inventoryItems = []
        projects = []
        UserDefaults.standard.removeObject(forKey: "completedStepIDs")
        UserDefaults.standard.removeObject(forKey: "activeLabTimers")
        UserDefaults.standard.removeObject(forKey: "lastLabBuddyOpenDate")
        UserDefaults.standard.removeObject(forKey: "userProjects")
        saveImportedRuns(importedRuns)
        saveTomorrowRuns(tomorrowRuns)
        savePastDays(pastDays)
        saveInventoryItems(inventoryItems)
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
    let projects: [Project]
    let onEndDay: () -> Void

    @AppStorage("completedStepIDs") private var completedStepIDsData = ""
    @State private var activeTimers: [ActiveLabTimer] = []
    @State private var selectedDataCardRun: LabRun?
    @State private var focusedRun: LabRun?
    @State private var selectedMode: TodayMode = .today
    @State private var selectedRecordDayID = ""
    @State private var scheduleRequest: ScheduleRequest?
    @State private var showEndDayConfirm = false
    @AppStorage("preferencesTimerSound") private var timerSound = true
    @AppStorage("preferencesVoiceAnnouncementTemplate") private var voiceAnnouncementTemplate = "{实验}，{步骤}已完成"
    @State private var lastNotifiedTimerIDs: Set<String> = []
    @State private var selectedProjectFilter: String? = nil

    private let speechSynthesizer = AVSpeechSynthesizer()

    private var completedStepIDs: Set<String> {
        get { Set(completedStepIDsData.split(separator: ",").map(String.init)) }
        nonmutating set { completedStepIDsData = newValue.sorted().joined(separator: ",") }
    }

    private var todayRuns: [LabRun] {
        let runs = importedRuns.sortedByTimeLabel()
        guard let filter = selectedProjectFilter else { return runs }
        return runs.filter { $0.projectID == filter }
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

                    if !projects.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(title: "全部", isSelected: selectedProjectFilter == nil) {
                                    selectedProjectFilter = nil
                                }
                                ForEach(projects) { project in
                                    let projectColor = Color(hex: project.colorHex)
                                    FilterChip(
                                        title: project.name,
                                        isSelected: selectedProjectFilter == project.id,
                                        accentColor: projectColor
                                    ) {
                                        selectedProjectFilter = selectedProjectFilter == project.id ? nil : project.id
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }

                    switch selectedMode {
                    case .past:
                        ExperimentCalendarView(
                            days: historyDays,
                            selectedDayID: $selectedRecordDayID,
                            projects: projects
                        )
                        if let filter = selectedProjectFilter {
                            ProjectDaysListView(
                                days: historyDays,
                                projectFilter: filter,
                                projects: projects,
                                completedStepIDs: completedStepIDs
                            )
                        } else {
                            ExperimentDayDetailView(
                                day: selectedRecordDay,
                                completedStepIDs: completedStepIDs,
                                projects: projects
                            )
                        }

                    case .today:
                        if !activeTimers.isEmpty {
                            TimerDock(activeTimers: activeTimers, stopTimer: stopTimer)
                        }

                        if todayRuns.isEmpty {
                            VStack(spacing: 16) {
                                Spacer()
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 64))
                                    .foregroundStyle(.teal.opacity(0.3))
                                Text("今天还没有安排实验")
                                    .font(.title3.weight(.semibold))
                                Text("点击下方按钮添加今天的实验计划")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                Button {
                                    scheduleRequest = ScheduleRequest(targetDay: .today, timeLabel: "09:00")
                                } label: {
                                    Label("添加实验", systemImage: "plus.circle.fill")
                                        .font(.headline)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.teal)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 32)
                        } else {
                            DayTimelineView(
                                targetDay: .today,
                                runs: todayRuns,
                                completedStepIDs: completedStepIDs,
                                activeTimers: activeTimers,
                                projects: projects,
                                addAtTime: { timeLabel in
                                    scheduleRequest = ScheduleRequest(targetDay: .today, timeLabel: timeLabel)
                                },
                                startTimer: { run, step, customMin in startTimer(for: run, step: step, customMinutes: customMin) },
                                showDataCard: { selectedDataCardRun = $0 },
                                openBenchMode: { focusedRun = $0 },
                                removeRun: { run in
                                    if run.id.hasPrefix("import-") {
                                        importedRuns.removeAll { $0.id == run.id }
                                        hapticFeedback(.medium)
                                    }
                                },
                                onUpdateRun: { updatedRun in
                                    if let index = importedRuns.firstIndex(where: { $0.id == updatedRun.id }) {
                                        importedRuns[index] = updatedRun
                                    }
                                },
                                pauseTimer: pauseTimer,
                                resumeTimer: resumeTimer,
                                stopTimer: stopTimer
                            )
                        }

                        if !todayRuns.isEmpty {
                            Button {
                                showEndDayConfirm = true
                            } label: {
                                Label("结束今天", systemImage: "moon.stars")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }

                    case .tomorrow:
                        if tomorrowRuns.isEmpty {
                            // Empty state for tomorrow
                            VStack(spacing: 16) {
                                Spacer()
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 64))
                                    .foregroundStyle(.teal.opacity(0.3))
                                Text("明天还没有计划")
                                    .font(.title3.weight(.semibold))
                                Text("提前规划明天的实验安排")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                Button {
                                    scheduleRequest = ScheduleRequest(targetDay: .tomorrow, timeLabel: "09:00")
                                } label: {
                                    Label("添加明天的实验", systemImage: "plus.circle.fill")
                                        .font(.headline)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.teal)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 32)
                        } else {
                            DayTimelineView(
                                targetDay: .tomorrow,
                                runs: tomorrowRuns.sortedByTimeLabel(),
                                completedStepIDs: completedStepIDs,
                                activeTimers: [],
                                projects: projects,
                                addAtTime: { timeLabel in
                                    scheduleRequest = ScheduleRequest(targetDay: .tomorrow, timeLabel: timeLabel)
                                },
                                startTimer: { _, _, _ in },
                                showDataCard: { selectedDataCardRun = $0 },
                                openBenchMode: { _ in },
                                removeRun: { run in tomorrowRuns.removeAll { $0.id == run.id }; hapticFeedback(.medium) },
                                onUpdateRun: { updatedRun in
                                    if let index = tomorrowRuns.firstIndex(where: { $0.id == updatedRun.id }) {
                                        tomorrowRuns[index] = updatedRun
                                    }
                                },
                                pauseTimer: { _ in },
                                resumeTimer: { _ in },
                                stopTimer: { _ in }
                            )
                        }
                    }
                }
                .padding(18)
            }
            .sheet(item: $selectedDataCardRun) { run in
                DataCardSheet(run: run, completedStepIDs: completedStepIDs)
            }
            .sheet(item: $scheduleRequest) { request in
                AddExperimentSheet(request: request, projects: projects) { run in
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
                    startTimer: { customMin in startTimer(for: run, customMinutes: customMin) },
                    pauseTimer: {
                        if let t = activeTimers.first(where: { $0.runID == run.id }) { pauseTimer(t) }
                    },
                    resumeTimer: {
                        if let t = activeTimers.first(where: { $0.runID == run.id }) { resumeTimer(t) }
                    },
                    stopTimer: {
                        if let t = activeTimers.first(where: { $0.runID == run.id }) { stopTimer(t) }
                    },
                    showDataCard: { selectedDataCardRun = run }
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
            .onChange(of: activeTimers) { _, newTimers in
                saveTimers(newTimers)
                checkForFinishedTimers(newTimers)
            }
        }
    }

    private func startTimer(for run: LabRun, step: LabStep? = nil, customMinutes: Int? = nil) {
        let targetStep = step ?? (run.steps.first(where: { $0.durationMinutes != nil && !completedStepIDs.contains($0.id) })
                                  ?? run.steps.first(where: { $0.durationMinutes != nil }))
        guard let targetStep = targetStep else { return }
        let dur = customMinutes ?? targetStep.durationMinutes ?? 5
        let now = Date()
        let timer = ActiveLabTimer(id: "\(run.id)-\(targetStep.id)", runID: run.id, runTitle: run.title, stepTitle: targetStep.title, startedAt: now, endsAt: now.addingTimeInterval(TimeInterval(dur * 60)))
        activeTimers.removeAll { $0.id == timer.id || $0.runID == run.id }
        activeTimers.append(timer)
        activeTimers.sort { $0.endsAt < $1.endsAt }
        hapticNotification(.success)
    }

    private func stopTimer(_ timer: ActiveLabTimer) {
        activeTimers.removeAll { $0.id == timer.id }
        lastNotifiedTimerIDs.remove(timer.id)
        hapticFeedback(.medium)
    }

    private func pauseTimer(_ timer: ActiveLabTimer) {
        guard let idx = activeTimers.firstIndex(where: { $0.id == timer.id }) else { return }
        // Freeze remaining and push endsAt far out so it can never fire while paused
        let frozen = timer.remainingSeconds
        activeTimers[idx].pausedRemaining = frozen
        activeTimers[idx].endsAt = Date.distantFuture
        hapticFeedback(.light)
    }

    private func resumeTimer(_ timer: ActiveLabTimer) {
        guard let idx = activeTimers.firstIndex(where: { $0.id == timer.id }),
              let paused = timer.pausedRemaining else { return }
        let newEndsAt = Date().addingTimeInterval(TimeInterval(paused))
        activeTimers[idx].endsAt = newEndsAt
        activeTimers[idx].pausedRemaining = nil
        activeTimers.sort { $0.endsAt < $1.endsAt }
        hapticFeedback(.light)
    }

    private func toggleStepCompletion(_ stepID: String) {
        var next = completedStepIDs
        if next.contains(stepID) { next.remove(stepID) } else { next.insert(stepID) }
        completedStepIDs = next
        hapticFeedback(.light)
    }

    private func markRunComplete(_ run: LabRun) {
        var next = completedStepIDs
        run.steps.forEach { next.insert($0.id) }
        completedStepIDs = next
        activeTimers.removeAll { $0.runID == run.id }
        focusedRun = nil
        hapticNotification(.success)
    }

    // MARK: - Haptic Feedback

    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
        #endif
    }

    private func hapticNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
        #endif
    }

    private func loadTimers() {
        guard let data = UserDefaults.standard.data(forKey: "activeLabTimers"),
              let timers = try? JSONDecoder().decode([ActiveLabTimer].self, from: data) else { return }
        // Only keep timers that are still relevant: not finished, or paused
        let valid = timers.filter { !$0.isFinished }
        activeTimers = valid.sorted { $0.endsAt < $1.endsAt }
        // If we filtered any out, persist the cleaned list
        if valid.count != timers.count {
            saveTimers(valid)
        }
    }

    private func saveTimers(_ timers: [ActiveLabTimer]) {
        guard let data = try? JSONEncoder().encode(timers) else { return }
        UserDefaults.standard.set(data, forKey: "activeLabTimers")
    }

    private func checkForFinishedTimers(_ timers: [ActiveLabTimer]) {
        for timer in timers {
            if timer.isFinished && !lastNotifiedTimerIDs.contains(timer.id) {
                lastNotifiedTimerIDs.insert(timer.id)
                playTimerAlert(for: timer)
            }
        }
        // Clean up old notified IDs
        lastNotifiedTimerIDs = lastNotifiedTimerIDs.filter { id in
            timers.contains { $0.id == id }
        }
    }

    private func playTimerAlert(for timer: ActiveLabTimer) {
        #if os(iOS)
        // Play system sound
        AudioServicesPlaySystemSound(1005)

        // Use customizable voice template if sound is enabled
        if timerSound {
            let message = voiceAnnouncementTemplate
                .replacingOccurrences(of: "{实验}", with: timer.runTitle)
                .replacingOccurrences(of: "{步骤}", with: timer.stepTitle)
            let utterance = AVSpeechUtterance(string: message)
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
            utterance.rate = 0.5
            utterance.volume = 1.0
            speechSynthesizer.speak(utterance)
        }
        #endif
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
    let projects: [Project]
    let onAdd: (LabRun) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var path: AddExperimentPath = .importProtocol
    @State private var selectedProtocolID = SampleData.protocols.first?.id ?? ""
    @State private var targetVolume = 50.0
    @State private var targetVolumeText = "50"
    @State private var experimentName = ""
    @State private var selectedProjectID: String? = nil
    @State private var manualTitle = ""
    @State private var manualArea: WorkflowArea = .cell
    @State private var manualNote = ""
    @State private var carryOverTitle = ""
    @State private var editingTime = false
    @State private var selectedHour = 9
    @State private var selectedMinute = 0

    private var selectedProtocol: LabProtocol {
        SampleData.protocols.first { $0.id == selectedProtocolID } ?? SampleData.protocols[0]
    }

    private var destinationTitle: String {
        let timeStr = editingTime ? String(format: "%02d:%02d", selectedHour, selectedMinute) : request.timeLabel
        return request.targetDay == .today ? "今天 \(timeStr)" : "明天 \(timeStr)"
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
                    Button {
                        editingTime.toggle()
                        if editingTime {
                            // Parse current time
                            let parts = request.timeLabel.split(separator: ":")
                            if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                                selectedHour = h
                                selectedMinute = m
                            }
                        }
                    } label: {
                        HStack {
                            Label(destinationTitle, systemImage: "calendar.badge.plus")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: editingTime ? "checkmark.circle.fill" : "pencil.circle")
                                .foregroundStyle(.teal)
                        }
                    }
                    .buttonStyle(.plain)

                    if editingTime {
                        HStack {
                            Picker("小时", selection: $selectedHour) {
                                ForEach(0..<24) { h in
                                    Text(String(format: "%02d", h)).tag(h)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80)

                            Text(":").font(.title2.bold())

                            Picker("分钟", selection: $selectedMinute) {
                                ForEach([0, 15, 30, 45], id: \.self) { m in
                                    Text(String(format: "%02d", m)).tag(m)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                switch path {
                case .importProtocol:
                    Section("选择 Protocol") {
                        Picker("Protocol", selection: $selectedProtocolID) {
                            ForEach(SampleData.protocols) { p in Text(p.name).tag(p.id) }
                        }
                        .onChange(of: selectedProtocolID) { _, _ in
                            if experimentName.isEmpty || experimentName == SampleData.protocols.first(where: { $0.id == selectedProtocolID })?.name {
                                experimentName = selectedProtocol.name
                            }
                        }
                    }

                    Section("实验命名") {
                        TextField("实验名称", text: $experimentName, prompt: Text(selectedProtocol.name))
                            .font(.body)
                        if !projects.isEmpty {
                            Picker("所属项目", selection: $selectedProjectID) {
                                Text("无项目").tag(nil as String?)
                                ForEach(projects) { project in
                                    HStack {
                                        Circle()
                                            .fill(Color(hex: project.colorHex))
                                            .frame(width: 8, height: 8)
                                        Text(project.name)
                                    }
                                    .tag(project.id as String?)
                                }
                            }
                            .font(.subheadline)
                        }
                    }

                    Section("体积与预览") {
                        HStack {
                            Text("目标体积")
                            Spacer()
                            TextField("体积", text: $targetVolumeText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .onChange(of: targetVolumeText) { _, newValue in
                                    if let val = Double(newValue), val >= 10, val <= 200 {
                                        targetVolume = val
                                    }
                                }
                            Text(selectedProtocol.volumeUnit)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Section("预览") {
                        LabeledContent("实验类型", value: selectedProtocol.area.rawValue)
                        LabeledContent("预计时长", value: selectedProtocol.expectedDuration)
                    }

                case .manual:
                    Section("手动实验") {
                        TextField("实验名称", text: $manualTitle)
                        Picker("实验类型", selection: $manualArea) {
                            ForEach(WorkflowArea.builtIn) { area in Text(area.rawValue).tag(area) }
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .onAppear {
                if experimentName.isEmpty {
                    experimentName = selectedProtocol.name
                }
            }
        }
    }

    private func buildRun() -> LabRun {
        let ts = Int(Date().timeIntervalSince1970)
        let finalTimeLabel = editingTime ? String(format: "%02d:%02d", selectedHour, selectedMinute) : request.timeLabel

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

            let finalName = experimentName.trimmingCharacters(in: .whitespaces).isEmpty ? selectedProtocol.name : experimentName
            let volumeLabel = "\(formatVol(targetVolume)) \(selectedProtocol.volumeUnit) · x\(String(format: "%.2f", factor))"
            let project = selectedProjectID

            return LabRun(
                id: "import-\(request.targetDay.rawValue)-\(selectedProtocol.id)-\(ts)",
                title: finalName,
                area: selectedProtocol.area,
                timeLabel: finalTimeLabel,
                status: request.targetDay == .today ? "已排期" : "明日计划",
                protocolName: selectedProtocol.name,
                scaledVolumeLabel: volumeLabel,
                projectID: project,
                steps: steps
            )

        case .manual:
            return LabRun(
                id: "manual-\(ts)",
                title: manualTitle,
                area: manualArea,
                timeLabel: finalTimeLabel,
                status: request.targetDay == .today ? "手动" : "明日手动",
                protocolName: "手动实验",
                scaledVolumeLabel: "",
                projectID: nil,
                steps: [
                    LabStep(id: "manual-step-\(ts)", title: manualTitle, detail: manualNote.isEmpty ? "手动实验" : manualNote, durationMinutes: nil, isCarryOver: false)
                ]
            )

        case .carryOver:
            return LabRun(
                id: "carryover-\(ts)",
                title: carryOverTitle,
                area: .cell,
                timeLabel: finalTimeLabel,
                status: "顺延占位",
                protocolName: "顺延占位",
                scaledVolumeLabel: "",
                projectID: nil,
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

private struct ExperimentDayDetailView: View {
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

private struct ProjectDaysListView: View {
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

// MARK: - Day Timeline View (vertical, Apple Calendar-style)

private enum TimelineZoom {
    case overview   // full day, compressed
    case focused    // ~6h window centred on current time / first run
}

private struct DayTimelineView: View {
    let targetDay: PlanTargetDay
    let runs: [LabRun]
    let completedStepIDs: Set<String>
    let activeTimers: [ActiveLabTimer]
    let projects: [Project]
    let addAtTime: (String) -> Void
    let startTimer: (LabRun, LabStep?, Int?) -> Void
    let showDataCard: (LabRun) -> Void
    let openBenchMode: (LabRun) -> Void
    let removeRun: (LabRun) -> Void
    let onUpdateRun: (LabRun) -> Void
    let pauseTimer: (ActiveLabTimer) -> Void
    let resumeTimer: (ActiveLabTimer) -> Void
    let stopTimer: (ActiveLabTimer) -> Void

    @State private var zoom: TimelineZoom = .overview
    @State private var showRunDetail: LabRun? = nil
    @State private var showAddSheet = false

    // Hour-row heights — different for each mode
    private var hourH: CGFloat {
        zoom == .overview ? 88 : 240  // overview: 88pt/hr (44pt per 30min), focused: 240pt/hr (4pt per min)
    }

    private var displayHours: [Int] { Array(0...23) }

    // Group hours into segments: consecutive empty hours are collapsed
    private var hourSegments: [(startHour: Int, endHour: Int, hasRuns: Bool)] {
        var segments: [(Int, Int, Bool)] = []
        var currentStart = 0
        var currentHasRuns = !runs.filter { hourFromLabel($0.timeLabel) == 0 }.isEmpty

        for hour in 1...23 {
            let hasRuns = !runs.filter { hourFromLabel($0.timeLabel) == hour }.isEmpty
            if hasRuns != currentHasRuns {
                segments.append((currentStart, hour - 1, currentHasRuns))
                currentStart = hour
                currentHasRuns = hasRuns
            }
        }
        segments.append((currentStart, 23, currentHasRuns))
        return segments
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row - only + button and zoom button
            HStack {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.teal)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        zoom = (zoom == .overview) ? .focused : .overview
                    }
                } label: {
                    Label(zoom == .overview ? "聚焦当前" : "全天览", systemImage: zoom == .overview ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.teal.opacity(0.12), in: Capsule())
                        .foregroundStyle(.teal)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 16)

            // Dynamic timeline layout with collapsed empty segments
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        ForEach(hourSegments, id: \.startHour) { segment in
                            if segment.hasRuns {
                                // Show all hours in this segment
                                ForEach(segment.startHour...segment.endHour, id: \.self) { hour in
                                    DynamicHourBlock(
                                        hour: hour,
                                        runs: runs.filter { hourFromLabel($0.timeLabel) == hour },
                                        zoom: zoom,
                                        targetDay: targetDay,
                                        completedStepIDs: completedStepIDs,
                                        activeTimers: activeTimers,
                                        projects: projects,
                                        onTapRun: { showRunDetail = $0 },
                                        onStart: startTimer,
                                        onCard: showDataCard,
                                        onBench: openBenchMode,
                                        onRemove: { run in
                                            if canRemove(run) { removeRun(run) }
                                        },
                                        onPauseTimer: pauseTimer,
                                        onResumeTimer: resumeTimer,
                                        onStopTimer: stopTimer
                                    )
                                    .id(hour)
                                }
                            } else {
                                // Collapsed empty segment
                                CollapsedEmptySegment(
                                    startHour: segment.startHour,
                                    endHour: segment.endHour
                                )
                                .id(segment.startHour)
                            }
                        }
                    }
                    .padding(.bottom, 20)  // Reduced padding
                }
                .onAppear {
                    // Auto-scroll to first experiment or current hour
                    if let firstRun = runs.first, let h = hourFromLabel(firstRun.timeLabel) {
                        // Scroll to first experiment
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(h, anchor: .top)
                            }
                        }
                    } else if targetDay == .today {
                        // No experiments, scroll to current hour
                        let currentHour = Calendar.current.component(.hour, from: Date())
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(currentHour, anchor: .top)
                            }
                        }
                    }
                }
                .onChange(of: zoom) { _, _ in
                    // Re-scroll when zoom changes
                    if let firstRun = runs.first, let h = hourFromLabel(firstRun.timeLabel) {
                        withAnimation {
                            proxy.scrollTo(h, anchor: .top)
                        }
                    }
                }
            }

            // Empty state hint
            if runs.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.plus").foregroundStyle(.teal)
                    Text("点击左上角 + 添加实验")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
        .onChange(of: showAddSheet) { _, newValue in
            if newValue {
                addAtTime(suggestedTimeForNewRun())
                showAddSheet = false
            }
        }
        .sheet(item: $showRunDetail) { run in
            RunDetailSheet(
                run: run,
                targetDay: targetDay,
                completedStepIDs: completedStepIDs,
                activeTimer: activeTimers.first { $0.runID == run.id },
                projects: projects,
                startTimer: { step, customMin in startTimer(run, step, customMin) },
                showDataCard: { showDataCard(run) },
                openBenchMode: { openBenchMode(run) },
                removeRun: canRemove(run) ? { removeRun(run) } : nil,
                updateRun: { updatedRun in
                    onUpdateRun(updatedRun)
                    showRunDetail = nil
                },
                pauseTimer: { pauseTimer($0) },
                resumeTimer: { resumeTimer($0) },
                stopTimer: { stopTimer($0) }
            )
        }
    }

    private func suggestedTimeForNewRun() -> String {
        if targetDay == .today {
            let now = Date()
            let cal = Calendar.current
            let h = cal.component(.hour, from: now)
            let m = cal.component(.minute, from: now)
            let rounded = ((m + 14) / 15) * 15
            if rounded >= 60 {
                return String(format: "%02d:00", min(h + 1, 23))
            }
            return String(format: "%02d:%02d", h, rounded)
        }
        return "09:00"
    }

    private func canRemove(_ run: LabRun) -> Bool {
        run.id.hasPrefix("import-") || run.id.hasPrefix("manual-") || run.id.hasPrefix("carryover-")
    }

    private func hourFromLabel(_ label: String) -> Int? {
        let parts = label.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]) else { return nil }
        return h
    }

    private func minuteFromLabel(_ label: String) -> Int {
        let parts = label.split(separator: ":")
        guard parts.count == 2, let m = Int(parts[1]) else { return 0 }
        return m
    }

    private func roundToNearest15(_ label: String) -> String {
        let parts = label.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return label }
        let rounded = (m / 15) * 15
        return String(format: "%02d:%02d", h, rounded)
    }
}

private struct HourRow: View {
    let hour: Int
    let hourH: CGFloat
    let isCurrentHour: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Hour label
            Text(String(format: "%02d:00", hour))
                .font(.system(size: 11, weight: isCurrentHour ? .bold : .regular, design: .monospaced))
                .foregroundStyle(isCurrentHour ? Color.teal : Color.secondary.opacity(0.7))
                .frame(width: 48, alignment: .trailing)
                .offset(y: -7)

            // Tick line
            Rectangle()
                .fill(isCurrentHour ? Color.teal.opacity(0.35) : Color.secondary.opacity(0.12))
                .frame(height: 1)
                .padding(.leading, 56)
                .offset(y: 0)

            // Half-hour sub-tick
            if hourH >= 40 {
                Rectangle()
                    .fill(Color.secondary.opacity(0.07))
                    .frame(height: 1)
                    .padding(.leading, 56)
                    .offset(y: hourH / 2)
            }
        }
        .frame(height: hourH)
    }
}

private struct CurrentTimeIndicator: View {
    let displayHours: [Int]
    let hourH: CGFloat

    private var nowFraction: CGFloat {
        let cal = Calendar.current
        let h = cal.component(.hour, from: Date())
        let m = cal.component(.minute, from: Date())
        guard let firstH = displayHours.first, displayHours.contains(h) else { return -1 }
        return CGFloat(h - firstH) * hourH + CGFloat(m) / 60.0 * hourH
    }

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { _ in
            let y = nowFraction
            if y >= 0 {
                HStack(spacing: 0) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .padding(.leading, 52)
                    Rectangle()
                        .fill(Color.red.opacity(0.7))
                        .frame(height: 1.5)
                }
                .offset(y: y)
            }
        }
    }
}

private struct RunChip: View {
    let run: LabRun
    let completedStepIDs: Set<String>
    let activeTimer: ActiveLabTimer?
    let projects: [Project]
    let onTap: () -> Void
    let onStart: () -> Void
    let onCard: () -> Void
    let onRemove: (() -> Void)?

    private var projectName: String? {
        guard let pid = run.projectID else { return nil }
        return projects.first { $0.id == pid }?.name
    }
    private var projectColor: Color? {
        guard let pid = run.projectID, let hex = projects.first(where: { $0.id == pid })?.colorHex else { return nil }
        return Color(hex: hex)
    }

    private var doneCount: Int { run.steps.filter { completedStepIDs.contains($0.id) }.count }
    private var chipColor: Color {
        switch run.area {
        case .cell: return .teal
        case .cloning: return .blue
        case .blot: return .purple
        default: return .gray
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(chipColor)
                    .frame(width: 3)
                    .frame(height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(run.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text("\(run.timeLabel) · \(doneCount)/\(run.steps.count)步").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(run.area.rawValue)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(chipColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(chipColor)
                    if let name = projectName, let color = projectColor {
                        Text(name)
                            .font(.caption2)
                            .foregroundStyle(color)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(chipColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Expanded Run Card (for focused mode)

private struct ExpandedRunCard: View {
    let run: LabRun
    let completedStepIDs: Set<String>
    let activeTimer: ActiveLabTimer?
    let projects: [Project]
    let onTap: () -> Void
    let onStart: (LabStep?) -> Void
    let onCard: () -> Void
    let onBench: () -> Void
    let onRemove: (() -> Void)?
    let onPause: (() -> Void)?
    let onResume: (() -> Void)?
    let onStop: (() -> Void)?

    private var projectName: String? {
        guard let pid = run.projectID else { return nil }
        return projects.first { $0.id == pid }?.name
    }
    private var projectColor: Color? {
        guard let pid = run.projectID, let hex = projects.first(where: { $0.id == pid })?.colorHex else { return nil }
        return Color(hex: hex)
    }

    private var doneCount: Int { run.steps.filter { completedStepIDs.contains($0.id) }.count }
    private var chipColor: Color {
        switch run.area {
        case .cell: return .teal
        case .cloning: return .blue
        case .blot: return .purple
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header - title tappable only
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(chipColor)
                    .frame(width: 4, height: 44)
                Button(action: onTap) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(run.title).font(.headline).lineLimit(1)
                        HStack(spacing: 4) {
                            Text(run.timeLabel).font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(chipColor)
                            Text("·").foregroundStyle(.secondary)
                            Text(run.protocolName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(run.area.rawValue)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(chipColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(chipColor)
                    if let name = projectName, let color = projectColor {
                        Text(name)
                            .font(.caption2)
                            .foregroundStyle(color)
                            .lineLimit(1)
                    }
                }
            }

            // Steps list
            VStack(spacing: 6) {
                ForEach(run.steps) { step in
                    HStack(spacing: 8) {
                        Image(systemName: completedStepIDs.contains(step.id) ? "checkmark.circle.fill" : "circle")
                            .font(.body)
                            .foregroundStyle(completedStepIDs.contains(step.id) ? chipColor : .secondary.opacity(0.5))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.body.weight(.medium))
                                .strikethrough(completedStepIDs.contains(step.id))
                            Text(step.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        if let dur = step.durationMinutes {
                            Button {
                                onStart(step)
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "timer").font(.caption2)
                                    Text("\(dur)m").font(.caption.weight(.semibold))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.12), in: Capsule())
                                .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Timer display
            if let timer = activeTimer {
                TimelineView(.periodic(from: Date(), by: 1)) { _ in
                    HStack {
                        Image(systemName: timer.isPaused ? "pause.circle.fill" : (timer.isFinished ? "bell.fill" : "timer"))
                            .foregroundStyle(timer.isPaused ? .orange : (timer.isFinished ? .orange : chipColor))
                        Text(timer.stepTitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        if timer.isPaused {
                            Text("已暂停")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.orange)
                        } else {
                            Text(timer.isFinished ? "到点" : formatDuration(timer.remainingSeconds))
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(timer.isFinished ? .orange : chipColor)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        timer.isPaused ? Color.orange.opacity(0.12) :
                        (timer.isFinished ? Color.orange.opacity(0.12) : chipColor.opacity(0.08)),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }
                // Pause/Resume/Stop mini controls
                if !timer.isFinished {
                    HStack(spacing: 8) {
                        if timer.isPaused {
                            Button(action: { onResume?() }) {
                                Label("继续", systemImage: "play.fill")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.mini)
                            .tint(chipColor)
                        } else {
                            Button(action: { onPause?() }) {
                                Label("暂停", systemImage: "pause.fill")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .tint(chipColor)
                        }
                        Button(action: { onStop?() }) {
                            Label("取消", systemImage: "stop.fill")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .tint(.red)
                    }
                }
            }
        }
        .padding(12)
        .background(chipColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(chipColor.opacity(0.2), lineWidth: 1.5))
        .contextMenu {
            if let remove = onRemove {
                Button(role: .destructive, action: remove) {
                    Label("删除实验", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Run Detail Sheet (from timeline chip tap)

private struct RunDetailSheet: View {
    let run: LabRun
    let targetDay: PlanTargetDay
    let completedStepIDs: Set<String>
    let activeTimer: ActiveLabTimer?
    let projects: [Project]
    let startTimer: (LabStep?, Int?) -> Void  // (step, customMinutes)
    let showDataCard: () -> Void
    let openBenchMode: () -> Void
    let removeRun: (() -> Void)?
    let updateRun: ((LabRun) -> Void)?
    let pauseTimer: ((ActiveLabTimer) -> Void)?
    let resumeTimer: ((ActiveLabTimer) -> Void)?
    let stopTimer: ((ActiveLabTimer) -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var editedTitle = ""
    @State private var selectedProjectID: String? = nil
    @State private var selectedHour = 9
    @State private var selectedMinute = 0
    @State private var editableSteps: [LabStep] = []
    @State private var editingStep: LabStep?
    @State private var showCustomTimer = false
    @State private var pendingStep: LabStep?
    @State private var customHours = 0
    @State private var customMins = 5
    @State private var customSecs = 0
    @State private var showingTimePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Info + Time in one row
                    HStack(alignment: .top, spacing: 16) {
                        // Info
                        VStack(alignment: .leading, spacing: 4) {
                            Text("实验信息")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("实验名称", text: $editedTitle)
                                .font(.body.weight(.semibold))
                            if !projects.isEmpty {
                                Picker("项目", selection: $selectedProjectID) {
                                    Text("无项目").tag(nil as String?)
                                    ForEach(projects) { project in
                                        HStack {
                                            Circle()
                                                .fill(Color(hex: project.colorHex))
                                                .frame(width: 8, height: 8)
                                            Text(project.name)
                                        }
                                        .tag(project.id as String?)
                                    }
                                }
                                .font(.subheadline)
                                .pickerStyle(.menu)
                                .tint(.secondary)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
                        .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))

                        // Time
                        VStack(alignment: .leading, spacing: 4) {
                            Text("时间")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Button {
                                let parts = run.timeLabel.split(separator: ":")
                                if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                                    selectedHour = h
                                    selectedMinute = m
                                }
                                showingTimePicker = true
                            } label: {
                                Text(run.timeLabel)
                                    .font(.title2.monospacedDigit().weight(.bold))
                                    .foregroundStyle(.teal)
                            }
                            .buttonStyle(.plain)
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
                        .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
                    }

                    // Steps — centered, large, editable
                    VStack(spacing: 12) {
                        ForEach(Array(editableSteps.enumerated()), id: \.element.id) { index, step in
                            HStack(spacing: 14) {
                                // Step number
                                Text("\(index + 1)")
                                    .font(.title2.monospacedDigit().weight(.bold))
                                    .foregroundStyle(.teal)
                                    .frame(width: 28)

                                // Step content
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(step.title)
                                        .font(.headline)
                                        .strikethrough(completedStepIDs.contains(step.id))
                                    if !step.detail.isEmpty {
                                        Text(highlightedStepDetail(step.detail))
                                            .font(.subheadline)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                // Timer button
                                if let dur = step.durationMinutes {
                                    Button {
                                        pendingStep = step
                                        let totalSecs = dur * 60
                                        customHours = totalSecs / 3600
                                        customMins = (totalSecs % 3600) / 60
                                        customSecs = totalSecs % 60
                                        showCustomTimer = true
                                    } label: {
                                        HStack(spacing: 3) {
                                            Image(systemName: "timer").font(.caption2)
                                            Text("\(dur)m").font(.caption.weight(.semibold))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.12), in: Capsule())
                                        .foregroundStyle(.blue)
                                    }
                                    .buttonStyle(.plain)
                                }

                                // Edit button
                                Button {
                                    editingStep = step
                                } label: {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(14)
                            .background(Color.labInset, in: RoundedRectangle(cornerRadius: 10))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    editableSteps.removeAll { $0.id == step.id }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }

                        // Add step button
                        Button {
                            let newStep = LabStep(
                                id: "step-\(UUID().uuidString)",
                                title: "新步骤",
                                detail: "",
                                durationMinutes: nil,
                                isCarryOver: false,
                                variableRefs: [],
                                reagents: []
                            )
                            editableSteps.append(newStep)
                            editingStep = newStep
                        } label: {
                            Label("添加步骤", systemImage: "plus.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.teal)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    // Active timer
                    if let timer = activeTimer {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("运行中的计时器")
                                .font(.headline)
                            TimelineView(.periodic(from: Date(), by: 1)) { _ in
                                VStack(spacing: 10) {
                                    HStack {
                                        Image(systemName: "timer")
                                            .foregroundStyle(timer.isFinished ? .orange : .teal)
                                        Text(timer.stepTitle).font(.caption).foregroundStyle(.secondary)
                                        Spacer()
                                        if timer.isPaused {
                                            Text("已暂停")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.orange)
                                        }
                                        Text(timer.isFinished ? "到点" : formatDuration(timer.remainingSeconds))
                                            .font(.title3.monospacedDigit().weight(.bold))
                                            .foregroundStyle(timer.isFinished ? .orange : timer.isPaused ? .orange : .teal)
                                    }
                                    HStack(spacing: 12) {
                                        if timer.isPaused {
                                            Button { resumeTimer?(timer) } label: {
                                                Label("继续", systemImage: "play.fill").frame(maxWidth: .infinity)
                                            }
                                            .buttonStyle(.borderedProminent).tint(.teal)
                                        } else if !timer.isFinished {
                                            Button { pauseTimer?(timer) } label: {
                                                Label("暂停", systemImage: "pause.fill").frame(maxWidth: .infinity)
                                            }
                                            .buttonStyle(.bordered).tint(.teal)
                                        }
                                        Button { stopTimer?(timer) } label: {
                                            Label("取消", systemImage: "stop.fill").frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.bordered).tint(.red)
                                    }
                                }
                                .padding(12)
                                .background(timer.isFinished ? Color.orange.opacity(0.12) : timer.isPaused ? Color.orange.opacity(0.08) : Color.labInset, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(16)
                        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(16)
            }
            .background(Color.labBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(editedTitle.isEmpty ? run.title : editedTitle)
                        .font(.headline)
                        .lineLimit(1)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("保存") {
                        let trimmedTitle = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        let updatedRun = LabRun(
                            id: run.id,
                            title: trimmedTitle.isEmpty ? run.title : trimmedTitle,
                            area: run.area,
                            timeLabel: String(format: "%02d:%02d", selectedHour, selectedMinute),
                            status: run.status,
                            protocolName: run.protocolName,
                            scaledVolumeLabel: run.scaledVolumeLabel,
                            projectID: selectedProjectID,
                            steps: editableSteps
                        )
                        updateRun?(updatedRun)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showDataCard()
                        dismiss()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingTimePicker) {
                TimePickerSheet(
                    hour: $selectedHour,
                    minute: $selectedMinute,
                    onApply: {
                        showingTimePicker = false
                    }
                )
            }
            .sheet(item: $editingStep) { step in
                StepEditorSheet(
                    step: step,
                    onSave: { updated in
                        if let idx = editableSteps.firstIndex(where: { $0.id == updated.id }) {
                            editableSteps[idx] = updated
                        }
                    }
                )
            }
            .sheet(isPresented: $showCustomTimer) {
                CustomTimerSheet(
                    hours: $customHours,
                    mins: $customMins,
                    secs: $customSecs,
                    onStart: {
                        let totalMins = customHours * 60 + customMins + (customSecs >= 30 ? 1 : 0)
                        startTimer(pendingStep, max(totalMins, 1))
                        showCustomTimer = false
                    }
                )
            }
        }
        .onAppear {
            editedTitle = run.title
            selectedProjectID = run.projectID
            editableSteps = run.steps
            let parts = run.timeLabel.split(separator: ":")
            if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                selectedHour = h
                selectedMinute = m
            }
        }
    }

    private func highlightedStepDetail(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = .secondary

        // Pattern: number + optional space + unit
        // Matches: "1 次", "37 C", "4 ml", "5%", "10 min", etc.
        let pattern = #"(\d+\.?\d*)\s*([A-Za-z°µμ%次]+)"#

        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                if let range = Range(match.range, in: text) {
                    if let attrRange = Range(range, in: attributed) {
                        attributed[attrRange].foregroundColor = .teal
                        attributed[attrRange].font = .subheadline.weight(.semibold).monospacedDigit()
                    }
                }
            }
        }

        return attributed
    }
}

// MARK: - Custom Timer Sheet

private struct CustomTimerSheet: View {
    @Binding var hours: Int
    @Binding var mins: Int
    @Binding var secs: Int
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("自定义计时时长")
                    .font(.headline)

                HStack(spacing: 0) {
                    Picker("时", selection: $hours) {
                        ForEach(0..<24) { h in
                            Text("\(h)").tag(h)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60)

                    Text("时")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

                    Picker("分", selection: $mins) {
                        ForEach(0..<60) { m in
                            Text("\(m)").tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60)

                    Text("分")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

                    Picker("秒", selection: $secs) {
                        ForEach(0..<60) { s in
                            Text("\(s)").tag(s)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60)

                    Text("秒")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                }
                .frame(height: 160)

                Button {
                    onStart()
                    dismiss()
                } label: {
                    Label("开始计时", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.teal)
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}

// MARK: - Time Picker Sheet

private struct TimePickerSheet: View {
    @Binding var hour: Int
    @Binding var minute: Int
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                HStack(spacing: 0) {
                    Picker("时", selection: $hour) {
                        ForEach(0..<24) { h in Text(String(format: "%02d", h)).tag(h) }
                    }
                    .pickerStyle(.wheel).frame(width: 80)
                    Text(":").font(.title2.bold())
                    Picker("分", selection: $minute) {
                        ForEach([0, 15, 30, 45], id: \.self) { m in Text(String(format: "%02d", m)).tag(m) }
                    }
                    .pickerStyle(.wheel).frame(width: 80)
                }
                .frame(height: 180)

                Button {
                    onApply()
                    dismiss()
                } label: {
                    Text("应用").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(.teal).padding(.horizontal)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
        .presentationDetents([.height(280)])
    }
}

// MARK: - Step Editor Sheet

private struct StepEditorSheet: View {
    let step: LabStep
    let onSave: (LabStep) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var detail: String
    @State private var durationMinutes: Int?
    @State private var hasDuration: Bool
    @State private var durValue = 5

    init(step: LabStep, onSave: @escaping (LabStep) -> Void) {
        self.step = step
        self.onSave = onSave
        _title = State(initialValue: step.title)
        _detail = State(initialValue: step.detail)
        _durationMinutes = State(initialValue: step.durationMinutes)
        _hasDuration = State(initialValue: step.durationMinutes != nil)
        if let d = step.durationMinutes { _durValue = State(initialValue: d) }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("步骤名称", text: $title)
                TextField("详细说明（可选）", text: $detail)
                Toggle("需要计时", isOn: $hasDuration)
                if hasDuration {
                    HStack {
                        Text("时长（分钟）")
                        Spacer()
                        TextField("分钟", value: $durValue, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle("编辑步骤")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var updated = step
                        updated.title = title
                        updated.detail = detail
                        updated.durationMinutes = hasDuration ? durValue : nil
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
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

// MARK: - Bench Mode (Electronic Protocol Display)

private enum BenchLayoutMode {
    case full
    case compact
}

private struct BenchModeView: View {
    let run: LabRun
    let completedStepIDs: Set<String>
    let activeTimer: ActiveLabTimer?
    let toggleStep: (String) -> Void
    let completeRun: () -> Void
    let startTimer: (Int?) -> Void  // customMinutes
    let pauseTimer: () -> Void
    let resumeTimer: () -> Void
    let stopTimer: () -> Void
    let showDataCard: () -> Void
    @Environment(\.dismiss) private var dismiss

    @AppStorage("preferencesLargeBenchMode") private var largeBenchMode = true
    @AppStorage("preferencesCompactCards") private var compactCards = false
    @AppStorage("preferencesFontScale") private var fontScale = 1.0

    @State private var stepIndex: Int
    @State private var showingCompleteAlert = false
    @State private var showTimerFlash = false
    @State private var flashOpacity = 0.8
    @State private var layoutMode: BenchLayoutMode
    @State private var showCustomTimer = false
    @State private var customHours = 0
    @State private var customMins = 5
    @State private var customSecs = 0

    init(run: LabRun, completedStepIDs: Set<String>, activeTimer: ActiveLabTimer?, toggleStep: @escaping (String) -> Void, completeRun: @escaping () -> Void, startTimer: @escaping (Int?) -> Void, pauseTimer: @escaping () -> Void, resumeTimer: @escaping () -> Void, stopTimer: @escaping () -> Void, showDataCard: @escaping () -> Void) {
        self.run = run
        self.completedStepIDs = completedStepIDs
        self.activeTimer = activeTimer
        self.toggleStep = toggleStep
        self.completeRun = completeRun
        self.startTimer = startTimer
        self.pauseTimer = pauseTimer
        self.resumeTimer = resumeTimer
        self.stopTimer = stopTimer
        self.showDataCard = showDataCard
        let firstIncomplete = run.steps.firstIndex { !completedStepIDs.contains($0.id) } ?? (run.steps.count - 1)
        _stepIndex = State(initialValue: firstIncomplete)
        let prefCompact = UserDefaults.standard.bool(forKey: "preferencesCompactCards")
        _layoutMode = State(initialValue: prefCompact ? .compact : .full)
    }

    private var steps: [LabStep] { run.steps }
    private var currentStep: LabStep { steps[safe: stepIndex] ?? steps[steps.count - 1] }
    private var isCurrentStepDone: Bool { completedStepIDs.contains(currentStep.id) }
    private var doneCount: Int { run.steps.filter { completedStepIDs.contains($0.id) }.count }
    private var isRunComplete: Bool { doneCount == steps.count }
    private var chipColor: Color {
        switch run.area {
        case .cell: return .teal
        case .cloning: return .blue
        case .blot: return .purple
        default: return .gray
        }
    }

    var body: some View {
        ZStack {
            Color.labBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                benchModeHeader

                Group {
                    if layoutMode == .full {
                        VStack(spacing: 0) {
                            Spacer()

                        // MARK: - Step Number
                        Text("步骤 \(stepIndex + 1)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(chipColor)
                            .padding(.bottom, 4)

                        // MARK: - Step Title (hero)
                        Text(currentStep.title)
                            .font(.system(size: 42, weight: .bold))
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)

                        // MARK: - Step Detail
                        Text(currentStep.detail)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 16)

                        // MARK: - Reagents Panel (full mode)
                        if !currentStep.reagents.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("本步试剂")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(currentStep.reagents) { reagent in
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(chipColor.opacity(0.35))
                                            .frame(width: 5, height: 5)
                                        Text(reagent.name)
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        reagentAmountView(reagent)
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(chipColor.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(chipColor.opacity(0.08), lineWidth: 1))
                            .padding(.horizontal, 32)
                            .padding(.bottom, 12)
                        }

                        // MARK: - Timer Display
                        if let dur = currentStep.durationMinutes {
                            if let timer = activeTimer, timer.stepTitle == currentStep.title {
                                VStack(spacing: 16) {
                                    if timer.isPaused {
                                        VStack(spacing: 4) {
                                            Text(formatDuration(timer.remainingSeconds))
                                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                                .foregroundStyle(.orange)
                                            Text("已暂停")
                                                .font(.caption)
                                                .foregroundStyle(.orange.opacity(0.6))
                                        }
                                    } else {
                                        CircularTimerView(
                                            totalSeconds: dur * 60,
                                            endsAt: timer.endsAt
                                        )
                                    }

                                    HStack(spacing: 16) {
                                        if timer.isPaused {
                                            Button { resumeTimer() } label: {
                                                Label("继续", systemImage: "play.fill")
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(chipColor)
                                        } else {
                                            Button { pauseTimer() } label: {
                                                Label("暂停", systemImage: "pause.fill")
                                            }
                                            .buttonStyle(.bordered)
                                            .tint(chipColor)
                                        }

                                        Button { stopTimer() } label: {
                                            Label("取消", systemImage: "stop.fill")
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.red)
                                    }
                                }
                                .padding(.bottom, 12)
                            } else if !isCurrentStepDone {
                                Button {
                                    if let dur = currentStep.durationMinutes {
                                        let totalSecs = dur * 60
                                        customHours = totalSecs / 3600
                                        customMins = (totalSecs % 3600) / 60
                                        customSecs = totalSecs % 60
                                    } else {
                                        customHours = 0
                                        customMins = 5
                                        customSecs = 0
                                    }
                                    showCustomTimer = true
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "play.fill")
                                        Text("启动计时 \(dur) min")
                                    }
                                    .font(.title3.weight(.semibold))
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 14)
                                    .background(chipColor, in: Capsule())
                                    .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)
                                .padding(.bottom, 12)
                            }
                        }

                        Spacer()

                        // MARK: - Step Indicator Dots
                        HStack(spacing: 10) {
                            ForEach(Array(steps.enumerated()), id: \.element.id) { idx, step in
                                Button {
                                    withAnimation(.spring(response: 0.35)) {
                                        stepIndex = idx
                                    }
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                idx == stepIndex ? chipColor :
                                                completedStepIDs.contains(step.id) ? chipColor.opacity(0.35) :
                                                Color.secondary.opacity(0.2)
                                            )
                                            .frame(width: idx == stepIndex ? 36 : 28, height: idx == stepIndex ? 36 : 28)
                                            .animation(.spring(response: 0.35), value: stepIndex)

                                        if completedStepIDs.contains(step.id) {
                                            Image(systemName: "checkmark")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(.white)
                                        } else if idx == stepIndex {
                                            Text("\(idx + 1)")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(idx > doneCount)
                            }
                        }
                        .padding(.bottom, 24)

                        // MARK: - Gesture hints
                        HStack(spacing: 24) {
                            Image(systemName: "chevron.left")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(stepIndex > 0 ? chipColor : .secondary.opacity(0.2))
                                .onTapGesture {
                                    if stepIndex > 0 {
                                        withAnimation(.spring(response: 0.35)) { stepIndex -= 1 }
                                    }
                                }

                            Button {
                                if isRunComplete {
                                    showingCompleteAlert = true
                                } else {
                                    if !isCurrentStepDone {
                                        toggleStep(currentStep.id)
                                    }
                                    let nextIdx = steps.firstIndex { !completedStepIDs.contains($0.id) }
                                    if let next = nextIdx {
                                        withAnimation(.spring(response: 0.35)) {
                                            stepIndex = next
                                        }
                                    } else if doneCount + 1 >= steps.count {
                                        showingCompleteAlert = true
                                    }
                                }
                            } label: {
                                Label(
                                    isRunComplete ? "完成实验" : "完成此步骤",
                                    systemImage: isRunComplete ? "checkmark.seal.fill" : "checkmark.circle.fill"
                                )
                                .font(.title3.weight(.bold))
                                .frame(maxWidth: .infinity, minHeight: 58)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(isRunComplete ? .teal : chipColor)

                            Image(systemName: "chevron.right")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(stepIndex < steps.count - 1 ? chipColor : .secondary.opacity(0.2))
                                .onTapGesture {
                                    if stepIndex < steps.count - 1 {
                                        withAnimation(.spring(response: 0.35)) { stepIndex += 1 }
                                    }
                                }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                        if !isRunComplete && doneCount > 0 && stepIndex > doneCount {
                            Button {
                                withAnimation(.spring(response: 0.35)) {
                                    stepIndex = doneCount
                                }
                            } label: {
                                Label("回到当前步骤", systemImage: "arrow.uturn.backward")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 6)
                        }
                        }
                    } else {
                        compactModeLayout
                    }
                }
            }
            .padding(.bottom, 20)

            // Timer finished flash overlay
            if showTimerFlash {
                Color.white
                    .ignoresSafeArea()
                    .opacity(flashOpacity)
                    .allowsHitTesting(false)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.3)) { flashOpacity = 0 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showTimerFlash = false
                            flashOpacity = 0.8
                        }
                    }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -80, stepIndex < steps.count - 1 {
                        withAnimation(.spring(response: 0.35)) { stepIndex += 1 }
                    } else if value.translation.width > 80, stepIndex > 0 {
                        withAnimation(.spring(response: 0.35)) { stepIndex -= 1 }
                    }
                }
        )
        .onChange(of: activeTimer?.isFinished ?? false) { _, isFinished in
            if isFinished {
                showTimerFlash = true
                flashOpacity = 0.8
            }
        }
        .sheet(isPresented: $showCustomTimer) {
            CustomTimerSheet(
                hours: $customHours,
                mins: $customMins,
                secs: $customSecs,
                onStart: {
                    let totalMins = customHours * 60 + customMins + (customSecs >= 30 ? 1 : 0)
                    startTimer(max(totalMins, 1))
                    showCustomTimer = false
                }
            )
        }
        .alert("实验完成", isPresented: $showingCompleteAlert) {
            Button("生成结果卡片") { completeRun() }
            Button("稍后处理", role: .cancel) { dismiss() }
        } message: {
            Text("所有步骤已完成，是否生成结果卡片？")
        }
    }

    private var benchModeHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(run.title)
                        .font(.title3.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .truncationMode(.tail)
                    Text("\(run.area.rawValue) · \(run.timeLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                HStack(spacing: 12) {
                    Button {
                        layoutMode = layoutMode == .full ? .compact : .full
                        compactCards = layoutMode == .compact
                    } label: {
                        Image(systemName: layoutMode == .full ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(chipColor)
                            .frame(width: 44, height: 44)
                            .background(chipColor.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)

                    Button(action: showDataCard) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(chipColor)
                            .frame(width: 44, height: 44)
                            .background(chipColor.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)

                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .transaction { transaction in
                transaction.animation = nil
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 4)
                    Capsule()
                        .fill(chipColor)
                        .frame(width: max(4, geo.size.width * CGFloat(doneCount) / CGFloat(max(1, steps.count))), height: 4)
                        .animation(.spring(response: 0.4), value: doneCount)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Reagent Amount View
    private func reagentAmountView(_ reagent: StepReagent) -> some View {
        let amount = reagent.calculateAmount(variables: [:])
        if let val = amount {
            return AnyView(
                Text("\(formatCalcAmount(val)) \(reagent.unit)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(chipColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(chipColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
            )
        } else {
            return AnyView(
                Text("\(reagent.amountExpression) \(reagent.unit)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(chipColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(chipColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
            )
        }
    }

    // MARK: - Compact Mode Layout
    private var compactModeLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Timer Dashboard
                if let timer = activeTimer {
                    compactTimerDashboard(timer)
                } else if let dur = currentStep.durationMinutes, !isCurrentStepDone {
                    Button {
                        let totalSecs = dur * 60
                        customHours = totalSecs / 3600
                        customMins = (totalSecs % 3600) / 60
                        customSecs = totalSecs % 60
                        showCustomTimer = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                            Text("启动计时 \(dur) min — \(currentStep.title)")
                        }
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(chipColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }

                // Step list
                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { idx, step in
                        compactStepRow(idx: idx, step: step)
                        if idx < steps.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(chipColor.opacity(0.12), lineWidth: 1))

                // Bottom action
                HStack(spacing: 16) {
                    // Step nav
                    Button {
                        if stepIndex > 0 {
                            withAnimation(.spring(response: 0.35)) { stepIndex -= 1 }
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(stepIndex > 0 ? chipColor : .secondary)
                    .disabled(stepIndex == 0)

                    Button {
                        if isRunComplete {
                            showingCompleteAlert = true
                        } else {
                            if !isCurrentStepDone {
                                toggleStep(currentStep.id)
                            }
                            let nextIdx = steps.firstIndex { !completedStepIDs.contains($0.id) }
                            if let next = nextIdx {
                                withAnimation(.spring(response: 0.35)) { stepIndex = next }
                            } else {
                                if doneCount + 1 >= steps.count {
                                    showingCompleteAlert = true
                                }
                            }
                        }
                    } label: {
                        Label(
                            isRunComplete ? "完成实验" : "完成此步骤",
                            systemImage: isRunComplete ? "checkmark.seal.fill" : "checkmark.circle.fill"
                        )
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isRunComplete ? .teal : chipColor)

                    Button {
                        if stepIndex < steps.count - 1 {
                            withAnimation(.spring(response: 0.35)) { stepIndex += 1 }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title2.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(stepIndex < steps.count - 1 ? chipColor : .secondary)
                    .disabled(stepIndex >= steps.count - 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Compact Timer Dashboard
    private func compactTimerDashboard(_ timer: ActiveLabTimer) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: timer.isPaused ? "pause.circle.fill" : (timer.isFinished ? "bell.fill" : "timer"))
                    .font(.title2)
                    .foregroundStyle(timer.isPaused || timer.isFinished ? .orange : chipColor)
                Text(timer.stepTitle)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if timer.isPaused {
                    Text("已暂停")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.orange)
                } else if timer.isFinished {
                    Text("到点")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.orange)
                } else {
                    TimelineView(.periodic(from: Date(), by: 1)) { _ in
                        Text(formatDuration(timer.remainingSeconds))
                            .font(.title.monospacedDigit().weight(.bold))
                            .foregroundStyle(chipColor)
                    }
                }
            }

            if !timer.isFinished {
                HStack(spacing: 12) {
                    if timer.isPaused {
                        Button { resumeTimer() } label: {
                            Label("继续", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(chipColor)
                    } else {
                        Button { pauseTimer() } label: {
                            Label("暂停", systemImage: "pause.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(chipColor)
                    }
                    Button { stopTimer() } label: {
                        Label("取消", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
        }
        .padding(14)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(chipColor.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Compact Step Row
    private func compactStepRow(idx: Int, step: LabStep) -> some View {
        let isDone = completedStepIDs.contains(step.id)
        let isCurrent = idx == stepIndex
        let hasActiveTimer = activeTimer?.stepTitle == step.title && !(activeTimer?.isFinished ?? true)

        return Button {
            withAnimation(.spring(response: 0.35)) { stepIndex = idx }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 10) {
                    // Status icon
                    ZStack {
                        Circle()
                            .fill(
                                isCurrent ? chipColor :
                                isDone ? chipColor.opacity(0.25) :
                                Color.secondary.opacity(0.12)
                            )
                            .frame(width: isCurrent ? 34 : 30, height: isCurrent ? 34 : 30)
                        if isDone {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(idx + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(isCurrent ? .white : .secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.title)
                            .font(isCurrent ? .title3.weight(.bold) : .body.weight(.medium))
                            .strikethrough(isDone)
                            .foregroundStyle(isCurrent ? .primary : (isDone ? .secondary : .secondary))
                        Text(step.detail)
                            .font(isCurrent ? .body : .subheadline)
                            .foregroundStyle(isCurrent ? Color.secondary : Color.secondary.opacity(0.75))
                            .lineLimit(isCurrent ? nil : 2)
                            .fixedSize(horizontal: false, vertical: isCurrent)
                    }
                    Spacer()
                    if let dur = step.durationMinutes {
                        if hasActiveTimer {
                            TimelineView(.periodic(from: Date(), by: 1)) { _ in
                                Text(formatDuration(activeTimer?.remainingSeconds ?? dur * 60))
                                    .font(.caption.monospacedDigit().weight(.bold))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.12), in: Capsule())
                            }
                        } else {
                            Label("\(dur)m", systemImage: "timer")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isCurrent ? .blue : .blue.opacity(0.6))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(isCurrent ? 0.1 : 0.06), in: Capsule())
                        }
                    }
                }

                // Reagents
                if isCurrent && !step.reagents.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(step.reagents) { reagent in
                            reagentCompactPill(reagent)
                        }
                    }
                    .padding(.leading, 40)
                }
            }
            .padding(12)
            .background(
                isCurrent
                    ? chipColor.opacity(0.06)
                    : Color.clear
            )
            .overlay(alignment: .leading) {
                if isCurrent {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(chipColor)
                        .frame(width: 4)
                        .padding(.vertical, 8)
                        .padding(.leading, 2)
                }
            }
            .opacity(isCurrent ? 1 : 0.55)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Compact Reagent Pill
    private func reagentCompactPill(_ reagent: StepReagent) -> some View {
        let amount = reagent.calculateAmount(variables: [:])
        return AnyView(
            HStack(spacing: 2) {
                Text(reagent.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let val = amount {
                    Text("\(formatCalcAmount(val))\(reagent.unit)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(chipColor)
                } else {
                    Text("\(reagent.amountExpression)\(reagent.unit)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(chipColor)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(chipColor.opacity(0.08), in: Capsule())
        )
    }

    private func formatCalcAmount(_ value: Double) -> String {
        if value >= 100 { return String(format: "%.0f", value) }
        if value >= 10 { return String(format: "%.1f", value) }
        return String(format: "%.2f", value)
    }
}

// MARK: - Circular Timer View

private struct CircularTimerView: View {
    let totalSeconds: Int
    let endsAt: Date

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { _ in
            let remaining = max(0, Int(endsAt.timeIntervalSinceNow.rounded()))
            let isFinished = remaining == 0
            let progress = totalSeconds > 0 ? Double(remaining) / Double(totalSeconds) : 0.0

            VStack(spacing: 12) {
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 12)
                        .frame(width: 140, height: 140)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: min(1, progress))
                        .stroke(
                            isFinished ? Color.orange : Color.teal,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))

                    // Time text
                    Text(isFinished ? "完成" : formatDuration(remaining))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(isFinished ? .orange : .teal)
                        .contentTransition(.numericText())
                }
            }
        }
    }
}

// MARK: - Collapsed Empty Segment

private struct CollapsedEmptySegment: View {
    let startHour: Int
    let endHour: Int

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Text(String(format: "%02d:00", startHour))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .frame(width: 48, alignment: .trailing)

                Rectangle()
                    .fill(Color.secondary.opacity(0.08))
                    .frame(height: 1)

                Text(String(format: "%02d:00", endHour))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 8)

            Text("· · ·")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.3))
        }
        .frame(height: 32)
        .padding(.vertical, 4)
    }
}

// MARK: - Dynamic Hour Block

private struct DynamicHourBlock: View {
    let hour: Int
    let runs: [LabRun]
    let zoom: TimelineZoom
    let targetDay: PlanTargetDay
    let completedStepIDs: Set<String>
    let activeTimers: [ActiveLabTimer]
    let projects: [Project]
    let onTapRun: (LabRun) -> Void
    let onStart: (LabRun, LabStep?, Int?) -> Void
    let onCard: (LabRun) -> Void
    let onBench: (LabRun) -> Void
    let onRemove: (LabRun) -> Void
    let onPauseTimer: ((ActiveLabTimer) -> Void)?
    let onResumeTimer: ((ActiveLabTimer) -> Void)?
    let onStopTimer: ((ActiveLabTimer) -> Void)?

    private var isCurrentHour: Bool {
        targetDay == .today && Calendar.current.component(.hour, from: Date()) == hour
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hour label
            HStack(spacing: 0) {
                Text(String(format: "%02d:00", hour))
                    .font(.system(size: 11, weight: isCurrentHour ? .bold : .regular, design: .monospaced))
                    .foregroundStyle(isCurrentHour ? Color.teal : Color.secondary.opacity(0.7))
                    .frame(width: 48, alignment: .trailing)

                Rectangle()
                    .fill(isCurrentHour ? Color.teal.opacity(0.35) : Color.secondary.opacity(0.12))
                    .frame(height: 1)
                    .padding(.leading, 8)
            }

            // Experiment content area
            if runs.isEmpty {
                // Empty space - minimal
                Color.clear
                    .frame(height: zoom == .overview ? 24 : 32)
            } else {
                // Has experiments - dynamic layout
                VStack(spacing: zoom == .overview ? 8 : 12) {
                    ForEach(runs.sorted(by: { minuteFrom($0.timeLabel) < minuteFrom($1.timeLabel) })) { run in
                        HStack(spacing: 0) {
                            // Time indicator for this run
                            Text(run.timeLabel)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary.opacity(0.6))
                                .frame(width: 48, alignment: .trailing)

                            // Run card
                            if zoom == .overview {
                                RunChip(
                                    run: run,
                                    completedStepIDs: completedStepIDs,
                                    activeTimer: activeTimers.first { $0.runID == run.id },
                                    projects: projects,
                                    onTap: { onTapRun(run) },
                                    onStart: { onStart(run, nil, nil) },
                                    onCard: { onCard(run) },
                                    onRemove: { onRemove(run) }
                                )
                                .padding(.leading, 8)
                            } else {
                                let timerForRun = activeTimers.first { $0.runID == run.id }
                                ExpandedRunCard(
                                    run: run,
                                    completedStepIDs: completedStepIDs,
                                    activeTimer: timerForRun,
                                    projects: projects,
                                    onTap: { onBench(run) },
                                    onStart: { step in onStart(run, step, nil) },
                                    onCard: { onCard(run) },
                                    onBench: { onBench(run) },
                                    onRemove: { onRemove(run) },
                                    onPause: { if let t = timerForRun { onPauseTimer?(t) } },
                                    onResume: { if let t = timerForRun { onResumeTimer?(t) } },
                                    onStop: { if let t = timerForRun { onStopTimer?(t) } }
                                )
                                .padding(.leading, 8)
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
                .padding(.trailing, 8)
            }

            // Current time indicator (if applicable)
            if targetDay == .today && isCurrentHour {
                CurrentTimeIndicatorInHour()
            }
        }
    }

    private func minuteFrom(_ label: String) -> Int {
        let parts = label.split(separator: ":")
        guard parts.count == 2, let m = Int(parts[1]) else { return 0 }
        return m
    }
}

private struct CurrentTimeIndicatorInHour: View {
    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { _ in
            let minute = Calendar.current.component(.minute, from: Date())
            HStack(spacing: 0) {
                Text(String(format: ":%02d", minute))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red)
                    .frame(width: 48, alignment: .trailing)

                HStack(spacing: 0) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                        .padding(.leading, 5)
                    Rectangle()
                        .fill(Color.red.opacity(0.7))
                        .frame(height: 1.5)
                }
            }
        }
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
