import SwiftUI

// MARK: - Toolbox Home

struct CalculatorToolkitView: View {
    @State private var history: [CalculationRecord] = {
        guard let data = UserDefaults.standard.data(forKey: "calculationHistory"),
              let records = try? JSONDecoder().decode([CalculationRecord].self, from: data) else { return [] }
        return records
    }()
    @State private var activeCalculator: CalculatorMode?
    @State private var activeTemplate: BufferTemplate?
    @State private var restoreInputs: [String: Double]?

    var body: some View {
        ZStack {
            Color.labBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {

                    // Calculator tool list
                    VStack(alignment: .leading, spacing: 10) {
                        Text("计算工具")
                            .font(.headline)

                        ForEach(CalculatorMode.allCases) { mode in
                            Button {
                                restoreInputs = nil
                                activeCalculator = mode
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: mode.icon)
                                        .font(.title2)
                                        .foregroundStyle(.teal)
                                        .frame(width: 40, height: 40)
                                        .background(Color.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mode.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text(mode.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(14)
                                .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Buffer / medium templates
                    VStack(alignment: .leading, spacing: 10) {
                        Text("常用缓冲液 · 培养基模板")
                            .font(.headline)

                        ForEach(SampleData.bufferTemplates) { template in
                            Button {
                                activeTemplate = template
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(template.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        HStack(spacing: 6) {
                                            AreaBadge(area: template.area)
                                            Text("基准 \(Int(template.baseVolume)) \(template.volumeUnit)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(14)
                                .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Recent calculation history
                    if !history.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("最近计算记录")
                                    .font(.headline)
                                Spacer()
                                Button("清空") {
                                    history = []
                                    saveHistory()
                                }
                                .font(.subheadline)
                                .foregroundStyle(.red)
                            }

                            ForEach(history.prefix(8)) { record in
                                Button {
                                    restoreInputs = record.inputs
                                    if let mode = CalculatorMode(rawValue: record.mode) {
                                        activeCalculator = mode
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(record.label)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                            Text(record.result)
                                                .font(.caption.monospacedDigit())
                                                .foregroundStyle(.teal)
                                            Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(12)
                                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        history.removeAll { $0.id == record.id }
                                        saveHistory()
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(18)
            }
        }
        .sheet(item: $activeCalculator) { mode in
            CalculatorScreen(
                mode: mode,
                initialInputs: restoreInputs,
                onSave: { record in
                    history.removeAll { $0.mode == record.mode && $0.label == record.label }
                    history.insert(record, at: 0)
                    if history.count > 50 { history = Array(history.prefix(50)) }
                    saveHistory()
                }
            )
        }
        .sheet(item: $activeTemplate) { template in
            BufferTemplateSheet(template: template, onSave: { record in
                history.insert(record, at: 0)
                saveHistory()
            })
        }
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: "calculationHistory")
    }
}

// MARK: - Calculator Screen (focused, per-mode)

struct CalculatorScreen: View {
    let mode: CalculatorMode
    let initialInputs: [String: Double]?
    let onSave: (CalculationRecord) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    // Mass concentration
    @State private var molecularWeight: Double = 121.14
    @State private var targetMolarity: Double = 0.5
    @State private var massVolumeML: Double = 100.0
    // Dilution
    @State private var stockConcentration: Double = 1.0
    @State private var finalConcentration: Double = 0.05
    @State private var dilutionVolumeML: Double = 100.0
    // Percent
    @State private var percentValue: Double = 5.0
    @State private var percentVolumeML: Double = 20.0

    private var resultText: String {
        switch mode {
        case .mass:
            let mass = molecularWeight * targetMolarity * (massVolumeML / 1000.0)
            return "称量 \(formatCalc(mass)) g"
        case .dilution:
            let stockVol = stockConcentration > 0 ? finalConcentration * dilutionVolumeML / stockConcentration : 0
            let solventVol = max(0, dilutionVolumeML - stockVol)
            return "取母液 \(formatCalc(stockVol)) ml + 溶剂 \(formatCalc(solventVol)) ml"
        case .percent:
            let mass = percentValue / 100.0 * percentVolumeML
            return "称量/量取 \(formatCalc(mass)) g 或 ml，定容至 \(formatCalc(percentVolumeML)) ml"
        }
    }

    private var currentInputs: [String: Double] {
        switch mode {
        case .mass: return ["mw": molecularWeight, "mol": targetMolarity, "vol": massVolumeML]
        case .dilution: return ["c1": stockConcentration, "c2": finalConcentration, "v2": dilutionVolumeML]
        case .percent: return ["pct": percentValue, "vol": percentVolumeML]
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Image(systemName: mode.icon)
                            .font(.title)
                            .foregroundStyle(.teal)
                        VStack(alignment: .leading) {
                            Text(mode.title)
                                .font(.title2.bold())
                            Text(mode.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    VStack(spacing: 12) {
                        switch mode {
                        case .mass:
                            LabNumberField(title: "分子量 (MW)", value: $molecularWeight, unit: "g/mol")
                            LabNumberField(title: "目标浓度", value: $targetMolarity, unit: "M")
                            LabNumberField(title: "总体积", value: $massVolumeML, unit: "ml")
                        case .dilution:
                            LabNumberField(title: "母液浓度 C1", value: $stockConcentration, unit: "M")
                            LabNumberField(title: "目标浓度 C2", value: $finalConcentration, unit: "M")
                            LabNumberField(title: "总体积 V2", value: $dilutionVolumeML, unit: "ml")
                        case .percent:
                            LabNumberField(title: "百分比浓度", value: $percentValue, unit: "%")
                            LabNumberField(title: "总体积", value: $percentVolumeML, unit: "ml")
                        }
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    // Result
                    VStack(alignment: .leading, spacing: 12) {
                        Text("计算结果")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(resultText)
                            .font(.title3.monospacedDigit().weight(.bold))

                        HStack(spacing: 10) {
                            Button {
                                Clipboard.copy(resultText)
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                            } label: {
                                Label(copied ? "已复制" : "复制结果", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)

                            Button {
                                let record = CalculationRecord(
                                    id: UUID().uuidString,
                                    mode: mode.rawValue,
                                    label: "\(mode.title)",
                                    result: resultText,
                                    date: Date(),
                                    inputs: currentInputs
                                )
                                onSave(record)
                                dismiss()
                            } label: {
                                Label("存为 Protocol 草稿", systemImage: "square.and.pencil")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }
                    .padding(16)
                    .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(18)
            }
            .background(Color.labBackground)
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
            .onAppear {
                guard let inputs = initialInputs else { return }
                switch mode {
                case .mass:
                    molecularWeight = inputs["mw"] ?? molecularWeight
                    targetMolarity = inputs["mol"] ?? targetMolarity
                    massVolumeML = inputs["vol"] ?? massVolumeML
                case .dilution:
                    stockConcentration = inputs["c1"] ?? stockConcentration
                    finalConcentration = inputs["c2"] ?? finalConcentration
                    dilutionVolumeML = inputs["v2"] ?? dilutionVolumeML
                case .percent:
                    percentValue = inputs["pct"] ?? percentValue
                    percentVolumeML = inputs["vol"] ?? percentVolumeML
                }
            }
        }
    }
}

// MARK: - Buffer Template Sheet

struct BufferTemplateSheet: View {
    let template: BufferTemplate
    let onSave: (CalculationRecord) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var targetVolume: Double
    @State private var copied = false

    init(template: BufferTemplate, onSave: @escaping (CalculationRecord) -> Void) {
        self.template = template
        self.onSave = onSave
        _targetVolume = State(initialValue: template.baseVolume)
    }

    private var scaleFactor: Double { template.baseVolume > 0 ? targetVolume / template.baseVolume : 1 }

    private var resultText: String {
        template.ingredients.map { ing in
            let amount = ing.standardAmount * scaleFactor
            let formatted = amount >= 10 ? String(format: "%.0f", amount) : String(format: "%.2f", amount)
            return "\(ing.name): \(formatted) \(ing.unit)"
        }.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.title2.bold())
                            AreaBadge(area: template.area)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("目标体积")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(Int(targetVolume)) \(template.volumeUnit)")
                                .font(.headline.monospacedDigit())
                        }
                        Slider(value: $targetVolume, in: 10...1000, step: 10)
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("缩放配方")
                                .font(.headline)
                            Spacer()
                            Text("x\(String(format: "%.2f", scaleFactor))")
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(.teal)
                        }
                        ForEach(template.ingredients) { ing in
                            HStack {
                                Text(ing.name)
                                    .font(.subheadline)
                                Spacer()
                                let amount = ing.standardAmount * scaleFactor
                                Text("\(amount >= 10 ? String(format: "%.0f", amount) : String(format: "%.2f", amount)) \(ing.unit)")
                                    .font(.subheadline.monospacedDigit().weight(.semibold))
                            }
                            .padding(.vertical, 2)
                            Divider()
                        }
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    HStack(spacing: 10) {
                        Button {
                            Clipboard.copy(resultText)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                        } label: {
                            Label(copied ? "已复制" : "复制配方", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button {
                            let record = CalculationRecord(
                                id: UUID().uuidString,
                                mode: "buffer",
                                label: template.name,
                                result: resultText,
                                date: Date(),
                                inputs: ["vol": targetVolume]
                            )
                            onSave(record)
                            dismiss()
                        } label: {
                            Label("存为 Protocol 草稿", systemImage: "square.and.pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .padding(18)
            }
            .background(Color.labBackground)
            .navigationTitle("缓冲液模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
    }
}

// MARK: - Shared number field

struct LabNumberField: View {
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
                .frame(width: 54, alignment: .leading)
        }
    }
}

// MARK: - Calculator mode enum

enum CalculatorMode: String, CaseIterable, Identifiable {
    case mass = "质量"
    case dilution = "稀释"
    case percent = "%"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mass: return "质量浓度"
        case .dilution: return "液体稀释"
        case .percent: return "百分比浓度"
        }
    }

    var subtitle: String {
        switch self {
        case .mass: return "MW × M × L → 称量质量"
        case .dilution: return "C1V1 = C2V2 → 取母液量"
        case .percent: return "w/v 或 v/v → 溶质质量"
        }
    }

    var icon: String {
        switch self {
        case .mass: return "scalemass"
        case .dilution: return "drop.triangle"
        case .percent: return "percent"
        }
    }
}

private func formatCalc(_ value: Double) -> String {
    if value >= 100 { return String(format: "%.0f", value) }
    if value >= 10 { return String(format: "%.1f", value) }
    return String(format: "%.2f", value)
}
