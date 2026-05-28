import SwiftUI

struct ContentView: View {
    @State private var importedRuns: [LabRun] = []

    var body: some View {
        TabView {
            TodayView(importedRuns: importedRuns)
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
        }
        .tint(.teal)
        .onAppear(perform: loadImportedRuns)
        .onChange(of: importedRuns) {
            saveImportedRuns(importedRuns)
        }
    }

    private func importRun(from labProtocol: LabProtocol, targetVolume: Double) {
        let factor = targetVolume / labProtocol.baseVolume
        let recipeSummary = labProtocol.ingredients
            .prefix(3)
            .map { "\($0.name) \($0.scaled(by: factor))" }
            .joined(separator: " / ")
        let duration = estimatedMinutes(from: labProtocol.expectedDuration)
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
                ),
                LabStep(
                    id: "\(labProtocol.id)-execute-\(Int(Date().timeIntervalSince1970))",
                    title: "执行 Protocol",
                    detail: "按缩放后的用量完成 \(labProtocol.name)",
                    durationMinutes: duration,
                    isCarryOver: false
                ),
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
    @AppStorage("completedStepIDs") private var completedStepIDsData = ""
    @State private var activeTimers: [ActiveLabTimer] = []
    @State private var selectedDataCardRun: LabRun?
    @State private var focusedRun: LabRun?

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
                            openBenchMode: { focusedRun = run }
                        )
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
    let importRun: (LabProtocol, Double) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("调用 Protocol 时输入本次用量，配方会按比例换算。")
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

                ForEach(SampleData.protocols) { labProtocol in
                    ProtocolCard(
                        labProtocol: labProtocol,
                        targetVolume: targetVolume,
                        isRecentlyImported: importedProtocolName == labProtocol.name,
                        importRun: {
                            importRun(labProtocol, targetVolume)
                            importedProtocolName = labProtocol.name
                        }
                    )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Protocol")
        }
    }
}

private struct ProtocolCard: View {
    let labProtocol: LabProtocol
    let targetVolume: Double
    let isRecentlyImported: Bool
    let importRun: () -> Void

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
                Button(action: importRun) {
                    Label("已导入今日", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button(action: importRun) {
                    Label("导入今日安排", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(16)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
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
                            copiedResult = resultText
                        } label: {
                            Label(copiedResult == resultText ? "已准备复制" : "生成可复制结果", systemImage: copiedResult == resultText ? "checkmark.circle.fill" : "doc.on.doc")
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
    @State private var reportCopied = false

    private var doneCount: Int {
        run.steps.filter { completedStepIDs.contains($0.id) }.count
    }

    private var reportText: String {
        "老师好，我刚完成了\(run.title)。Protocol：\(run.protocolName)；规模：\(run.scaledVolumeLabel)；步骤完成：\(doneCount)/\(run.steps.count)。关键条件和结果图已整理在 LabBuddy 卡片中。"
    }

    var body: some View {
        NavigationStack {
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
                        .fill(LinearGradient(colors: [.teal.opacity(0.28), .blue.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(height: 170)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.checkmark")
                                    .font(.system(size: 42))
                                Text("实验图片占位")
                                    .font(.headline)
                            }
                            .foregroundStyle(.teal)
                        }

                    VStack(alignment: .leading, spacing: 10) {
                        MetadataRow(label: "Protocol", value: run.protocolName)
                        MetadataRow(label: "用量/规模", value: run.scaledVolumeLabel)
                        MetadataRow(label: "步骤完成", value: "\(doneCount)/\(run.steps.count)")
                        MetadataRow(label: "生成时间", value: Date.now.formatted(date: .abbreviated, time: .shortened))
                    }

                    Text("Powered by LabBuddy")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(18)
                .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 10) {
                    Text("汇报摘要")
                        .font(.headline)
                    Text(reportText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                Button {
                    reportCopied = true
                } label: {
                    Label(reportCopied ? "摘要已准备复制" : "生成汇报摘要", systemImage: reportCopied ? "checkmark.circle.fill" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Spacer()
            }
            .padding(18)
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
