import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
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
        }
        .tint(.teal)
    }
}

private struct TodayView: View {
    @AppStorage("completedStepIDs") private var completedStepIDsData = ""
    @State private var activeTimers: [ActiveLabTimer] = []
    @State private var selectedDataCardRun: LabRun?
    @State private var focusedRun: LabRun?

    private var completedStepIDs: Set<String> {
        get { Set(completedStepIDsData.split(separator: ",").map(String.init)) }
        nonmutating set { completedStepIDsData = newValue.sorted().joined(separator: ",") }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HeaderPanel(activeTimers: activeTimers)

                    if !activeTimers.isEmpty {
                        TimerDock(activeTimers: activeTimers, stopTimer: stopTimer)
                    }

                    ForEach(SampleData.runs) { run in
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
                    Text("3 个实验 · 5 个计时点 · 1 个顺延占位")
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
    let startTimer: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var currentStep: LabStep? {
        run.steps.first { !completedStepIDs.contains($0.id) } ?? run.steps.last
    }

    private var completionText: String {
        let doneCount = run.steps.filter { completedStepIDs.contains($0.id) }.count
        return "\(doneCount)/\(run.steps.count)"
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
                    ProtocolCard(labProtocol: labProtocol, targetVolume: targetVolume)
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

            Button {
            } label: {
                Label("导入今日安排", systemImage: "calendar.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(16)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ToolsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
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

private struct DataCardPreview: View {
    let run: LabRun
    let completedStepIDs: Set<String>
    @Environment(\.dismiss) private var dismiss

    private var doneCount: Int {
        run.steps.filter { completedStepIDs.contains($0.id) }.count
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

                Button {
                    dismiss()
                } label: {
                    Label("复制汇报摘要", systemImage: "doc.on.doc")
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
