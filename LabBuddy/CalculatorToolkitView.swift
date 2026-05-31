import SwiftUI

// MARK: - Toolbox Home

struct CalculatorToolkitView: View {
    @State private var history: [CalculationRecord] = {
        guard let data = UserDefaults.standard.data(forKey: "calculationHistory"),
              let records = try? JSONDecoder().decode([CalculationRecord].self, from: data) else { return [] }
        return records
    }()
    @State private var customTemplates: [BufferTemplate] = {
        guard let data = UserDefaults.standard.data(forKey: "customBufferTemplates"),
              let templates = try? JSONDecoder().decode([BufferTemplate].self, from: data) else { return [] }
        return templates
    }()
    @State private var activeCalculator: CalculatorMode?
    @State private var activeTemplate: BufferTemplate?
    @State private var restoreInputs: [String: Double]?
    @State private var showingNewTemplateSheet = false
    @State private var editingTemplate: BufferTemplate?
    @State private var showCustomCalculator = false

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
                                if mode == .custom {
                                    showCustomCalculator = true
                                } else {
                                    restoreInputs = nil
                                    activeCalculator = mode
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: mode.icon)
                                        .font(.title3)
                                        .foregroundStyle(.teal)
                                        .frame(width: 36, height: 36)
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

                                    if let last = lastResultFor(mode) {
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(last.result)
                                                .font(.caption2.monospacedDigit().weight(.semibold))
                                                .foregroundStyle(.teal)
                                                .lineLimit(1)
                                            Text(last.date.formatted(.relative(presentation: .numeric)))
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }

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
                        HStack {
                            Text("常用缓冲液 · 培养基模板")
                                .font(.headline)
                            Spacer()
                            Button {
                                showingNewTemplateSheet = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.teal)
                            }
                        }

                        ForEach(SampleData.bufferTemplates + customTemplates) { template in
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
                            .contextMenu {
                                if customTemplates.contains(where: { $0.id == template.id }) {
                                    Button {
                                        editingTemplate = template
                                    } label: {
                                        Label("编辑", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        customTemplates.removeAll { $0.id == template.id }
                                        saveCustomTemplates()
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
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
            BufferTemplateSheet(
                template: template,
                onSave: { record in
                    history.insert(record, at: 0)
                    saveHistory()
                },
                onUpdate: { updated in
                    if let index = customTemplates.firstIndex(where: { $0.id == updated.id }) {
                        customTemplates[index] = updated
                        saveCustomTemplates()
                    }
                }
            )
        }
        .sheet(isPresented: $showingNewTemplateSheet) {
            BufferTemplateEditorSheet(template: nil) { newTemplate in
                customTemplates.append(newTemplate)
                saveCustomTemplates()
            }
        }
        .sheet(item: $editingTemplate) { template in
            BufferTemplateEditorSheet(template: template) { updated in
                if let index = customTemplates.firstIndex(where: { $0.id == updated.id }) {
                    customTemplates[index] = updated
                    saveCustomTemplates()
                }
            }
        }
        .sheet(isPresented: $showCustomCalculator) {
            CustomCalculatorSheet(
                onSave: { record in
                    history.removeAll { $0.mode == record.mode && $0.label == record.label }
                    history.insert(record, at: 0)
                    if history.count > 50 { history = Array(history.prefix(50)) }
                    saveHistory()
                }
            )
        }
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: "calculationHistory")
    }

    private func saveCustomTemplates() {
        guard let data = try? JSONEncoder().encode(customTemplates) else { return }
        UserDefaults.standard.set(data, forKey: "customBufferTemplates")
    }

    private func lastResultFor(_ mode: CalculatorMode) -> CalculationRecord? {
        history.first { $0.mode == mode.rawValue }
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
    @State private var mwUnit: String = "g/mol"
    @State private var molarityUnit: String = "M"
    @State private var massVolumeUnit: String = "ml"
    // Dilution
    @State private var stockConcentration: Double = 1.0
    @State private var finalConcentration: Double = 0.05
    @State private var dilutionVolumeML: Double = 100.0
    @State private var stockUnit: String = "M"
    @State private var finalUnit: String = "M"
    @State private var dilutionVolumeUnit: String = "ml"
    // Percent
    @State private var percentValue: Double = 5.0
    @State private var percentVolumeML: Double = 20.0
    @State private var percentUnit: String = "%"
    @State private var percentVolumeUnit: String = "ml"

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
        case .custom:
            return ""
        }
    }

    private var currentInputs: [String: Double] {
        switch mode {
        case .mass: return ["mw": molecularWeight, "mol": targetMolarity, "vol": massVolumeML]
        case .dilution: return ["c1": stockConcentration, "c2": finalConcentration, "v2": dilutionVolumeML]
        case .percent: return ["pct": percentValue, "vol": percentVolumeML]
        case .custom: return [:]
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
                            LabNumberField(title: "分子量 (MW)", value: $molecularWeight, unit: $mwUnit)
                            LabNumberField(title: "目标浓度", value: $targetMolarity, unit: $molarityUnit)
                            LabNumberField(title: "总体积", value: $massVolumeML, unit: $massVolumeUnit)
                        case .dilution:
                            LabNumberField(title: "母液浓度 C1", value: $stockConcentration, unit: $stockUnit)
                            LabNumberField(title: "目标浓度 C2", value: $finalConcentration, unit: $finalUnit)
                            LabNumberField(title: "总体积 V2", value: $dilutionVolumeML, unit: $dilutionVolumeUnit)
                        case .percent:
                            LabNumberField(title: "百分比浓度", value: $percentValue, unit: $percentUnit)
                            LabNumberField(title: "总体积", value: $percentVolumeML, unit: $percentVolumeUnit)
                        case .custom:
                            EmptyView()
                        }
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    // Result
                    VStack(alignment: .leading, spacing: 12) {
                        Text("计算结果")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        // Structured result display with prominent number
                        switch mode {
                        case .mass:
                            let mass = molecularWeight * targetMolarity * (massVolumeML / 1000.0)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("称量")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(formatCalc(mass))
                                    .font(.system(size: 42, weight: .bold, design: .rounded))
                                    .foregroundStyle(.teal)
                                Text("g")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                        case .dilution:
                            let stockVol = stockConcentration > 0 ? finalConcentration * dilutionVolumeML / stockConcentration : 0
                            let solventVol = max(0, dilutionVolumeML - stockVol)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("取母液")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(formatCalc(stockVol))
                                        .font(.system(size: 42, weight: .bold, design: .rounded))
                                        .foregroundStyle(.teal)
                                    Text("ml")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("加溶剂")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(formatCalc(solventVol))
                                        .font(.system(size: 42, weight: .bold, design: .rounded))
                                        .foregroundStyle(.teal)
                                    Text("ml")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        case .percent:
                            let mass = percentValue / 100.0 * percentVolumeML
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("称量/量取")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(formatCalc(mass))
                                        .font(.system(size: 42, weight: .bold, design: .rounded))
                                        .foregroundStyle(.teal)
                                    Text("g 或 ml")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("定容至")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(formatCalc(percentVolumeML))
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundStyle(.teal)
                                    Text("ml")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        case .custom:
                            EmptyView()
                        }

                        HStack(spacing: 10) {
                            Button {
                                Clipboard.copy(resultText)
                                copied = true
                                hapticSuccess()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                            } label: {
                                Label(copied ? "已复制" : "复制结果", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
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
                                Label("存为草稿", systemImage: "square.and.pencil")
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
                case .custom:
                    break
                }
            }
        }
    }
}

// MARK: - Buffer Template Sheet

struct BufferTemplateSheet: View {
    let template: BufferTemplate
    let onSave: (CalculationRecord) -> Void
    let onUpdate: ((BufferTemplate) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var targetVolume: Double
    @State private var copied = false
    @State private var editingIngredients: [ProtocolIngredient]
    @State private var showingAddIngredient = false
    @State private var editingIngredient: ProtocolIngredient?
    @State private var editedName: String
    @State private var editedVolumeUnit: String

    init(template: BufferTemplate, onSave: @escaping (CalculationRecord) -> Void, onUpdate: ((BufferTemplate) -> Void)? = nil) {
        self.template = template
        self.onSave = onSave
        self.onUpdate = onUpdate
        _targetVolume = State(initialValue: template.baseVolume)
        _editingIngredients = State(initialValue: template.ingredients)
        _editedName = State(initialValue: template.name)
        _editedVolumeUnit = State(initialValue: template.volumeUnit)
    }

    private var scaleFactor: Double { template.baseVolume > 0 ? targetVolume / template.baseVolume : 1 }

    private var resultText: String {
        editingIngredients.map { ing in
            let amount = ing.standardAmount * scaleFactor
            let formatted = amount >= 10 ? String(format: "%.0f", amount) : String(format: "%.2f", amount)
            return "\(ing.name): \(formatted) \(ing.unit)"
        }.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        TextField("模板名称", text: $editedName)
                            .font(.title2.bold())
                        Spacer()
                        AreaBadge(area: template.area)
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("目标体积")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            TextField("体积", value: $targetVolume, format: .number)
                                .multilineTextAlignment(.trailing)
                                .font(.headline.monospacedDigit())
                                .frame(width: 72)
                                .keyboardType(.decimalPad)
                            Picker("单位", selection: $editedVolumeUnit) {
                                Text("ml").tag("ml")
                                Text("L").tag("L")
                                Text("μl").tag("μl")
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 64)
                        }
                        Slider(value: $targetVolume, in: 10...1000, step: 10)
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("配方")
                                .font(.headline)
                            Spacer()
                            Button {
                                showingAddIngredient = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.teal)
                            }
                        }
                        ForEach($editingIngredients) { $ing in
                            Button {
                                editingIngredient = ing
                            } label: {
                                HStack {
                                    Text(ing.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    let amount = ing.isFormula ? (ing.standardAmount * scaleFactor) : ing.standardAmount
                                    Text("\(amount >= 10 ? String(format: "%.0f", amount) : String(format: "%.2f", amount)) \(ing.unit)")
                                        .font(.subheadline.monospacedDigit().weight(.semibold))
                                        .foregroundStyle(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 2)
                            .contextMenu {
                                Button(role: .destructive) {
                                    editingIngredients.removeAll { $0.id == ing.id }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
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
                        .buttonStyle(.borderedProminent)
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
                            Label("存为草稿", systemImage: "square.and.pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .padding(18)
            }
            .background(Color.labBackground)
            .navigationTitle(editedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
            .sheet(isPresented: $showingAddIngredient) {
                AddIngredientSheet(onAdd: { newIngredient in
                    editingIngredients.append(newIngredient)
                }, suggestedScale: scaleFactor)
            }
            .sheet(item: $editingIngredient) { ingredient in
                EditIngredientSheet(
                    ingredient: ingredient,
                    onSave: { updated in
                        if let index = editingIngredients.firstIndex(where: { $0.id == updated.id }) {
                            editingIngredients[index] = updated
                        }
                    },
                    onDelete: {
                        editingIngredients.removeAll { $0.id == ingredient.id }
                    }
                )
            }
        }
    }
}

// MARK: - Shared number field

struct LabNumberField: View {
    let title: String
    @Binding var value: Double
    @Binding var unit: String

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
            Picker("", selection: $unit) {
                ForEach(UnifiedUnits.forCalculator, id: \.self) { Text($0) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
        }
    }
}

// MARK: - Calculator mode enum

enum CalculatorMode: String, CaseIterable, Identifiable {
    case mass = "质量"
    case dilution = "稀释"
    case percent = "%"
    case custom = "自定义"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mass: return "质量浓度"
        case .dilution: return "液体稀释"
        case .percent: return "百分比浓度"
        case .custom: return "自定义公式"
        }
    }

    var subtitle: String {
        switch self {
        case .mass: return "MW × M × L → 称量质量"
        case .dilution: return "C1V1 = C2V2 → 取母液量"
        case .percent: return "w/v 或 v/v → 溶质质量"
        case .custom: return "自由定义公式与变量 → 即时计算"
        }
    }

    var icon: String {
        switch self {
        case .mass: return "scalemass"
        case .dilution: return "drop.triangle"
        case .percent: return "percent"
        case .custom: return "x.squareroot"
        }
    }
}

private func formatCalc(_ value: Double) -> String {
    if value >= 100 { return String(format: "%.0f", value) }
    if value >= 10 { return String(format: "%.1f", value) }
    return String(format: "%.2f", value)
}

// MARK: - Add Ingredient Sheet

struct AddIngredientSheet: View {
    let onAdd: (ProtocolIngredient) -> Void
    var suggestedScale: Double = 1.0
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amount = ""
    @State private var unit = "g"
    @State private var isFormula = true

    init(onAdd: @escaping (ProtocolIngredient) -> Void, suggestedScale: Double = 1.0) {
        self.onAdd = onAdd
        self.suggestedScale = suggestedScale
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("成分信息") {
                    TextField("名称", text: $name)
                    TextField("用量", text: $amount)
                        .keyboardType(.decimalPad)
                    HStack {
                        Text("单位")
                        Spacer()
                        Picker("", selection: $unit) {
                            ForEach(UnifiedUnits.forProtocol, id: \.self) { u in
                                Text(u).tag(u)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .fixedSize()
                    }
                    Toggle("公式模式（可随体积缩放）", isOn: $isFormula)
                    if isFormula {
                        HStack {
                            Text("缩放后用量")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let val = Double(amount) {
                                Text("\(formatCalc(val * suggestedScale)) \(unit)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.teal)
                            }
                        }
                    }
                }

                Section {
                    Button("添加") {
                        guard !name.isEmpty, let amountValue = Double(amount), amountValue > 0 else { return }
                        let ingredient = ProtocolIngredient(
                            name: name,
                            standardAmount: amountValue,
                            unit: unit,
                            isFormula: isFormula
                        )
                        onAdd(ingredient)
                        dismiss()
                    }
                    .disabled(name.isEmpty || Double(amount) == nil)
                }
            }
            .navigationTitle("添加成分")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Edit Ingredient Sheet

struct EditIngredientSheet: View {
    let ingredient: ProtocolIngredient
    let onSave: (ProtocolIngredient) -> Void
    let onDelete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var amount: String
    @State private var unit: String
    @State private var isFormula: Bool

    init(ingredient: ProtocolIngredient, onSave: @escaping (ProtocolIngredient) -> Void, onDelete: (() -> Void)? = nil) {
        self.ingredient = ingredient
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: ingredient.name)
        _amount = State(initialValue: String(ingredient.standardAmount))
        _unit = State(initialValue: ingredient.unit)
        _isFormula = State(initialValue: ingredient.isFormula)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("成分信息") {
                    TextField("名称", text: $name)
                    TextField("用量", text: $amount)
                        .keyboardType(.decimalPad)
                    HStack {
                        Text("单位")
                        Spacer()
                        Picker("", selection: $unit) {
                            ForEach(UnifiedUnits.forProtocol, id: \.self) { u in
                                Text(u).tag(u)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .fixedSize()
                    }
                    Toggle("公式模式（可随体积缩放）", isOn: $isFormula)
                }

                Section {
                    Button("保存") {
                        guard !name.isEmpty, let amountValue = Double(amount), amountValue > 0 else { return }
                        let updated = ProtocolIngredient(
                            id: ingredient.id,
                            name: name,
                            standardAmount: amountValue,
                            unit: unit,
                            isFormula: isFormula
                        )
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(name.isEmpty || Double(amount) == nil)

                    if let onDelete = onDelete {
                        Button("删除", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("编辑成分")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Buffer Template Editor Sheet

struct BufferTemplateEditorSheet: View {
    let template: BufferTemplate?
    let onSave: (BufferTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var area: WorkflowArea
    @State private var baseVolume: String
    @State private var volumeUnit: String
    @State private var ingredients: [ProtocolIngredient]
    @State private var showingAddIngredient = false
    @State private var editingIngredient: ProtocolIngredient?

    init(template: BufferTemplate?, onSave: @escaping (BufferTemplate) -> Void) {
        self.template = template
        self.onSave = onSave
        _name = State(initialValue: template?.name ?? "")
        _area = State(initialValue: template?.area ?? .cell)
        _baseVolume = State(initialValue: template != nil ? String(Int(template!.baseVolume)) : "1000")
        _volumeUnit = State(initialValue: template?.volumeUnit ?? "ml")
        _ingredients = State(initialValue: template?.ingredients ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("模板名称", text: $name)
                    Picker("实验类型", selection: $area) {
                        ForEach(WorkflowArea.builtIn) { a in
                            Text(a.rawValue).tag(a)
                        }
                    }
                    HStack {
                        TextField("基准体积", text: $baseVolume)
                            .keyboardType(.decimalPad)
                        Picker("单位", selection: $volumeUnit) {
                            Text("ml").tag("ml")
                            Text("L").tag("L")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)
                    }
                }

                Section {
                    HStack {
                        Text("配方成分")
                            .font(.headline)
                        Spacer()
                        Button {
                            showingAddIngredient = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.teal)
                        }
                    }

                    ForEach(Array(ingredients.enumerated()), id: \.element.id) { index, ing in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ing.name)
                                    .font(.subheadline)
                                Text("\(formatCalc(ing.standardAmount)) \(ing.unit)\(ing.isFormula ? " (缩放)" : " (固定)")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                let ingredient = ingredients[index]
                                editingIngredient = ingredient
                            } label: {
                                Image(systemName: "pencil.circle")
                                    .font(.title3)
                                    .foregroundStyle(.teal)
                            }
                            .buttonStyle(.plain)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                ingredients.removeAll { $0.id == ing.id }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }

                Section {
                    Button("保存模板") {
                        guard !name.isEmpty,
                              let volValue = Double(baseVolume),
                              volValue > 0,
                              !ingredients.isEmpty else { return }

                        let newTemplate = BufferTemplate(
                            id: template?.id ?? UUID().uuidString,
                            name: name,
                            area: area,
                            baseVolume: volValue,
                            volumeUnit: volumeUnit,
                            ingredients: ingredients
                        )
                        onSave(newTemplate)
                        dismiss()
                    }
                    .disabled(name.isEmpty || Double(baseVolume) == nil || ingredients.isEmpty)
                }
            }
            .navigationTitle(template == nil ? "新建模板" : "编辑模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddIngredient) {
                AddIngredientSheet(onAdd: { newIngredient in
                    ingredients.append(newIngredient)
                })
            }
            .sheet(item: $editingIngredient) { ingredient in
                EditIngredientSheet(
                    ingredient: ingredient,
                    onSave: { updated in
                        if let index = ingredients.firstIndex(where: { $0.id == updated.id }) {
                            ingredients[index] = updated
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Custom Calculator Sheet

private struct CustomVariableField: Identifiable {
    let id = UUID()
    var name: String
    var value: String
    var unit: String
}

struct CustomCalculatorSheet: View {
    let onSave: (CalculationRecord) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var formula: String = ""
    @State private var variables: [CustomVariableField] = [CustomVariableField(name: "", value: "", unit: "")]
    @State private var resultLabel: String = "自定义公式"
    @State private var resultUnit: String = ""
    @State private var copied = false

    private var variableDict: [String: Double] {
        var dict = [String: Double]()
        for v in variables {
            guard !v.name.trimmingCharacters(in: .whitespaces).isEmpty,
                  let val = Double(v.value) else { continue }
            dict[v.name.trimmingCharacters(in: .whitespaces)] = val
        }
        return dict
    }

    private var result: Double? {
        guard !formula.trimmingCharacters(in: .whitespaces).isEmpty,
              !variableDict.isEmpty else { return nil }
        return ExpressionEvaluator.evaluate(formula, variables: variableDict)
    }

    private var resultText: String {
        guard let r = result else { return "输入公式和变量后自动计算" }
        return ExpressionEvaluator.format(r)
    }

    private var currentInputs: [String: Double] {
        variableDict
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header
                    HStack {
                        Image(systemName: "x.squareroot")
                            .font(.title)
                            .foregroundStyle(.teal)
                        VStack(alignment: .leading) {
                            Text("自定义公式")
                                .font(.title2.bold())
                            Text("自由定义公式与变量 → 即时计算")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    // Label
                    VStack(alignment: .leading, spacing: 6) {
                        Text("计算名称")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("如：细胞接种密度、稀释倍数...", text: $resultLabel)
                            .font(.subheadline)
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    // Formula
                    VStack(alignment: .leading, spacing: 6) {
                        Text("计算公式")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("如：a * b / 1000", text: $formula)
                            .font(.body.monospacedDigit())
                            .textFieldStyle(.roundedBorder)
                        Text("支持 + - * / 括号，变量名区分大小写")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    // Variables
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("变量")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                variables.append(CustomVariableField(name: "", value: "", unit: ""))
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.teal)
                            }
                        }

                        ForEach($variables) { $v in
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    TextField("变量名", text: $v.name)
                                        .font(.subheadline.monospacedDigit())
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)

                                    Text("=")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    TextField("值", text: $v.value)
                                        .font(.subheadline.monospacedDigit())
                                        .textFieldStyle(.roundedBorder)
                                        .keyboardType(.decimalPad)
                                        .frame(width: 80)

                                    Picker("", selection: $v.unit) {
                                        ForEach(UnifiedUnits.forCalculator, id: \.self) { Text($0) }
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                    .fixedSize()

                                    if variables.count > 1 {
                                        Button {
                                            variables.removeAll { $0.id == v.id }
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(.red.opacity(0.6))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                if !v.unit.isEmpty {
                                    HStack {
                                        Spacer()
                                        Text("\(v.name) = \(v.value) \(v.unit)")
                                            .font(.caption2)
                                            .foregroundStyle(.teal)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    // Result
                    VStack(alignment: .leading, spacing: 12) {
                        Text("计算结果")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            if let r = result {
                                Text(ExpressionEvaluator.format(r))
                                    .font(.title.monospacedDigit().weight(.bold))
                                    .foregroundStyle(.teal)
                            } else {
                                Text("输入公式和变量后自动计算")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                            }

                            if result != nil {
                                Picker("", selection: $resultUnit) {
                                    Text("无单位").tag("")
                                    ForEach(UnifiedUnits.forCalculator, id: \.self) { unit in
                                        Text(unit).tag(unit)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .fixedSize()
                            }
                        }

                        HStack(spacing: 10) {
                            Button {
                                guard let r = result else { return }
                                let resultText = resultUnit.isEmpty ? ExpressionEvaluator.format(r) : "\(ExpressionEvaluator.format(r)) \(resultUnit)"
                                Clipboard.copy(resultText)
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                            } label: {
                                Label(copied ? "已复制" : "复制结果", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(result == nil)

                            Button {
                                guard let r = result else { return }
                                let resultText = resultUnit.isEmpty ? ExpressionEvaluator.format(r) : "\(ExpressionEvaluator.format(r)) \(resultUnit)"
                                let record = CalculationRecord(
                                    id: UUID().uuidString,
                                    mode: CalculatorMode.custom.rawValue,
                                    label: resultLabel.trimmingCharacters(in: .whitespaces).isEmpty ? "自定义公式" : resultLabel,
                                    result: "\(formula) → \(resultText)",
                                    date: Date(),
                                    inputs: currentInputs
                                )
                                onSave(record)
                                dismiss()
                            } label: {
                                Label("存为草稿", systemImage: "square.and.pencil")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(result == nil)
                        }
                    }
                    .padding(16)
                    .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(18)
            }
            .background(Color.labBackground)
            .navigationTitle("自定义公式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
    }
}

// MARK: - Haptic Feedback Helper

private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
    #if os(iOS)
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.impactOccurred()
    #endif
}

private func hapticSuccess() {
    #if os(iOS)
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
    #endif
}
