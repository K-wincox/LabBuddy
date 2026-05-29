import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ContentView: View {
    @State private var importedRuns: [LabRun] = []
    @State private var inventoryItems: [InventoryItem] = SampleData.inventory

    var body: some View {
        TabView {
            TodayView(importedRuns: importedRuns)
                .environment(\.removeImportedRun, { runID in
                    importedRuns.removeAll { $0.id == runID }
                })
                .tabItem {
                    Label("今日", systemImage: "calendar")
                }

            ProtocolsView { labProtocol, targetVolume in
                importRun(from: labProtocol, targetVolume: targetVolume)
            }
                .tabItem {
                    Label("Protocol", systemImage: "list.clipboard")
                }

            ToolsView()
                .tabItem {
                    Label("工具", systemImage: "function")
                }

            InventoryView(
                items: $inventoryItems,
                resetDemoData: resetDemoData
            )
                .tabItem {
                    Label("库存", systemImage: "shippingbox")
                }

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
        }
        .tint(.teal)
        .onAppear {
            loadImportedRuns()
            loadInventoryItems()
        }
        .onChange(of: importedRuns) {
            saveImportedRuns(importedRuns)
        }
        .onChange(of: inventoryItems) {
            saveInventoryItems(inventoryItems)
        }
    }

    private func importRun(from labProtocol: LabProtocol, targetVolume: Double) {
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
            id: "import-\(labProtocol.id)-\(Int(Date().timeIntervalSince1970))",
            title: labProtocol.name,
            area: labProtocol.area,
            timeLabel: "现在",
            status: "刚导入",
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
        importedRuns.insert(run, at: 0)
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

private struct TodayView: View {
    let importedRuns: [LabRun]
    @Environment(\.removeImportedRun) private var removeImportedRun
    @AppStorage("completedStepIDs") private var completedStepIDsData = ""
    @State private var activeTimers: [ActiveLabTimer] = []
    @State private var selectedDataCardRun: LabRun?
    @State private var focusedRun: LabRun?
    @State private var selectedMode: TodayMode = .plan

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HeaderPanel(
                        runCount: todayRuns.count,
                        timerPointCount: timerPointCount,
                        carryOverCount: carryOverCount,
                        activeTimers: activeTimers
                    )

                    Picker("今日视图", selection: $selectedMode) {
                        ForEach(TodayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch selectedMode {
                    case .plan:
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
                    case .history:
                        ExperimentHistoryView(days: historyDays, completedStepIDs: completedStepIDs)
                    }
                }
                .padding(18)
            }
            .background(Color.labBackground)
            .navigationTitle("LabBuddy")
            .sheet(item: $selectedDataCardRun) { run in
                DataCardPreview(run: run, completedStepIDs: completedStepIDs)
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

private enum TodayMode: String, CaseIterable, Identifiable {
    case plan
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plan:
            return "今日安排"
        case .history:
            return "实验记录"
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

private struct ExperimentHistoryView: View {
    let days: [ExperimentDay]
    let completedStepIDs: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(days) { day in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(day.dateLabel)
                                .font(.title3.bold())
                            Text(day.weekday)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 64, alignment: .leading)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(day.summary)
                                .font(.subheadline.weight(.semibold))
                            Text("\(day.runs.count) 条实验记录")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

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
                .padding(16)
                .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
            }
        }
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
    @State private var importedProtocolName: String?
    @State private var editableProtocols = SampleData.protocols
    @State private var selectedProtocol: LabProtocol?
    let importRun: (LabProtocol, Double) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("选择模板后可先修改参数、成分和步骤，再导入今日安排。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
                    Button {
                        selectedProtocol = emptyProtocol()
                    } label: {
                        Label("导入/新建 Protocol", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                ForEach(editableProtocols) { labProtocol in
                    ProtocolCard(
                        labProtocol: labProtocol,
                        targetVolume: targetVolume,
                        isRecentlyImported: importedProtocolName == labProtocol.name,
                        importRun: {
                            importRun(labProtocol, targetVolume)
                            importedProtocolName = labProtocol.name
                        },
                        editProtocol: {
                            selectedProtocol = labProtocol
                        }
                    )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Protocol")
            .sheet(item: $selectedProtocol) { labProtocol in
                ProtocolEditorView(
                    labProtocol: labProtocol,
                    targetVolume: targetVolume,
                    saveProtocol: { updatedProtocol in
                        upsert(updatedProtocol)
                    },
                    importProtocol: { updatedProtocol in
                        upsert(updatedProtocol)
                        importRun(updatedProtocol, targetVolume)
                        importedProtocolName = updatedProtocol.name
                    }
                )
            }
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
            ]
        )
    }
}

private struct ProtocolCard: View {
    let labProtocol: LabProtocol
    let targetVolume: Double
    let isRecentlyImported: Bool
    let importRun: () -> Void
    let editProtocol: () -> Void

    private var scaleFactor: Double {
        targetVolume / labProtocol.baseVolume
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
                Text("x\(scaleFactor, specifier: "%.2f")")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.teal.opacity(0.12), in: Capsule())
                    .foregroundStyle(.teal)
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

            if isRecentlyImported {
                HStack(spacing: 10) {
                    Button(action: editProtocol) {
                        Label("编辑", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(action: importRun) {
                        Label("已导入今日", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else {
                HStack(spacing: 10) {
                    Button(action: editProtocol) {
                        Label("编辑", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(action: importRun) {
                        Label("导入今日", systemImage: "calendar.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
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
    let importProtocol: (LabProtocol) -> Void
    @Environment(\.dismiss) private var dismiss

    init(
        labProtocol: LabProtocol,
        targetVolume: Double,
        saveProtocol: @escaping (LabProtocol) -> Void,
        importProtocol: @escaping (LabProtocol) -> Void
    ) {
        _draft = State(initialValue: labProtocol)
        self.targetVolume = targetVolume
        self.saveProtocol = saveProtocol
        self.importProtocol = importProtocol
    }

    private var scaleFactor: Double {
        guard draft.baseVolume > 0 else {
            return 1
        }
        return targetVolume / draft.baseVolume
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

                Section {
                    Button {
                        importProtocol(draft)
                        dismiss()
                    } label: {
                        Label("保存并导入今日安排", systemImage: "calendar.badge.plus")
                            .frame(maxWidth: .infinity)
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
        NavigationStack {
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
            .background(Color.labBackground)
            .navigationTitle("计算工具")
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
        NavigationStack {
            ScrollView {
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
                .padding(18)
            }
            .background(Color.labBackground)
            .navigationTitle("库存")
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
    @AppStorage("profileDisplayName") private var displayName = "未登录用户"
    @AppStorage("profileLabName") private var labName = "个人本地工作区"
    @AppStorage("profileLargeBenchMode") private var largeBenchMode = true
    @AppStorage("profileLocalOnly") private var localOnly = true
    @AppStorage("profileDataCardWatermark") private var dataCardWatermark = true

    var body: some View {
        NavigationStack {
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
                }
                .padding(18)
            }
            .background(Color.labBackground)
            .navigationTitle("我的")
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

private extension EnvironmentValues {
    var removeImportedRun: (String) -> Void {
        get { self[RemoveImportedRunKey.self] }
        set { self[RemoveImportedRunKey.self] = newValue }
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
