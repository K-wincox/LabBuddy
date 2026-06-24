import SwiftUI

#if os(iOS)
    import UIKit
    import AVFoundation
    import AudioToolbox
#endif

// MARK: - Today View (Phase 4 三段式)

struct TodayView: View {
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
    @AppStorage("preferencesVoiceAnnouncementTemplate") private var voiceAnnouncementTemplate =
        "{实验}，{步骤}已完成"
    @State private var lastNotifiedTimerIDs: Set<String> = []
    @State private var selectedProjectFilter: String? = nil
    @State private var selectedFutureDate =
        Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: Date()) ?? Date()

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

    private var selectedFutureDateKey: String {
        Self.futureDayKey(selectedFutureDate)
    }

    private var selectedFutureDateLabel: String {
        Self.futureDateLabel(selectedFutureDate)
    }

    private var selectedFutureRuns: [LabRun] {
        let fallback = Self.futureDayKey(
            Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: Date()) ?? Date())
        let runs = tomorrowRuns.filter { ($0.planDateKey ?? fallback) == selectedFutureDateKey }
            .sortedByTimeLabel()
        guard let filter = selectedProjectFilter else { return runs }
        return runs.filter { $0.projectID == filter }
    }

    private var selectedRecordDay: ExperimentDayRecord {
        historyDays.first { $0.id == selectedRecordDayID }
            ?? historyDays.first
            ?? ExperimentDayRecord(
                id: "empty", dateLabel: "过去", weekday: "", summary: "还没有记录", runs: [])
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
                                        selectedProjectFilter =
                                            selectedProjectFilter == project.id ? nil : project.id
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
                            projects: projects,
                            projectFilter: selectedProjectFilter
                        )
                        ExperimentDayDetailView(
                            day: selectedRecordDay,
                            completedStepIDs: completedStepIDs,
                            projects: projects,
                            projectFilter: selectedProjectFilter
                        )

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
                                    scheduleRequest = ScheduleRequest(
                                        targetDay: .today, timeLabel: "09:00")
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
                                    scheduleRequest = ScheduleRequest(
                                        targetDay: .today, timeLabel: timeLabel)
                                },
                                startTimer: { run, step, customMin in
                                    startTimer(for: run, step: step, customMinutes: customMin)
                                },
                                showDataCard: { selectedDataCardRun = $0 },
                                openBenchMode: { focusedRun = $0 },
                                removeRun: { run in
                                    importedRuns.removeAll { $0.id == run.id }
                                    hapticFeedback(.medium)
                                },
                                onUpdateRun: { updatedRun in
                                    if let index = importedRuns.firstIndex(where: {
                                        $0.id == updatedRun.id
                                    }) {
                                        importedRuns[index] = updatedRun
                                    }
                                },
                                toggleStep: toggleStepCompletion,
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
                        FuturePlanCalendarView(
                            runs: tomorrowRuns,
                            selectedDate: $selectedFutureDate,
                            projects: projects,
                            projectFilter: selectedProjectFilter
                        )

                        HStack(spacing: 10) {
                            Image(systemName: "calendar.badge.plus")
                                .foregroundStyle(.teal)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(selectedFutureDateLabel) · \(selectedFutureRuns.count) 个计划")
                                    .font(.headline)
                                Text("点击日历任意未来日期后，在这里安排当天实验")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                scheduleRequest = ScheduleRequest(
                                    targetDay: .tomorrow,
                                    timeLabel: "09:00",
                                    dateKey: selectedFutureDateKey,
                                    dateLabel: selectedFutureDateLabel
                                )
                            } label: {
                                Label("添加", systemImage: "plus")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.teal)
                        }
                        .padding(14)
                        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                        if selectedFutureRuns.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 46))
                                    .foregroundStyle(.teal.opacity(0.32))
                                Text("\(selectedFutureDateLabel) 还没有计划")
                                    .font(.title3.weight(.semibold))
                                Text("选择日期后点击「添加」安排当天实验")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 34)
                            .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
                        } else {
                            DayTimelineView(
                                targetDay: .tomorrow,
                                runs: selectedFutureRuns,
                                completedStepIDs: completedStepIDs,
                                activeTimers: [],
                                projects: projects,
                                addAtTime: { timeLabel in
                                    scheduleRequest = ScheduleRequest(
                                        targetDay: .tomorrow,
                                        timeLabel: timeLabel,
                                        dateKey: selectedFutureDateKey,
                                        dateLabel: selectedFutureDateLabel
                                    )
                                },
                                startTimer: { _, _, _ in },
                                showDataCard: { selectedDataCardRun = $0 },
                                openBenchMode: { _ in },
                                removeRun: { run in
                                    tomorrowRuns.removeAll { $0.id == run.id }
                                    hapticFeedback(.medium)
                                },
                                onUpdateRun: { updatedRun in
                                    if let index = tomorrowRuns.firstIndex(where: {
                                        $0.id == updatedRun.id
                                    }) {
                                        tomorrowRuns[index] = updatedRun
                                    }
                                },
                                toggleStep: toggleStepCompletion,
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
                    startTimer: { customMin in startTimer(for: run, customMinutes: customMin) },
                    pauseTimer: {
                        if let t = activeTimers.first(where: { $0.runID == run.id }) {
                            pauseTimer(t)
                        }
                    },
                    resumeTimer: {
                        if let t = activeTimers.first(where: { $0.runID == run.id }) {
                            resumeTimer(t)
                        }
                    },
                    stopTimer: {
                        if let t = activeTimers.first(where: { $0.runID == run.id }) {
                            stopTimer(t)
                        }
                    },
                    showDataCard: { selectedDataCardRun = run }
                )
            }
            .confirmationDialog("结束今天", isPresented: $showEndDayConfirm, titleVisibility: .visible)
            {
                Button("归档今天并开始新的一天", role: .destructive) {
                    onEndDay()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("今天所有实验（含未完成）将归档到「过去」，明天的计划移入今天。")
            }
            .onAppear(perform: loadTimers)
            .onChange(of: selectedMode) { _, mode in
                if mode == .past {
                    selectedProjectFilter = nil
                    ensurePastSelection()
                }
            }
            .onChange(of: selectedProjectFilter) { _, _ in
                if selectedMode == .past {
                    ensurePastSelection()
                }
            }
            .onChange(of: pastDays) { _, _ in
                if selectedMode == .past {
                    ensurePastSelection()
                }
            }
            .onChange(of: activeTimers) { _, newTimers in
                saveTimers(newTimers)
                checkForFinishedTimers(newTimers)
            }
        }
    }

    private func startTimer(for run: LabRun, step: LabStep? = nil, customMinutes: Int? = nil) {
        let targetStep =
            step
            ?? (run.steps.first(where: {
                $0.durationMinutes != nil && !completedStepIDs.contains($0.id)
            })
                ?? run.steps.first(where: { $0.durationMinutes != nil }))
        guard let targetStep = targetStep else { return }
        let dur = customMinutes ?? targetStep.durationMinutes ?? 5
        let now = Date()
        let timer = ActiveLabTimer(
            id: "\(run.id)-\(targetStep.id)", runID: run.id, runTitle: run.title,
            stepTitle: targetStep.title, startedAt: now,
            endsAt: now.addingTimeInterval(TimeInterval(dur * 60)))
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
            let paused = timer.pausedRemaining
        else { return }
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

    private static func futureDayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func futureDateLabel(_ date: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        if cal.isDate(date, inSameDayAs: cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()) {
            return "明天"
        }
        let f = DateFormatter()
        f.calendar = cal
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f.string(from: date)
    }

    private func ensurePastSelection() {
        let visibleDays: [ExperimentDayRecord]
        if let selectedProjectFilter {
            visibleDays = historyDays.filter { day in
                day.runs.contains {
                    runMatchesProject($0, projectFilter: selectedProjectFilter, projects: projects)
                }
            }
        } else {
            visibleDays = historyDays
        }

        if visibleDays.contains(where: { $0.id == selectedRecordDayID }) {
            return
        }
        selectedRecordDayID = visibleDays.first?.id ?? historyDays.first?.id ?? ""
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
            let timers = try? JSONDecoder().decode([ActiveLabTimer].self, from: data)
        else { return }
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
                let message =
                    voiceAnnouncementTemplate
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
