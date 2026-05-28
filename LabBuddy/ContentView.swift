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

    private var completedStepIDs: Set<String> {
        get { Set(completedStepIDsData.split(separator: ",").map(String.init)) }
        nonmutating set { completedStepIDsData = newValue.sorted().joined(separator: ",") }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HeaderPanel()

                    ForEach(SampleData.runs) { run in
                        RunCard(run: run, completedStepIDs: completedStepIDs) { stepID in
                            var next = completedStepIDs
                            if next.contains(stepID) {
                                next.remove(stepID)
                            } else {
                                next.insert(stepID)
                            }
                            completedStepIDs = next
                        }
                    }
                }
                .padding(18)
            }
            .background(Color.labBackground)
            .navigationTitle("LabBuddy")
        }
    }
}

private struct HeaderPanel: View {
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
                MetricPill(value: "15 min", label: "最近倒计时")
                MetricPill(value: "50 ml", label: "培养基用量")
                MetricPill(value: "低库存", label: "FBS 预警")
            }
        }
        .padding(18)
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
    let toggleStep: (String) -> Void

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
                Button {
                } label: {
                    Label("启动计时", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                } label: {
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
