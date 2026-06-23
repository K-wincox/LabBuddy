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
    @State private var savedFormulas: [SavedFormula] = {
        guard let data = UserDefaults.standard.data(forKey: "savedCustomFormulas"),
              let formulas = try? JSONDecoder().decode([SavedFormula].self, from: data) else { return [] }
        return formulas
    }()
    @State private var activeCalculator: CalculatorMode?
    @State private var activeTemplate: BufferTemplate?
    @State private var restoreInputs: [String: Double]?
    @State private var showingNewTemplateSheet = false
    @State private var editingTemplate: BufferTemplate?
    @State private var showCustomCalculator = false
    @State private var prefillFormula: SavedFormula?

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

                    // Saved custom formulas
                    if !savedFormulas.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("已保存的公式")
                                .font(.headline)

                            ForEach(savedFormulas) { saved in
                                Button {
                                    prefillFormula = saved
                                    showCustomCalculator = true
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "function")
                                            .font(.title3)
                                            .foregroundStyle(.indigo)
                                            .frame(width: 36, height: 36)
                                            .background(Color.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(saved.label)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                            Text(saved.formula)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
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
                                    Button(role: .destructive) {
                                        savedFormulas.removeAll { $0.id == saved.id }
                                        saveFormulas()
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
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
                    } else {
                        customTemplates.append(updated)
                    }
                    saveCustomTemplates()
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
                prefill: prefillFormula,
                onSave: { record in
                    history.removeAll { $0.mode == record.mode && $0.label == record.label }
                    history.insert(record, at: 0)
                    if history.count > 50 { history = Array(history.prefix(50)) }
                    saveHistory()
                },
                onSaveFormula: { saved in
                    savedFormulas.removeAll { $0.label == saved.label && $0.formula == saved.formula }
                    savedFormulas.insert(saved, at: 0)
                    saveFormulas()
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

    private func saveFormulas() {
        guard let data = try? JSONEncoder().encode(savedFormulas) else { return }
        UserDefaults.standard.set(data, forKey: "savedCustomFormulas")
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
    @State private var alertMessage: String?

    // Mass concentration
    @State private var molecularWeight: Double = 121.14
    @State private var targetMolarity: Double = 0.5
    @State private var massVolumeML: Double = 100.0
    @State private var mwUnit: String = "g/mol"
    @State private var molarityUnit: String = "M"
    @State private var massVolumeUnit: String = "ml"
    // Dilution
    @State private var stockConcentration: Double = 1.0
    @State private var stockConcentrationText: String = "1.0"
    @State private var stockVolumeText: String = ""
    @State private var finalConcentration: Double = 0.05
    @State private var finalConcentrationText: String = "0.05"
    @State private var dilutionVolumeML: Double = 100.0
    @State private var dilutionVolumeText: String = "100"
    @State private var stockUnit: String = "M"
    @State private var stockVolumeUnit: String = "ml"
    @State private var finalUnit: String = "M"
    @State private var dilutionVolumeUnit: String = "ml"
    // Percent
    @State private var percentValue: Double = 5.0
    @State private var percentVolumeML: Double = 20.0
    @State private var percentUnit: String = "%"
    @State private var percentKind: String = "w/v"
    @State private var percentVolumeUnit: String = "ml"
    // Transfection
    @State private var totalDNAMass: Double = 10
    @State private var totalDNAMassUnit: String = "μg"
    @State private var selectedTransfectionDoseID: String = defaultTransfectionReferenceDoses.last?.id ?? ""
    @State private var transfectionDoses: [TransfectionReferenceDose] = defaultTransfectionReferenceDoses
    @State private var editingTransfectionDose: TransfectionReferenceDose?
    @State private var transfectionPlasmidGroups: [TransfectionPlasmidGroupInput] = defaultTransfectionPlasmidGroups
    @State private var transfectionRatioGroups: [TransfectionRatioGroup] = defaultTransfectionRatioGroups
    @State private var peiMassRatio: Double = 3
    @State private var dnaMassRatio: Double = 1
    @State private var editingPlasmid: TransfectionPlasmidEditContext?

    private var resultText: String {
        calculationResult?.detail ?? "点击「计算结果」后生成"
    }

    private var currentInputs: [String: Double] {
        switch mode {
        case .mass: return ["mw": molecularWeight, "mol": targetMolarity, "vol": massVolumeML]
        case .dilution:
            guard let solved = dilutionSolveResult else { return [:] }
            return ["c1": solved.c1, "v1": solved.v1ML, "c2": solved.c2, "v2": solved.v2ML]
        case .percent: return ["pct": percentValue, "vol": percentVolumeML]
        case .transfection:
            var inputs: [String: Double] = [
                "totalDNA": totalDNAMass,
                "groupCount": Double(transfectionPlasmidGroups.count),
                "ratioGroupCount": Double(transfectionRatioGroups.count),
                "peiMassRatio": peiMassRatio,
                "dnaMassRatio": dnaMassRatio
            ]
            for (groupIndex, group) in transfectionPlasmidGroups.enumerated() {
                inputs["group\(groupIndex)Count"] = Double(group.plasmids.count)
                for (plasmidIndex, plasmid) in group.plasmids.enumerated() {
                    inputs["group\(groupIndex)Plasmid\(plasmidIndex)Ratio"] = plasmid.ratio
                    inputs["group\(groupIndex)Plasmid\(plasmidIndex)Conc"] = plasmid.concentration
                }
            }
            return inputs
        case .custom: return [:]
        }
    }

    private var dilutionSolveResult: DilutionSolveResult? {
        guard case .success(let solved) = solveDilution() else { return nil }
        return solved
    }

    private var calculationResult: CalculatorResult? {
        previewCalculation().successValue
    }

    private func previewCalculation() -> CalculationValidation<CalculatorResult> {
        validateCurrentCalculation()
    }

    private func solveMass() -> CalculationValidation<CalculatorResult> {
        guard let molecularWeightGPerMol = UnitConverter.molecularWeight(molecularWeight, from: mwUnit, to: "g/mol") else {
            return .failure("分子量单位需要是 g/mol、Da 或 kDa。")
        }
        guard let molarityM = UnitConverter.molarity(targetMolarity, from: molarityUnit) else {
            return .failure("目标浓度单位需要是 M、mM、μM 或 nM。")
        }
        guard let volumeL = UnitConverter.volume(massVolumeML, from: massVolumeUnit, to: "L") else {
            return .failure("总体积单位需要是 L、ml 或 μl。")
        }
        guard molecularWeightGPerMol > 0, molarityM >= 0, volumeL >= 0 else {
            return .failure("分子量、浓度和体积必须为有效正数。")
        }
        let massG = molecularWeightGPerMol * molarityM * volumeL
        return .success(CalculatorResult(
            summary: "称量 \(formatCalc(massG)) g",
            detail: "\(formatCalc(molecularWeightGPerMol)) g/mol × \(formatCalc(molarityM)) M × \(formatCalc(volumeL)) L",
            inputs: currentInputs
        ))
    }

    private func solveDilution() -> CalculationValidation<DilutionSolveResult> {
        let c1Raw = Double(stockConcentrationText.trimmingCharacters(in: .whitespaces))
        let v1Raw = Double(stockVolumeText.trimmingCharacters(in: .whitespaces))
        let c2Raw = Double(finalConcentrationText.trimmingCharacters(in: .whitespaces))
        let v2Raw = Double(dilutionVolumeText.trimmingCharacters(in: .whitespaces))

        let values = [c1Raw, v1Raw, c2Raw, v2Raw].compactMap { $0 }
        guard values.count == 3 else { return .failure("请填写 C1、V1、C2、V2 中任意三项，且只留空一项。") }

        let c1 = c1Raw.flatMap { UnitConverter.normalizedConcentration($0, from: stockUnit) }
        let c2 = c2Raw.flatMap { UnitConverter.normalizedConcentration($0, from: finalUnit) }
        let v1ML = v1Raw.flatMap { UnitConverter.volume($0, from: stockVolumeUnit, to: "ml") }
        let v2ML = v2Raw.flatMap { UnitConverter.volume($0, from: dilutionVolumeUnit, to: "ml") }

        if c1Raw != nil && c1 == nil { return .failure("C1 单位不能用于液体稀释，请使用 M、mM、μM、nM 或质量浓度。") }
        if c2Raw != nil && c2 == nil { return .failure("C2 单位不能用于液体稀释，请使用 M、mM、μM、nM 或质量浓度。") }
        if v1Raw != nil && v1ML == nil { return .failure("V1 单位需要是 L、ml 或 μl。") }
        if v2Raw != nil && v2ML == nil { return .failure("V2 单位需要是 L、ml 或 μl。") }

        if c1Raw == nil, let v1ML, let c2, let v2ML, v1ML > 0 {
            let normalizedValue = c2.value * v2ML / v1ML
            guard let display = UnitConverter.displayConcentration(normalizedValue, kind: c2.kind, to: stockUnit) else {
                return .failure("C1 输出单位与已输入浓度单位不兼容。")
            }
            return .success(DilutionSolveResult(c1: normalizedValue, c1Kind: c2.kind, v1ML: v1ML, c2: c2.value, c2Kind: c2.kind, v2ML: v2ML, v1Unit: stockVolumeUnit, v2Unit: dilutionVolumeUnit, missingLabel: "C1", missingValueInDisplayUnit: display, missingUnit: stockUnit))
        }
        if v1Raw == nil, let c1, let c2, let v2ML, c1.value > 0 {
            guard c1.kind == c2.kind else { return .failure("C1 和 C2 必须使用同一类浓度单位，不能混用摩尔浓度和质量浓度。") }
            let valueML = c2.value * v2ML / c1.value
            guard let display = UnitConverter.volume(valueML, from: "ml", to: stockVolumeUnit) else {
                return .failure("V1 输出单位换算失败，请检查体积单位。")
            }
            return .success(DilutionSolveResult(c1: c1.value, c1Kind: c1.kind, v1ML: valueML, c2: c2.value, c2Kind: c2.kind, v2ML: v2ML, v1Unit: stockVolumeUnit, v2Unit: dilutionVolumeUnit, missingLabel: "V1", missingValueInDisplayUnit: display, missingUnit: stockVolumeUnit))
        }
        if c2Raw == nil, let c1, let v1ML, let v2ML, v2ML > 0 {
            let normalizedValue = c1.value * v1ML / v2ML
            guard let display = UnitConverter.displayConcentration(normalizedValue, kind: c1.kind, to: finalUnit) else {
                return .failure("C2 输出单位与已输入浓度单位不兼容。")
            }
            return .success(DilutionSolveResult(c1: c1.value, c1Kind: c1.kind, v1ML: v1ML, c2: normalizedValue, c2Kind: c1.kind, v2ML: v2ML, v1Unit: stockVolumeUnit, v2Unit: dilutionVolumeUnit, missingLabel: "C2", missingValueInDisplayUnit: display, missingUnit: finalUnit))
        }
        if v2Raw == nil, let c1, let v1ML, let c2, c2.value > 0 {
            guard c1.kind == c2.kind else { return .failure("C1 和 C2 必须使用同一类浓度单位，不能混用摩尔浓度和质量浓度。") }
            let valueML = c1.value * v1ML / c2.value
            guard let display = UnitConverter.volume(valueML, from: "ml", to: dilutionVolumeUnit) else {
                return .failure("V2 输出单位换算失败，请检查体积单位。")
            }
            return .success(DilutionSolveResult(c1: c1.value, c1Kind: c1.kind, v1ML: v1ML, c2: c2.value, c2Kind: c2.kind, v2ML: valueML, v1Unit: stockVolumeUnit, v2Unit: dilutionVolumeUnit, missingLabel: "V2", missingValueInDisplayUnit: display, missingUnit: dilutionVolumeUnit))
        }
        return .failure("输入数值不合法，请检查浓度和体积是否大于 0。")
    }

    private func solvePercent() -> CalculationValidation<CalculatorResult> {
        guard percentUnit == "%" else { return .failure("百分比浓度目前需要使用 % 单位。") }
        guard let volumeML = UnitConverter.volume(percentVolumeML, from: percentVolumeUnit, to: "ml") else {
            return .failure("总体积单位需要是 L、ml 或 μl。")
        }
        guard percentValue >= 0, volumeML >= 0 else {
            return .failure("百分比浓度和总体积必须为有效正数。")
        }
        let amountInMLOrG = percentValue / 100.0 * volumeML
        switch percentKind {
        case "v/v":
            guard let displayVolume = UnitConverter.volume(amountInMLOrG, from: "ml", to: percentVolumeUnit) else {
                return .failure("v/v 结果单位需要是 L、ml 或 μl。")
            }
            return .success(CalculatorResult(
                summary: "量取 \(formatCalc(displayVolume)) \(percentVolumeUnit)",
                detail: "v/v：\(formatCalc(percentValue))% × \(formatCalc(volumeML)) ml = \(formatCalc(amountInMLOrG)) ml；定容至 \(formatCalc(percentVolumeML)) \(percentVolumeUnit)",
                inputs: currentInputs
            ))
        default:
            return .success(CalculatorResult(
                summary: "称量 \(formatCalc(amountInMLOrG)) g",
                detail: "w/v：\(formatCalc(percentValue))% × \(formatCalc(volumeML)) ml / 100 ml = \(formatCalc(amountInMLOrG)) g；定容至 \(formatCalc(percentVolumeML)) \(percentVolumeUnit)",
                inputs: currentInputs
            ))
        }
    }

    private func solveTransfection() -> CalculationValidation<CalculatorResult> {
        guard let totalDNAUg = UnitConverter.mass(totalDNAMass, from: totalDNAMassUnit, to: "μg") else {
            return .failure("DNA 总量单位需要是 g、mg、μg 或 ng。")
        }
        let validPlasmids = transfectionPlasmidGroups
            .flatMap(\.plasmids)
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !validPlasmids.isEmpty else { return .failure("至少需要添加一个质粒。") }
        let rawComponents = makeTransfectionComponents(validPlasmids)
        guard totalDNAUg > 0, peiMassRatio > 0, dnaMassRatio > 0 else {
            return .failure("DNA 总量、质粒比例和 PEI:DNA 比例必须为有效正数。")
        }
        guard rawComponents.allSatisfy({ $0.ratio > 0 }) else {
            return .failure("所有质粒比例都必须大于 0。")
        }
        let ratioGroupIDs = Set(transfectionRatioGroups.map(\.id))
        guard rawComponents.allSatisfy({ ratioGroupIDs.contains($0.ratioGroupID) }) else {
            return .failure("质粒比例对象不完整，请检查每个质粒选择的比例计算对象。")
        }
        let normalizedComponents: [TransfectionComponent]
        do {
            normalizedComponents = try rawComponents.map { component in
                guard let concUgPerUL = UnitConverter.massConcentration(component.concentration, from: component.concentrationUnit, to: "μg/μl"), concUgPerUL > 0 else {
                    throw CalculatorUnitError.message("质粒浓度单位需要是 μg/μl、ng/μl、μg/ml 或 mg/ml，且浓度必须大于 0。")
                }
                return TransfectionComponent(name: component.name, ratio: component.ratio, ratioGroupID: component.ratioGroupID, concentrationUgPerUL: concUgPerUL)
            }
        } catch let error as CalculatorUnitError {
            return .failure(error.message)
        } catch {
            return .failure("质粒浓度单位或数值不合法。")
        }

        var lines: [String] = []
        var inputs = currentInputs
        var totalPlasmidVolumeUL: Double = 0
        var plasmidIndex = 0
        for ratioGroup in transfectionRatioGroups {
            let groupComponents = normalizedComponents.filter { $0.ratioGroupID == ratioGroup.id }
            guard !groupComponents.isEmpty else { continue }
            let groupRatioTotal = groupComponents.map(\.ratio).reduce(0, +)
            let ratioText = groupComponents
                .map { "\($0.name) \(formatRatioChoice($0.ratio))" }
                .joined(separator: " : ")
            lines.append("比例对象 \(ratioGroup.name): \(ratioText)")
            for component in groupComponents {
                let massUg = totalDNAUg * component.ratio / groupRatioTotal
                let volumeUL = massUg / component.concentrationUgPerUL
                totalPlasmidVolumeUL += volumeUL
                inputs["plasmid\(plasmidIndex)MassUg"] = massUg
                inputs["plasmid\(plasmidIndex)VolumeUL"] = volumeUL
                lines.append("\(component.name): \(formatCalc(volumeUL)) μl")
                plasmidIndex += 1
            }
        }
        let peiMassUg = totalDNAUg * peiMassRatio / dnaMassRatio
        let peiVolumeUL = peiMassUg
        inputs["totalPlasmidVolumeUL"] = totalPlasmidVolumeUL
        inputs["peiMassUg"] = peiMassUg
        inputs["peiVolumeUL"] = peiVolumeUL

        lines.append("PEI: \(formatCalc(peiVolumeUL)) μl")
        let summary = lines.joined(separator: "\n")
        return .success(CalculatorResult(summary: summary, detail: summary, inputs: inputs))
    }

    private func makeTransfectionComponents(_ plasmids: [TransfectionPlasmidInput]) -> [TransfectionComponentInput] {
        plasmids.map { plasmid in
            TransfectionComponentInput(
                name: plasmid.name.trimmingCharacters(in: .whitespacesAndNewlines),
                ratio: plasmid.ratio,
                ratioGroupID: plasmid.ratioGroupID,
                concentration: plasmid.concentration,
                concentrationUnit: plasmid.concentrationUnit
            )
        }
    }

    private func performCalculation() {
        switch mode {
        case .custom:
            return
        default:
            switch validateCurrentCalculation() {
            case .success(let result):
                let record = CalculationRecord(
                    id: UUID().uuidString,
                    mode: mode.rawValue,
                    label: mode.title,
                    result: result.detail,
                    date: Date(),
                    inputs: result.inputs
                )
                onSave(record)
                hapticSuccess()
            case .failure(let message):
                alertMessage = message
            }
        }
    }

    private func validateCurrentCalculation() -> CalculationValidation<CalculatorResult> {
        switch mode {
        case .mass: return solveMass()
        case .dilution: return solveDilution().flatMap(makeDilutionResult)
        case .percent: return solvePercent()
        case .transfection: return solveTransfection()
        case .custom: return .failure("自定义公式请使用自定义公式页面内的保存入口。")
        }
    }

    private func makeDilutionResult(_ solved: DilutionSolveResult) -> CalculationValidation<CalculatorResult> {
        let solventVolML = max(0, solved.v2ML - solved.v1ML)
        guard let stockDisplay = UnitConverter.volume(solved.v1ML, from: "ml", to: solved.v1Unit),
              let solventDisplay = UnitConverter.volume(solventVolML, from: "ml", to: solved.v2Unit) else {
            return .failure("稀释计算结果单位换算失败，请检查体积单位。")
        }
        return .success(CalculatorResult(
            summary: "\(solved.missingLabel) = \(formatCalc(solved.missingValueInDisplayUnit)) \(solved.missingUnit)",
            detail: "\(solved.missingLabel) = \(formatCalc(solved.missingValueInDisplayUnit)) \(solved.missingUnit)\n取母液 \(formatCalc(stockDisplay)) \(solved.v1Unit) + 溶剂 \(formatCalc(solventDisplay)) \(solved.v2Unit)",
            inputs: currentInputs
        ))
    }

    private func addTransfectionPlasmidGroup() {
        transfectionPlasmidGroups.append(TransfectionPlasmidGroupInput(
            title: "质粒分组 \(transfectionPlasmidGroups.count + 1)",
            plasmids: [TransfectionPlasmidInput(name: "新质粒", ratio: 1, ratioGroupID: defaultTransfectionRatioGroups[0].id, concentration: 1000)]
        ))
    }

    private func addTransfectionPlasmid(to groupID: String) {
        guard let index = transfectionPlasmidGroups.firstIndex(where: { $0.id == groupID }) else { return }
        transfectionPlasmidGroups[index].plasmids.append(TransfectionPlasmidInput(
            name: "质粒 \(transfectionPlasmidGroups[index].plasmids.count + 1)",
            ratio: 1,
            ratioGroupID: transfectionRatioGroups.first?.id ?? defaultTransfectionRatioGroups[0].id,
            concentration: 1000
        ))
    }

    private func removeTransfectionPlasmidGroup(_ groupID: String) {
        transfectionPlasmidGroups.removeAll { $0.id == groupID }
    }

    private func removeTransfectionPlasmid(_ id: String, from groupID: String) {
        guard let groupIndex = transfectionPlasmidGroups.firstIndex(where: { $0.id == groupID }) else { return }
        transfectionPlasmidGroups[groupIndex].plasmids.removeAll { $0.id == id }
    }

    private func updateTransfectionPlasmid(_ plasmid: TransfectionPlasmidInput, in groupID: String) {
        guard let groupIndex = transfectionPlasmidGroups.firstIndex(where: { $0.id == groupID }) else { return }
        if let plasmidIndex = transfectionPlasmidGroups[groupIndex].plasmids.firstIndex(where: { $0.id == plasmid.id }) {
            transfectionPlasmidGroups[groupIndex].plasmids[plasmidIndex] = plasmid
        }
    }

    private func canDeleteTransfectionPlasmid(_ id: String, from groupID: String) -> Bool {
        transfectionPlasmidGroups
            .first(where: { $0.id == groupID })?
            .plasmids
            .contains(where: { $0.id == id }) == true
    }

    private func bindingForTransfectionGroup(_ groupID: String) -> Binding<TransfectionPlasmidGroupInput> {
        Binding(
            get: {
                transfectionPlasmidGroups.first(where: { $0.id == groupID }) ?? TransfectionPlasmidGroupInput(title: "质粒分组", plasmids: [])
            },
            set: { updated in
                if let index = transfectionPlasmidGroups.firstIndex(where: { $0.id == groupID }) {
                    transfectionPlasmidGroups[index] = updated
                }
            }
        )
    }

    private func restoreLegacyTransfectionGroups(inputs: [String: Double]) {
        var restored = transfectionPlasmidGroups
        if let ratio = inputs["psPAX2Ratio"], let concentration = inputs["psPAX2Conc"] {
            if let helperIndex = restored.firstIndex(where: { $0.title.contains("辅助") }) {
                restored[helperIndex].plasmids = [TransfectionPlasmidInput(name: "psPAX2", ratio: ratio, concentration: concentration)]
            }
        }
        if let ratio = inputs["vsvgRatio"], let concentration = inputs["vsvgConc"] {
            if let envelopeIndex = restored.firstIndex(where: { $0.title.contains("包膜") }) {
                restored[envelopeIndex].plasmids = [TransfectionPlasmidInput(name: "pCMV-VSVG", ratio: ratio, concentration: concentration)]
            }
        }
        transfectionPlasmidGroups = restored
    }

    private func updateTransfectionDose(_ dose: TransfectionReferenceDose) {
        if let index = transfectionDoses.firstIndex(where: { $0.id == dose.id }) {
            transfectionDoses[index] = dose
        }
        if selectedTransfectionDoseID == dose.id {
            totalDNAMass = dose.dnaValue
            totalDNAMassUnit = "μg"
        }
    }

    private func deleteTransfectionDose(_ id: String) {
        guard transfectionDoses.count > 1 else { return }
        transfectionDoses.removeAll { $0.id == id }
        if selectedTransfectionDoseID == id, let fallback = transfectionDoses.last {
            selectedTransfectionDoseID = fallback.id
            totalDNAMass = fallback.dnaValue
            totalDNAMassUnit = "μg"
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
                            LabNumberField(title: "分子量 (MW)", value: $molecularWeight, unit: $mwUnit, units: CalculatorUnitOptions.molecularWeight)
                            LabNumberField(title: "目标浓度", value: $targetMolarity, unit: $molarityUnit, units: CalculatorUnitOptions.molarConcentration)
                            LabNumberField(title: "总体积", value: $massVolumeML, unit: $massVolumeUnit, units: CalculatorUnitOptions.volume)
                        case .dilution:
                            LabOptionalNumberField(title: "母液浓度 C1", text: $stockConcentrationText, unit: $stockUnit, units: CalculatorUnitOptions.concentration)
                            LabOptionalNumberField(title: "母液体积 V1", text: $stockVolumeText, unit: $stockVolumeUnit, units: CalculatorUnitOptions.volume)
                            LabOptionalNumberField(title: "目标浓度 C2", text: $finalConcentrationText, unit: $finalUnit, units: CalculatorUnitOptions.concentration)
                            LabOptionalNumberField(title: "总体积 V2", text: $dilutionVolumeText, unit: $dilutionVolumeUnit, units: CalculatorUnitOptions.volume)
                        case .percent:
                            PercentKindPicker(selection: $percentKind)
                            LabNumberField(title: "百分比浓度", value: $percentValue, unit: $percentUnit, units: ["%"])
                            LabNumberField(title: "总体积", value: $percentVolumeML, unit: $percentVolumeUnit, units: CalculatorUnitOptions.volume)
                        case .transfection:
                            TransfectionVesselDosePicker(
                                selectedID: $selectedTransfectionDoseID,
                                doses: transfectionDoses,
                                totalDNAMass: $totalDNAMass,
                                totalDNAMassUnit: $totalDNAMassUnit
                            ) { dose in
                                totalDNAMass = dose.dnaValue
                                totalDNAMassUnit = "μg"
                            }

                            HStack {
                                Text("质粒分组")
                                    .font(.headline)
                                Spacer()
                                Button(action: addTransfectionPlasmidGroup) {
                                    Label("新增分组", systemImage: "plus.circle.fill")
                                        .font(.caption.weight(.semibold))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.teal)
                            }
                            Text("同一「比例计算对象」内的质粒按各自比例分配上方 DNA 总量；不同对象会分开计算。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            ForEach(transfectionPlasmidGroups) { group in
                TransfectionPlasmidGroupSection(
                    group: bindingForTransfectionGroup(group.id),
                    ratioGroups: transfectionRatioGroups,
                    canDeleteGroup: true,
                                    onAdd: { addTransfectionPlasmid(to: group.id) },
                                    onDeleteGroup: { removeTransfectionPlasmidGroup(group.id) },
                                    onDelete: { removeTransfectionPlasmid($0, from: group.id) },
                                    onEdit: { editingPlasmid = TransfectionPlasmidEditContext(groupID: group.id, groupTitle: group.title, plasmid: $0) }
                                )
                            }

                            PEIRatioField(title: "PEI 体积 : DNA 质量", left: $peiMassRatio, right: $dnaMassRatio)
                            TransfectionReferenceTable(
                                doses: $transfectionDoses,
                                onAdd: {
                                    let newDose = TransfectionReferenceDose(
                                        vessel: "新培养皿",
                                        area: "",
                                        dna: "1",
                                        reagent: "",
                                        diluent: "",
                                        medium: ""
                                    )
                                    transfectionDoses.append(newDose)
                                    editingTransfectionDose = newDose
                                },
                                onEdit: { editingTransfectionDose = $0 },
                                onDelete: deleteTransfectionDose
                            )
                        case .custom:
                            EmptyView()
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    // Result
                    VStack(alignment: .leading, spacing: 12) {
                        Text("计算结果")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        if let calculationResult {
                            VStack(alignment: .leading, spacing: 8) {
                                if mode == .transfection {
                                    TransfectionResultLinesView(text: calculationResult.summary)
                                } else {
                                    Text(calculationResult.summary)
                                        .font(.title3.monospacedDigit().weight(.bold))
                                        .foregroundStyle(.teal)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                if mode != .transfection, calculationResult.detail != calculationResult.summary {
                                    Text(calculationResult.detail)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(mode == .dilution ? "请填写 C1、V1、C2、V2 中任意三项" : "点击「计算结果」后生成")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text("计算前会先检查单位并完成换算，单位不兼容时会提示。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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
                                performCalculation()
                            } label: {
                                Label("计算结果", systemImage: "equal.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.labBackground)
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
            .alert("单位或输入不正确", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
            .sheet(item: $editingPlasmid) { context in
                TransfectionPlasmidEditSheet(
                    title: "编辑\(context.groupTitle)",
                    plasmid: context.plasmid,
                    ratioGroups: transfectionRatioGroups,
                    canDelete: canDeleteTransfectionPlasmid(context.plasmid.id, from: context.groupID),
                    onSave: { updated in
                        updateTransfectionPlasmid(updated, in: context.groupID)
                    },
                    onDelete: {
                        removeTransfectionPlasmid(context.plasmid.id, from: context.groupID)
                    }
                )
            }
            .sheet(item: $editingTransfectionDose) { dose in
                TransfectionReferenceDoseEditSheet(
                    dose: dose,
                    canDelete: transfectionDoses.count > 1,
                    onSave: updateTransfectionDose,
                    onDelete: { deleteTransfectionDose(dose.id) }
                )
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
                    stockConcentrationText = formatInputValue(inputs["c1"] ?? stockConcentration)
                    stockVolumeText = inputs["v1"].map(formatInputValue) ?? stockVolumeText
                    finalConcentration = inputs["c2"] ?? finalConcentration
                    finalConcentrationText = formatInputValue(inputs["c2"] ?? finalConcentration)
                    dilutionVolumeML = inputs["v2"] ?? dilutionVolumeML
                    dilutionVolumeText = formatInputValue(inputs["v2"] ?? dilutionVolumeML)
                case .percent:
                    percentValue = inputs["pct"] ?? percentValue
                    percentVolumeML = inputs["vol"] ?? percentVolumeML
                case .transfection:
                    totalDNAMass = inputs["totalDNA"] ?? totalDNAMass
                    let matchingDose = transfectionDoses.first { dose in
                        abs(dose.dnaValue - totalDNAMass) < 0.0001
                    }
                    if let matchingDose {
                        selectedTransfectionDoseID = matchingDose.id
                    }
                    restoreLegacyTransfectionGroups(inputs: inputs)
                    peiMassRatio = inputs["peiMassRatio"] ?? inputs["peiRatio"] ?? peiMassRatio
                    dnaMassRatio = inputs["dnaMassRatio"] ?? dnaMassRatio
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

    private var scaleFactorResult: CalculationValidation<Double> {
        guard let targetML = UnitConverter.volume(targetVolume, from: editedVolumeUnit, to: "ml"),
              let baseML = UnitConverter.volume(template.baseVolume, from: template.volumeUnit, to: "ml") else {
            return .failure("目标体积或基准体积单位需要是 L、ml 或 μl。")
        }
        guard targetML > 0, baseML > 0 else {
            return .failure("目标体积和基准体积必须大于 0。")
        }
        return .success(targetML / baseML)
    }

    private var scaleFactor: Double {
        scaleFactorResult.successValue ?? 1
    }

    private var resultText: String {
        guard case .success(let scaleFactor) = scaleFactorResult else {
            return "目标体积单位不兼容，无法计算。"
        }
        return editingIngredients.map { ing in
            let amount = ing.standardAmount * scaleFactor
            let formatted = amount >= 10 ? String(format: "%.0f", amount) : String(format: "%.2f", amount)
            return "\(ing.name): \(formatted) \(ing.unit)"
        }.joined(separator: "\n")
    }

    private var updatedTemplate: BufferTemplate {
        BufferTemplate(
            id: template.id,
            name: editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? template.name : editedName.trimmingCharacters(in: .whitespacesAndNewlines),
            area: template.area,
            baseVolume: targetVolume,
            volumeUnit: editedVolumeUnit,
            ingredients: editingIngredients
        )
    }

    private func saveTemplate() {
        onUpdate?(updatedTemplate)
        dismiss()
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
                        ForEach(editingIngredients) { ingredient in
                            SwipeDeleteRecipeRow(
                                ingredient: ingredient,
                                scaleFactor: scaleFactor,
                                onEdit: {
                                    editingIngredient = ingredient
                                },
                                onDelete: {
                                    editingIngredients.removeAll { $0.id == ingredient.id }
                                }
                            )
                        }
                        if editingIngredients.isEmpty {
                            Button {
                                showingAddIngredient = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("添加配方成分")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.teal)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

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
                }
                .padding(18)
            }
            .background(Color.labBackground)
            .navigationTitle(editedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveTemplate() }
                        .font(.subheadline.weight(.semibold))
                }
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

private struct SwipeDeleteRecipeRow: View {
    let ingredient: ProtocolIngredient
    let scaleFactor: Double
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isRevealed = false
    @State private var dragOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 44

    private let deleteWidth: CGFloat = 82
    private let revealThreshold: CGFloat = 44

    private var displayedAmount: Double {
        ingredient.isFormula ? ingredient.standardAmount * scaleFactor : ingredient.standardAmount
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                    isRevealed = false
                    dragOffset = 0
                }
                onDelete()
            } label: {
                VStack(spacing: 5) {
                    Image(systemName: "trash.fill")
                        .font(.headline)
                    Text("删除")
                        .font(.caption.weight(.semibold))
                }
                    .foregroundStyle(.white)
                    .frame(width: deleteWidth)
                    .frame(height: contentHeight)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .opacity(currentOffset < -1 ? 1 : 0)
            .allowsHitTesting(isRevealed)
            .zIndex(0)

            HStack {
                Text(ingredient.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(displayedAmount >= 10 ? String(format: "%.0f", displayedAmount) : String(format: "%.2f", displayedAmount)) \(ingredient.unit)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 12)
            .padding(.trailing, 2)
            .background(Color.labPanel)
            .contentShape(Rectangle())
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: RecipeSwipeDeleteHeightKey.self, value: proxy.size.height)
                }
            )
            .offset(x: currentOffset)
            .onTapGesture {
                guard !isRevealed else {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                        isRevealed = false
                        dragOffset = 0
                    }
                    return
                }
                onEdit()
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        guard abs(horizontal) > abs(vertical) else { return }
                        dragOffset = min(max(horizontal, -deleteWidth), deleteWidth)
                    }
                    .onEnded { value in
                        let horizontal = value.predictedEndTranslation.width
                        let vertical = value.translation.height
                        guard abs(horizontal) > abs(vertical) else { return }
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                            let projected = currentOffset + horizontal * 0.18
                            isRevealed = projected < -revealThreshold
                            dragOffset = 0
                        }
                    }
            )
            .zIndex(1)
        }
        .frame(maxWidth: .infinity, minHeight: contentHeight, alignment: .trailing)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onPreferenceChange(RecipeSwipeDeleteHeightKey.self) { height in
            if height > 0 { contentHeight = height }
        }
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var currentOffset: CGFloat {
        let base = isRevealed ? -deleteWidth : 0
        return min(0, max(-deleteWidth, base + dragOffset))
    }
}

private struct RecipeSwipeDeleteHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 44

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Shared number field

struct LabNumberField: View {
    let title: String
    @Binding var value: Double
    @Binding var unit: String
    var units: [String] = UnifiedUnits.forCalculator

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
                ForEach(units, id: \.self) { Text($0) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
        }
    }
}

struct LabOptionalNumberField: View {
    let title: String
    @Binding var text: String
    @Binding var unit: String
    var units: [String] = UnifiedUnits.forCalculator

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            TextField("留空待计算", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .frame(width: 104)
                .textFieldStyle(.roundedBorder)
            Picker("", selection: $unit) {
                ForEach(units, id: \.self) { Text($0) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
        }
    }
}

struct PercentKindPicker: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 8) {
            Text("百分比类型")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Picker("", selection: $selection) {
                Text("w/v").tag("w/v")
                Text("v/v").tag("v/v")
            }
            .pickerStyle(.segmented)
            .frame(width: 132)
        }
        .frame(minHeight: 42)
    }
}

struct LabRatioField: View {
    let title: String
    @Binding var value: Double
    let suffix: String

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
                .keyboardType(.decimalPad)
            Text(suffix)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

struct TransfectionNumberUnitRow: View {
    let title: String
    @Binding var value: Double
    @Binding var unit: String
    var units: [String] = UnifiedUnits.forCalculator

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("0", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.title3.monospacedDigit().weight(.semibold))
                .frame(width: 92)
            CompactValueMenu(selection: $unit, options: units, width: 58, tint: .teal)
        }
        .frame(minHeight: 42)
    }
}

private let transfectionRatioChoices: [Double] = [0.5, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

private func formatRatioChoice(_ value: Double) -> String {
    value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
}

struct TransfectionRatioPicker: View {
    @Binding var value: Double
    var width: CGFloat = 36

    var body: some View {
        Menu {
            ForEach(transfectionRatioChoices, id: \.self) { ratio in
                Button(formatRatioChoice(ratio)) {
                    value = ratio
                }
            }
        } label: {
            Text(formatRatioChoice(value))
                .font(.body.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            .foregroundStyle(.primary)
            .frame(width: width, alignment: .trailing)
        }
    }
}

struct CompactValueMenu: View {
    @Binding var selection: String
    let options: [String]
    var width: CGFloat
    var tint: Color = .teal

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) {
                    selection = option
                }
            }
        } label: {
            Text(selection)
                .font(.title3.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            .foregroundStyle(tint)
            .frame(width: width, alignment: .leading)
        }
    }
}

struct TransfectionPlainNumberField: View {
    @Binding var value: Double
    var width: CGFloat = 76
    var font: Font = .body.monospacedDigit().weight(.semibold)

    var body: some View {
        TextField("0", value: $value, format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .font(font)
            .frame(width: width)
    }
}

struct PEIRatioField: View {
    let title: String
    @Binding var left: Double
    @Binding var right: Double

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            TransfectionRatioPicker(value: $left, width: 34)
            Text(":")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
            TransfectionRatioPicker(value: $right, width: 34)
        }
        .frame(minHeight: 42)
    }
}

struct TransfectionRatioConcentrationLine: View {
    @Binding var ratio: Double
    @Binding var concentration: Double
    @Binding var unit: String

    var body: some View {
        HStack(spacing: 6) {
            Text("比例")
                .font(.caption)
                .foregroundStyle(.secondary)
            TransfectionRatioPicker(value: $ratio)
            Spacer(minLength: 6)
            Text("浓度")
                .font(.caption)
                .foregroundStyle(.secondary)
            TransfectionPlainNumberField(value: $concentration, width: 82)
            CompactValueMenu(selection: $unit, options: CalculatorUnitOptions.massConcentration, width: 64, tint: .teal)
        }
        .frame(minHeight: 36)
    }
}

struct LabRatioConcentrationField: View {
    let title: String
    @Binding var name: String
    @Binding var ratio: Double
    @Binding var concentration: Double
    @Binding var unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                TextField("质粒名称", text: $name)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.trailing)
            }
            TransfectionRatioConcentrationLine(ratio: $ratio, concentration: $concentration, unit: $unit)
        }
        .padding(12)
        .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct TransfectionPlasmidRow: View {
    @Binding var plasmid: TransfectionPlasmidInput
    let ratioGroups: [TransfectionRatioGroup]
    let onEdit: () -> Void

    private var selectedRatioGroupName: String {
        ratioGroups.first { $0.id == plasmid.ratioGroupID }?.name ?? "未选择"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(plasmid.name.isEmpty ? "未命名质粒" : plasmid.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("编辑质粒")
            }
            HStack(alignment: .firstTextBaseline) {
                Text("比例")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TransfectionRatioPicker(value: $plasmid.ratio, width: 34)
                Spacer()
                Text("浓度")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TransfectionPlainNumberField(value: $plasmid.concentration, width: 74, font: .title3.monospacedDigit().weight(.bold))
                CompactValueMenu(selection: $plasmid.concentrationUnit, options: CalculatorUnitOptions.massConcentration, width: 64, tint: .teal)
            }
            HStack(spacing: 6) {
                Text("比例计算对象")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Menu {
                    ForEach(ratioGroups) { ratioGroup in
                        Button(ratioGroup.name) {
                            plasmid.ratioGroupID = ratioGroup.id
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedRatioGroupName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.teal)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.labPanel.opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct TransfectionPlasmidGroupSection: View {
    @Binding var group: TransfectionPlasmidGroupInput
    let ratioGroups: [TransfectionRatioGroup]
    let canDeleteGroup: Bool
    let onAdd: () -> Void
    let onDeleteGroup: () -> Void
    let onDelete: (String) -> Void
    let onEdit: (TransfectionPlasmidInput) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("分组名称", text: $group.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.teal)
                Button(role: .destructive, action: onDeleteGroup) {
                    Image(systemName: "trash")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .disabled(!canDeleteGroup)
            }

            if group.plasmids.isEmpty {
                Button(action: onAdd) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("添加质粒")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.teal)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            } else {
                List {
                    ForEach($group.plasmids) { $plasmid in
                        TransfectionPlasmidRow(
                            plasmid: $plasmid,
                            ratioGroups: ratioGroups,
                            onEdit: { onEdit(plasmid) }
                        )
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDelete(plasmid.id)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(group.plasmids.count) * 92)
            }
        }
        .padding(12)
        .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct TransfectionPlasmidEditSheet: View {
    let title: String
    @State private var plasmid: TransfectionPlasmidInput
    let ratioGroups: [TransfectionRatioGroup]
    let canDelete: Bool
    let onSave: (TransfectionPlasmidInput) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        plasmid: TransfectionPlasmidInput,
        ratioGroups: [TransfectionRatioGroup],
        canDelete: Bool,
        onSave: @escaping (TransfectionPlasmidInput) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.title = title
        _plasmid = State(initialValue: plasmid)
        self.ratioGroups = ratioGroups
        self.canDelete = canDelete
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("质粒名称")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("质粒名称", text: $plasmid.name)
                        .font(.title3.weight(.semibold))
                        .textFieldStyle(.roundedBorder)
                }
                .padding(16)
                .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                VStack(spacing: 12) {
                    HStack {
                        Text("比例")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        TransfectionRatioPicker(value: $plasmid.ratio, width: 48)
                    }
                    HStack {
                        Text("比例计算对象")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Picker("", selection: $plasmid.ratioGroupID) {
                            ForEach(ratioGroups) { ratioGroup in
                                Text(ratioGroup.name).tag(ratioGroup.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    HStack {
                        Text("浓度")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        TransfectionPlainNumberField(value: $plasmid.concentration, width: 96)
                        CompactValueMenu(selection: $plasmid.concentrationUnit, options: CalculatorUnitOptions.massConcentration, width: 64, tint: .teal)
                    }
                }
                .padding(16)
                .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Label("删除这个质粒", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!canDelete)

                Spacer()
            }
            .padding(18)
            .background(Color.labBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(plasmid)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct TransfectionReferenceDose: Identifiable {
    let id: String
    var vessel: String
    var area: String
    var dna: String
    var reagent: String
    var diluent: String
    var medium: String

    init(id: String = UUID().uuidString, vessel: String, area: String, dna: String, reagent: String, diluent: String, medium: String) {
        self.id = id
        self.vessel = vessel
        self.area = area
        self.dna = dna
        self.reagent = reagent
        self.diluent = diluent
        self.medium = medium
    }

    var dnaValue: Double {
        Double(dna) ?? 0
    }
}

private let defaultTransfectionReferenceDoses: [TransfectionReferenceDose] = [
    TransfectionReferenceDose(vessel: "96 孔板", area: "0.3", dna: "0.1", reagent: "0.1", diluent: "10", medium: "100 μl"),
    TransfectionReferenceDose(vessel: "48 孔板", area: "0.7", dna: "0.2", reagent: "0.3", diluent: "20", medium: "200 μl"),
    TransfectionReferenceDose(vessel: "24 孔板", area: "1.9", dna: "0.5", reagent: "1", diluent: "50", medium: "500 μl"),
    TransfectionReferenceDose(vessel: "12 孔板", area: "3.8", dna: "1", reagent: "2", diluent: "50", medium: "1 ml"),
    TransfectionReferenceDose(vessel: "6 孔板", area: "10", dna: "2", reagent: "4", diluent: "100", medium: "2 ml"),
    TransfectionReferenceDose(vessel: "25 cm² 瓶", area: "21", dna: "4", reagent: "8", diluent: "200", medium: "4 ml"),
    TransfectionReferenceDose(vessel: "75 cm² 瓶", area: "58", dna: "10", reagent: "20", diluent: "500", medium: "10 ml")
]

struct TransfectionVesselDosePicker: View {
    @Binding var selectedID: String
    let doses: [TransfectionReferenceDose]
    @Binding var totalDNAMass: Double
    @Binding var totalDNAMassUnit: String
    let onSelect: (TransfectionReferenceDose) -> Void

    private var selectedDose: TransfectionReferenceDose {
        doses.first { $0.id == selectedID } ?? doses.last ?? defaultTransfectionReferenceDoses.last!
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("培养皿")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Menu {
                    ForEach(doses) { dose in
                        Button {
                            selectedID = dose.id
                            onSelect(dose)
                        } label: {
                            Text("\(dose.vessel) · DNA \(dose.dna) μg")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedDose.vessel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.teal)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            VStack(alignment: .leading, spacing: 6) {
                Text("DNA 总量")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    TransfectionPlainNumberField(value: $totalDNAMass, width: 64, font: .title3.monospacedDigit().weight(.bold))
                    CompactValueMenu(selection: $totalDNAMassUnit, options: ["g", "mg", "μg", "ng"], width: 38, tint: .teal)
                }
            }
            .frame(width: 116, alignment: .leading)
        }
        .padding(12)
        .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct TransfectionReferenceTable: View {
    @Binding var doses: [TransfectionReferenceDose]
    let onAdd: () -> Void
    let onEdit: (TransfectionReferenceDose) -> Void
    let onDelete: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("不同培养容器转染用量")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: onAdd) {
                    Label("添加", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.teal)
            }
            Text("仅供参考，实际计算仍按上方输入值执行。")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    TransfectionReferenceRow(
                        vessel: "培养皿",
                        area: "cm²",
                        dna: "DNA μg",
                        reagent: "试剂 μl",
                        diluent: "稀释液 μl",
                        medium: "培养基",
                        isHeader: true
                    )
                    ForEach(doses) { dose in
                        TransfectionReferenceRow(
                            vessel: dose.vessel,
                            area: dose.area,
                            dna: dose.dna,
                            reagent: dose.reagent,
                            diluent: dose.diluent,
                            medium: dose.medium,
                            onTap: { onEdit(dose) }
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct TransfectionReferenceDoseEditSheet: View {
    @State private var dose: TransfectionReferenceDose
    let canDelete: Bool
    let onSave: (TransfectionReferenceDose) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    init(
        dose: TransfectionReferenceDose,
        canDelete: Bool,
        onSave: @escaping (TransfectionReferenceDose) -> Void,
        onDelete: @escaping () -> Void
    ) {
        _dose = State(initialValue: dose)
        self.canDelete = canDelete
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    TransfectionReferenceEditField(title: "培养皿", text: $dose.vessel)
                    TransfectionReferenceEditField(title: "表面积 cm²", text: $dose.area)
                    TransfectionReferenceEditField(title: "DNA μg", text: $dose.dna)
                    TransfectionReferenceEditField(title: "转染试剂 μl", text: $dose.reagent)
                    TransfectionReferenceEditField(title: "稀释液 μl", text: $dose.diluent)
                    TransfectionReferenceEditField(title: "培养基总量", text: $dose.medium)

                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("删除这条参考", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(!canDelete)
                }
                .padding(18)
            }
            .background(Color.labBackground)
            .navigationTitle("编辑参考")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(dose)
                        dismiss()
                    }
                    .disabled(dose.vessel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct TransfectionReferenceEditField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(title, text: $text)
                .font(.title3.weight(.semibold))
                .textFieldStyle(.roundedBorder)
        }
        .padding(14)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct TransfectionReferenceRow: View {
    let vessel: String
    let area: String
    let dna: String
    let reagent: String
    let diluent: String
    let medium: String
    var isHeader = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            referenceCell(vessel, width: 88, alignment: .leading)
            referenceCell(area, width: 52)
            referenceCell(dna, width: 58)
            referenceCell(reagent, width: 64)
            referenceCell(diluent, width: 70)
            referenceCell(medium, width: 62)
        }
        .font(isHeader ? .caption2.weight(.semibold) : .caption2.monospacedDigit())
        .foregroundStyle(isHeader ? .primary : .secondary)
        .background(isHeader ? Color.labPanel.opacity(0.9) : Color.labPanel.opacity(0.45))
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    private func referenceCell(_ text: String, width: CGFloat, alignment: Alignment = .center) -> some View {
        Text(text)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .frame(width: width, height: 28, alignment: alignment)
            .padding(.horizontal, 3)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 0.5)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.12))
                    .frame(height: 0.5)
            }
    }
}

struct TransfectionResultLinesView: View {
    let text: String

    private var lines: [String] {
        text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                TransfectionResultLineView(line: line)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct TransfectionResultLineView: View {
    let line: String

    private var parts: (label: String, value: String, unit: String)? {
        guard !line.hasPrefix("比例对象 ") else { return nil }
        let split = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
        guard split.count == 2 else { return nil }
        let label = String(split[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let valueParts = split[1].split(separator: " ", omittingEmptySubsequences: true)
        guard valueParts.count >= 2 else { return nil }
        return (
            label,
            String(valueParts[0]),
            valueParts.dropFirst().joined(separator: " ")
        )
    }

    var body: some View {
        if let parts {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(parts.label):")
                    .font(.subheadline.weight(.semibold))
                Text(parts.value)
                    .font(.title3.monospacedDigit().weight(.bold))
                Text(parts.unit)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }
            .foregroundStyle(.teal)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(line)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.teal)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct TransfectionPlasmidInput: Identifiable, Hashable {
    let id: String
    var name: String
    var ratio: Double
    var ratioGroupID: String
    var concentration: Double
    var concentrationUnit: String

    init(id: String = UUID().uuidString, name: String, ratio: Double, ratioGroupID: String = "transfection-system", concentration: Double, concentrationUnit: String = "ng/μl") {
        self.id = id
        self.name = name
        self.ratio = ratio
        self.ratioGroupID = ratioGroupID
        self.concentration = concentration
        self.concentrationUnit = concentrationUnit
    }
}

struct TransfectionRatioGroup: Identifiable, Hashable {
    let id: String
    var name: String
}

private let defaultTransfectionRatioGroups: [TransfectionRatioGroup] = [
    TransfectionRatioGroup(id: "transfection-system", name: "本次转染体系"),
    TransfectionRatioGroup(id: "target-only", name: "目的质粒组合"),
    TransfectionRatioGroup(id: "helper-envelope", name: "辅助/包膜组合")
]

struct TransfectionPlasmidGroupInput: Identifiable {
    let id: String
    var title: String
    var plasmids: [TransfectionPlasmidInput]

    init(id: String = UUID().uuidString, title: String, plasmids: [TransfectionPlasmidInput]) {
        self.id = id
        self.title = title
        self.plasmids = plasmids
    }
}

private let defaultTransfectionPlasmidGroups: [TransfectionPlasmidGroupInput] = [
    TransfectionPlasmidGroupInput(
        title: "目的质粒",
        plasmids: [TransfectionPlasmidInput(name: "pLVX-目的基因", ratio: 4, concentration: 1000)]
    ),
    TransfectionPlasmidGroupInput(
        title: "辅助质粒",
        plasmids: [TransfectionPlasmidInput(name: "psPAX2", ratio: 3, concentration: 1000)]
    ),
    TransfectionPlasmidGroupInput(
        title: "包膜质粒",
        plasmids: [TransfectionPlasmidInput(name: "pCMV-VSVG", ratio: 1, concentration: 1000)]
    )
]

private struct TransfectionPlasmidEditContext: Identifiable {
    let id = UUID()
    let groupID: String
    let groupTitle: String
    let plasmid: TransfectionPlasmidInput
}

private struct TransfectionComponentInput {
    let name: String
    let ratio: Double
    let ratioGroupID: String
    let concentration: Double
    let concentrationUnit: String
}

private struct TransfectionComponent {
    let name: String
    let ratio: Double
    let ratioGroupID: String
    let concentrationUgPerUL: Double
}

private struct DilutionSolveResult {
    let c1: Double
    let c1Kind: ConcentrationKind
    let v1ML: Double
    let c2: Double
    let c2Kind: ConcentrationKind
    let v2ML: Double
    let v1Unit: String
    let v2Unit: String
    let missingLabel: String
    let missingValueInDisplayUnit: Double
    let missingUnit: String
}

private enum ConcentrationKind {
    case molar
    case mass
}

private struct NormalizedConcentration {
    let value: Double
    let kind: ConcentrationKind
}

private struct CalculatorResult {
    let summary: String
    let detail: String
    let inputs: [String: Double]
}

private enum CalculationValidation<Value> {
    case success(Value)
    case failure(String)

    var successValue: Value? {
        if case .success(let value) = self { return value }
        return nil
    }

    func map<T>(_ transform: (Value) -> T) -> CalculationValidation<T> {
        switch self {
        case .success(let value): return .success(transform(value))
        case .failure(let message): return .failure(message)
        }
    }

    func flatMap<T>(_ transform: (Value) -> CalculationValidation<T>) -> CalculationValidation<T> {
        switch self {
        case .success(let value): return transform(value)
        case .failure(let message): return .failure(message)
        }
    }
}

private enum CalculatorUnitOptions {
    static let volume = ["ml", "μl", "L"]
    static let mass = ["g", "mg", "μg", "ng", "kg"]
    static let molarConcentration = ["M", "mM", "μM", "nM"]
    static let massConcentration = ["mg/ml", "μg/ml", "μg/μl", "ng/μl"]
    static let concentration = molarConcentration + massConcentration
    static let molecularWeight = ["g/mol", "Da", "kDa"]
}

private enum CalculatorUnitError: Error {
    case message(String)

    var message: String {
        switch self {
        case .message(let value): return value
        }
    }
}

private enum UnitConverter {
    static func molecularWeight(_ value: Double, from: String, to: String) -> Double? {
        guard to == "g/mol", let factor = molecularWeightToGPerMol[from] else { return nil }
        return value * factor
    }

    static func volume(_ value: Double, from: String, to: String) -> Double? {
        guard let fromFactor = volumeToML[from], let toFactor = volumeToML[to] else { return nil }
        return value * fromFactor / toFactor
    }

    static func volumeFactor(from: String, to: String) -> Double? {
        guard let fromFactor = volumeToML[from], let toFactor = volumeToML[to] else { return nil }
        return fromFactor / toFactor
    }

    static func mass(_ value: Double, from: String, to: String) -> Double? {
        guard let fromFactor = massToUG[from], let toFactor = massToUG[to] else { return nil }
        return value * fromFactor / toFactor
    }

    static func molarity(_ value: Double, from: String) -> Double? {
        concentration(value, from: from, to: "M")
    }

    static func concentration(_ value: Double, from: String, to: String) -> Double? {
        if let fromFactor = molarToM[from], let toFactor = molarToM[to] {
            return value * fromFactor / toFactor
        }
        if let fromFactor = massConcToUGPerUL[from], let toFactor = massConcToUGPerUL[to] {
            return value * fromFactor / toFactor
        }
        return nil
    }

    static func normalizedConcentration(_ value: Double, from: String) -> NormalizedConcentration? {
        if let molar = concentration(value, from: from, to: "M") {
            return NormalizedConcentration(value: molar, kind: .molar)
        }
        if let mass = massConcentration(value, from: from, to: "μg/μl") {
            return NormalizedConcentration(value: mass, kind: .mass)
        }
        return nil
    }

    static func displayConcentration(_ value: Double, kind: ConcentrationKind, to: String) -> Double? {
        switch kind {
        case .molar:
            return concentration(value, from: "M", to: to)
        case .mass:
            return massConcentration(value, from: "μg/μl", to: to)
        }
    }

    static func massConcentration(_ value: Double, from: String, to: String) -> Double? {
        guard let fromFactor = massConcToUGPerUL[from], let toFactor = massConcToUGPerUL[to] else { return nil }
        return value * fromFactor / toFactor
    }

    private static let volumeToML: [String: Double] = [
        "L": 1000,
        "ml": 1,
        "μl": 0.001
    ]

    private static let molecularWeightToGPerMol: [String: Double] = [
        "g/mol": 1,
        "Da": 1,
        "kDa": 1000
    ]

    private static let massToUG: [String: Double] = [
        "kg": 1_000_000_000,
        "g": 1_000_000,
        "mg": 1_000,
        "μg": 1,
        "ng": 0.001
    ]

    private static let molarToM: [String: Double] = [
        "M": 1,
        "mM": 0.001,
        "μM": 0.000001,
        "nM": 0.000000001
    ]

    private static let massConcToUGPerUL: [String: Double] = [
        "μg/μl": 1,
        "ng/μl": 0.001,
        "μg/ml": 0.001,
        "mg/ml": 1
    ]
}

private func formatInputValue(_ value: Double) -> String {
    value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.4g", value)
}

// MARK: - Calculator mode enum

enum CalculatorMode: String, CaseIterable, Identifiable {
    case mass = "质量"
    case dilution = "稀释"
    case percent = "%"
    case transfection = "转染"
    case custom = "自定义"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mass: return "质量浓度"
        case .dilution: return "液体稀释"
        case .percent: return "百分比浓度"
        case .transfection: return "PEI 转染配方"
        case .custom: return "自定义公式"
        }
    }

    var subtitle: String {
        switch self {
        case .mass: return "MW × M × L → 称量质量"
        case .dilution: return "C1V1 = C2V2 → 取母液量"
        case .percent: return "w/v 或 v/v → 溶质质量"
        case .transfection: return "DNA 比例 + 浓度 → 质粒/PEI 体积"
        case .custom: return "自由定义公式与变量 → 即时计算"
        }
    }

    var icon: String {
        switch self {
        case .mass: return "scalemass"
        case .dilution: return "drop.triangle"
        case .percent: return "percent"
        case .transfection: return "waveform.path.ecg.rectangle"
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
    @State private var vendor = ""
    @State private var category = ""
    @State private var notes = ""

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

                Section("可选备注") {
                    TextField("厂商", text: $vendor)
                    TextField("品类", text: $category)
                    TextField("备注", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    Button("添加") {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedName.isEmpty, let amountValue = Double(amount), amountValue > 0 else { return }
                        let ingredient = ProtocolIngredient(
                            name: trimmedName,
                            standardAmount: amountValue,
                            unit: unit,
                            isFormula: isFormula,
                            vendor: vendor.trimmingCharacters(in: .whitespacesAndNewlines),
                            category: category.trimmingCharacters(in: .whitespacesAndNewlines),
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
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
    @State private var vendor: String
    @State private var category: String
    @State private var notes: String

    init(ingredient: ProtocolIngredient, onSave: @escaping (ProtocolIngredient) -> Void, onDelete: (() -> Void)? = nil) {
        self.ingredient = ingredient
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: ingredient.name)
        _amount = State(initialValue: String(ingredient.standardAmount))
        _unit = State(initialValue: ingredient.unit)
        _isFormula = State(initialValue: ingredient.isFormula)
        _vendor = State(initialValue: ingredient.vendor)
        _category = State(initialValue: ingredient.category)
        _notes = State(initialValue: ingredient.notes)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Double(amount) != nil
    }

    private func saveIngredient() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let amountValue = Double(amount), amountValue > 0 else { return }
        let updated = ProtocolIngredient(
            id: ingredient.id,
            name: trimmedName,
            standardAmount: amountValue,
            unit: unit,
            isFormula: isFormula,
            vendor: vendor.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        onSave(updated)
        dismiss()
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

                Section("可选备注") {
                    TextField("厂商", text: $vendor)
                    TextField("品类", text: $category)
                    TextField("备注", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    if let onDelete = onDelete {
                        Button("删除", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
                    }
                }
            }
            .navigationTitle("编辑成分")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveIngredient() }
                        .disabled(!canSave)
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

struct CustomVariableField: Identifiable {
    let id = UUID()
    var name: String
    var value: String
    var unit: String
}

struct CustomCalculationStep: Identifiable, Codable {
    var id: String
    var outputName: String
    var formula: String
    var outputUnit: String

    init(id: String = UUID().uuidString, outputName: String, formula: String, outputUnit: String) {
        self.id = id
        self.outputName = outputName
        self.formula = formula
        self.outputUnit = outputUnit
    }
}

struct CustomResultField: Identifiable, Codable {
    var id: String
    var variableName: String
    var label: String
    var displayUnit: String

    init(id: String = UUID().uuidString, variableName: String, label: String, displayUnit: String) {
        self.id = id
        self.variableName = variableName
        self.label = label
        self.displayUnit = displayUnit
    }
}

struct CustomReferenceRow: Identifiable, Codable {
    var id: String
    var name: String
    var condition: String
    var value: String
    var note: String

    init(id: String = UUID().uuidString, name: String, condition: String, value: String, note: String) {
        self.id = id
        self.name = name
        self.condition = condition
        self.value = value
        self.note = note
    }
}

struct SavedFormula: Identifiable, Codable {
    let id: String
    var label: String
    var formula: String
    var variableNames: [String]
    var variableValues: [String]
    var variableUnits: [String]
    var resultUnit: String
    var steps: [CustomCalculationStep]? = nil
    var resultFields: [CustomResultField]? = nil
    var referenceRows: [CustomReferenceRow]? = nil

    var workflowSteps: [CustomCalculationStep] {
        if let steps, !steps.isEmpty { return steps }
        return [CustomCalculationStep(outputName: "result", formula: formula, outputUnit: resultUnit)]
    }

    var workflowResultFields: [CustomResultField] {
        if let resultFields, !resultFields.isEmpty { return resultFields }
        return [CustomResultField(variableName: "result", label: label, displayUnit: resultUnit)]
    }

    var workflowReferenceRows: [CustomReferenceRow] {
        referenceRows ?? []
    }
}

private struct CustomWorkflowLine: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let unit: String

    var valueText: String {
        unit.isEmpty ? CustomFormulaUnit.format(value) : "\(CustomFormulaUnit.format(value)) \(unit)"
    }
}

private struct CustomWorkflowOutput {
    let lines: [CustomWorkflowLine]
    let values: [String: Double]
    let units: [String: String]

    var clipboardText: String {
        lines.map { "\($0.label): \($0.valueText)" }.joined(separator: "\n")
    }
}

private enum CustomFormulaUnit {
    static var selectableUnits: [String] {
        unique(
            [""] +
            CalculatorUnitOptions.volume +
            CalculatorUnitOptions.mass +
            CalculatorUnitOptions.concentration +
            CalculatorUnitOptions.molecularWeight +
            ["%"] +
            UnifiedUnits.forCalculator
        )
    }

    static func normalize(_ value: Double, unit rawUnit: String) -> CalculationValidation<(value: Double, unit: String)> {
        let unit = rawUnit.trimmingCharacters(in: .whitespaces)
        guard !unit.isEmpty else { return .success((value, "")) }
        if unit == "%" { return .success((value / 100, "")) }

        if CalculatorUnitOptions.volume.contains(unit) {
            guard let converted = UnitConverter.volume(value, from: unit, to: "μl") else {
                return .failure("单位 \(unit) 不能作为体积单位换算。")
            }
            return .success((converted, "μl"))
        }

        if CalculatorUnitOptions.mass.contains(unit) {
            guard let converted = UnitConverter.mass(value, from: unit, to: "μg") else {
                return .failure("单位 \(unit) 不能作为质量单位换算。")
            }
            return .success((converted, "μg"))
        }

        if CalculatorUnitOptions.molarConcentration.contains(unit) {
            guard let converted = UnitConverter.concentration(value, from: unit, to: "M") else {
                return .failure("单位 \(unit) 不能作为摩尔浓度单位换算。")
            }
            return .success((converted, "M"))
        }

        if CalculatorUnitOptions.massConcentration.contains(unit) {
            guard let converted = UnitConverter.massConcentration(value, from: unit, to: "μg/μl") else {
                return .failure("单位 \(unit) 不能作为质量浓度单位换算。")
            }
            return .success((converted, "μg/μl"))
        }

        if CalculatorUnitOptions.molecularWeight.contains(unit) {
            guard let converted = UnitConverter.molecularWeight(value, from: unit, to: "g/mol") else {
                return .failure("单位 \(unit) 不能作为分子量单位换算。")
            }
            return .success((converted, "g/mol"))
        }

        return .success((value, unit))
    }

    static func convert(_ value: Double, from sourceUnit: String, to targetUnit: String) -> CalculationValidation<Double> {
        let source = sourceUnit.trimmingCharacters(in: .whitespaces)
        let target = targetUnit.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return .success(value) }
        if source == target { return .success(value) }
        if source.isEmpty && target == "%" { return .success(value * 100) }

        if CalculatorUnitOptions.volume.contains(source), CalculatorUnitOptions.volume.contains(target),
           let converted = UnitConverter.volume(value, from: source, to: target) {
            return .success(converted)
        }

        if CalculatorUnitOptions.mass.contains(source), CalculatorUnitOptions.mass.contains(target),
           let converted = UnitConverter.mass(value, from: source, to: target) {
            return .success(converted)
        }

        if CalculatorUnitOptions.concentration.contains(source), CalculatorUnitOptions.concentration.contains(target),
           let converted = UnitConverter.concentration(value, from: source, to: target) {
            return .success(converted)
        }

        if source == "g/mol" {
            if target == "Da" { return .success(value) }
            if target == "kDa" { return .success(value / 1000) }
        }

        if source == target {
            return .success(value)
        }

        return .failure("不能从 \(source.isEmpty ? "无单位" : source) 换算到 \(target)。")
    }

    static func format(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 100 {
            return trimZeros(String(format: "%.0f", value))
        } else if absValue >= 10 {
            return trimZeros(String(format: "%.1f", value))
        } else if absValue >= 1 {
            return trimZeros(String(format: "%.2f", value))
        } else {
            return trimZeros(String(format: "%.3g", value))
        }
    }

    private static func unique(_ units: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for unit in units where !seen.contains(unit) {
            seen.insert(unit)
            result.append(unit)
        }
        return result
    }

    private static func trimZeros(_ text: String) -> String {
        guard text.contains(".") else { return text }
        return text.replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }
}

private enum CustomWorkflowEngine {
    static func evaluate(
        variables: [CustomVariableField],
        steps: [CustomCalculationStep],
        resultFields: [CustomResultField]
    ) -> CalculationValidation<CustomWorkflowOutput> {
        var values: [String: Double] = [:]
        var units: [String: String] = [:]

        for variable in variables {
            let name = variable.name.trimmingCharacters(in: .whitespaces)
            let valueText = variable.value.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty || valueText.isEmpty else {
                return .failure("变量名不能为空。")
            }
            guard !name.isEmpty else { continue }
            guard values[name] == nil else {
                return .failure("变量 \(name) 重复，请使用唯一变量名。")
            }
            guard let rawValue = Double(valueText.replacingOccurrences(of: ",", with: "")) else {
                return .failure("变量 \(name) 的数值不合法。")
            }

            switch CustomFormulaUnit.normalize(rawValue, unit: variable.unit) {
            case .success(let normalized):
                values[name] = normalized.value
                units[name] = normalized.unit
            case .failure(let message):
                return .failure(message)
            }
        }

        guard !values.isEmpty else {
            return .failure("至少需要一个有效输入变量。")
        }

        let activeSteps = steps.filter {
            !$0.outputName.trimmingCharacters(in: .whitespaces).isEmpty ||
            !$0.formula.trimmingCharacters(in: .whitespaces).isEmpty
        }
        guard !activeSteps.isEmpty else {
            return .failure("至少需要一个计算步骤。")
        }

        for step in activeSteps {
            let outputName = step.outputName.trimmingCharacters(in: .whitespaces)
            let expression = step.formula.trimmingCharacters(in: .whitespaces)
            guard !outputName.isEmpty else {
                return .failure("计算步骤的输出变量不能为空。")
            }
            guard values[outputName] == nil else {
                return .failure("输出变量 \(outputName) 已存在，请使用唯一变量名。")
            }
            guard !expression.isEmpty else {
                return .failure("计算步骤 \(outputName) 的公式不能为空。")
            }
            guard let rawValue = ExpressionEvaluator.evaluate(expression, variables: values), rawValue.isFinite else {
                return .failure("步骤 \(outputName) 无法计算，请检查变量名、括号和运算符。")
            }

            switch CustomFormulaUnit.normalize(rawValue, unit: step.outputUnit) {
            case .success(let normalized):
                values[outputName] = normalized.value
                units[outputName] = normalized.unit
            case .failure(let message):
                return .failure("步骤 \(outputName)：\(message)")
            }
        }

        let activeResults = resultFields.filter {
            !$0.variableName.trimmingCharacters(in: .whitespaces).isEmpty ||
            !$0.label.trimmingCharacters(in: .whitespaces).isEmpty
        }
        guard !activeResults.isEmpty else {
            return .failure("至少需要选择一个展示结果。")
        }

        var lines: [CustomWorkflowLine] = []
        for field in activeResults {
            let variableName = field.variableName.trimmingCharacters(in: .whitespaces)
            guard !variableName.isEmpty else {
                return .failure("展示结果的变量名不能为空。")
            }
            guard let value = values[variableName] else {
                return .failure("展示结果 \(variableName) 不存在，请先在输入或步骤中定义。")
            }

            let sourceUnit = units[variableName] ?? ""
            let displayUnit = field.displayUnit.trimmingCharacters(in: .whitespaces)
            let targetUnit = displayUnit.isEmpty ? sourceUnit : displayUnit
            let converted: Double
            switch CustomFormulaUnit.convert(value, from: sourceUnit, to: targetUnit) {
            case .success(let value):
                converted = value
            case .failure(let message):
                return .failure("展示结果 \(variableName)：\(message)")
            }

            let label = field.label.trimmingCharacters(in: .whitespaces).isEmpty ? variableName : field.label
            lines.append(CustomWorkflowLine(label: label, value: converted, unit: targetUnit))
        }

        return .success(CustomWorkflowOutput(lines: lines, values: values, units: units))
    }
}

private struct CustomUnitPicker: View {
    @Binding var selection: String
    var tint: Color = .teal

    var body: some View {
        Picker("", selection: $selection) {
            Text("无单位").tag("")
            ForEach(CustomFormulaUnit.selectableUnits.filter { !$0.isEmpty }, id: \.self) { unit in
                Text(unit).tag(unit)
            }
        }
        .pickerStyle(.menu)
        .tint(tint)
        .labelsHidden()
        .fixedSize()
    }
}

struct CustomReferenceTableSection: View {
    @Binding var rows: [CustomReferenceRow]
    let onAdd: () -> Void
    let onEdit: (CustomReferenceRow) -> Void
    let onDelete: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("参考表格")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onAdd) {
                    Label("添加", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.teal)
            }

            if rows.isEmpty {
                Text("可添加培养体系、反应体系、推荐用量等参考数据；只用于展示和模板保存，不参与公式计算。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 0) {
                        CustomReferenceTableRow(name: "名称", condition: "条件", value: "数值", note: "备注", isHeader: true)
                        ForEach(rows) { row in
                            CustomReferenceTableRow(
                                name: row.name,
                                condition: row.condition,
                                value: row.value,
                                note: row.note,
                                onTap: { onEdit(row) }
                            )
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct CustomReferenceTableRow: View {
    let name: String
    let condition: String
    let value: String
    let note: String
    var isHeader = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            cell(name, width: 90, alignment: .leading)
            cell(condition, width: 100, alignment: .leading)
            cell(value, width: 84)
            cell(note, width: 120, alignment: .leading)
        }
        .font(isHeader ? .caption2.weight(.semibold) : .caption2)
        .foregroundStyle(isHeader ? .primary : .secondary)
        .background(isHeader ? Color.labInset.opacity(0.9) : Color.labInset.opacity(0.55))
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    private func cell(_ text: String, width: CGFloat, alignment: Alignment = .center) -> some View {
        Text(text.isEmpty ? "-" : text)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .frame(width: width, height: 30, alignment: alignment)
            .padding(.horizontal, 4)
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color.secondary.opacity(0.12)).frame(width: 0.5)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.secondary.opacity(0.12)).frame(height: 0.5)
            }
    }
}

struct CustomReferenceRowEditSheet: View {
    @State private var row: CustomReferenceRow
    let canDelete: Bool
    let onSave: (CustomReferenceRow) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    init(
        row: CustomReferenceRow,
        canDelete: Bool,
        onSave: @escaping (CustomReferenceRow) -> Void,
        onDelete: @escaping () -> Void
    ) {
        _row = State(initialValue: row)
        self.canDelete = canDelete
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    CustomReferenceEditField(title: "名称", text: $row.name)
                    CustomReferenceEditField(title: "条件", text: $row.condition)
                    CustomReferenceEditField(title: "数值", text: $row.value)
                    CustomReferenceEditField(title: "备注", text: $row.note)

                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("删除这条参考", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(!canDelete)
                }
                .padding(18)
            }
            .background(Color.labBackground)
            .navigationTitle("编辑参考")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(row)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct CustomReferenceEditField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(title, text: $text)
                .font(.title3.weight(.semibold))
                .textFieldStyle(.roundedBorder)
        }
        .padding(14)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct CustomCalculatorSheet: View {
    let prefill: SavedFormula?
    let onSave: (CalculationRecord) -> Void
    let onSaveFormula: ((SavedFormula) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var variables: [CustomVariableField]
    @State private var steps: [CustomCalculationStep]
    @State private var resultFields: [CustomResultField]
    @State private var referenceRows: [CustomReferenceRow]
    @State private var editingReferenceRow: CustomReferenceRow?
    @State private var resultLabel: String
    @State private var copied = false
    @State private var alertMessage: String?

    init(prefill: SavedFormula? = nil, onSave: @escaping (CalculationRecord) -> Void, onSaveFormula: ((SavedFormula) -> Void)? = nil) {
        self.prefill = prefill
        self.onSave = onSave
        self.onSaveFormula = onSaveFormula
        if let f = prefill {
            _resultLabel = State(initialValue: f.label)
            let fields = zip(zip(f.variableNames, f.variableValues), f.variableUnits).map { nameVal, unit in
                CustomVariableField(name: nameVal.0, value: nameVal.1, unit: unit)
            }
            _variables = State(initialValue: fields.isEmpty ? [CustomVariableField(name: "", value: "", unit: "")] : fields)
            _steps = State(initialValue: f.workflowSteps)
            _resultFields = State(initialValue: f.workflowResultFields)
            _referenceRows = State(initialValue: f.workflowReferenceRows)
        } else {
            _variables = State(initialValue: [CustomVariableField(name: "", value: "", unit: "")])
            _steps = State(initialValue: [CustomCalculationStep(outputName: "结果", formula: "", outputUnit: "")])
            _resultFields = State(initialValue: [CustomResultField(variableName: "结果", label: "结果", displayUnit: "")])
            _referenceRows = State(initialValue: [])
            _resultLabel = State(initialValue: "自定义公式")
        }
    }

    private var workflowValidation: CalculationValidation<CustomWorkflowOutput> {
        CustomWorkflowEngine.evaluate(variables: variables, steps: steps, resultFields: resultFields)
    }

    private var workflowOutput: CustomWorkflowOutput? {
        workflowValidation.successValue
    }

    private var currentInputs: [String: Double] {
        workflowOutput?.values ?? [:]
    }

    private var formulaSummary: String {
        let summary = steps
            .map { step in
                let name = step.outputName.trimmingCharacters(in: .whitespaces)
                let formula = step.formula.trimmingCharacters(in: .whitespaces)
                return "\(name)=\(formula)"
            }
            .joined(separator: "; ")
        return summary.isEmpty ? "自定义工作流" : summary
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
                            Text("变量 + 单位 + 多步骤计算 → 展示指定结果")
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

                    // Variables
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("输入变量")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                variables.append(CustomVariableField(name: "", value: "", unit: ""))
                            } label: {
                                Label("添加", systemImage: "plus.circle.fill")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.teal)
                        }

                        ForEach($variables) { $variable in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    TextField("变量名", text: $variable.name)
                                        .font(.subheadline.weight(.semibold))
                                        .textFieldStyle(.roundedBorder)

                                    if variables.count > 1 {
                                        Button {
                                            variables.removeAll { $0.id == variable.id }
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(.red.opacity(0.65))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                HStack(spacing: 8) {
                                    Text("数值")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 42, alignment: .leading)
                                    TextField("0", text: $variable.value)
                                        .font(.title3.monospacedDigit().weight(.semibold))
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                    CustomUnitPicker(selection: $variable.unit)
                                }
                            }
                            .padding(12)
                            .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
                        }

                        Text("计算时会先检查单位，再统一换算到基础单位：体积 μl、质量 μg、浓度 μg/μl 或 M。")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    // Steps
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("计算步骤")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                steps.append(CustomCalculationStep(outputName: "", formula: "", outputUnit: ""))
                            } label: {
                                Label("添加", systemImage: "plus.circle.fill")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.teal)
                        }

                        ForEach(Array($steps.enumerated()), id: \.element.id) { index, $step in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("步骤 \(index + 1)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.teal)
                                    Spacer()
                                    if steps.count > 1 {
                                        Button {
                                            steps.removeAll { $0.id == step.id }
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(.red.opacity(0.65))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                TextField("输出变量，如 plasmidVolume", text: $step.outputName)
                                    .font(.subheadline.weight(.semibold))
                                    .textFieldStyle(.roundedBorder)

                                TextField("公式，如 totalDNA * ratio / totalRatio", text: $step.formula)
                                    .font(.subheadline.monospacedDigit())
                                    .textFieldStyle(.roundedBorder)

                                HStack {
                                    Text("公式输出单位")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    CustomUnitPicker(selection: $step.outputUnit)
                                }
                            }
                            .padding(12)
                            .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
                        }

                        Text("后面的步骤可以使用前面步骤的输出变量。步骤输出会继续按单位归一化，供后续步骤使用。")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    // Displayed results
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("展示结果")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                resultFields.append(CustomResultField(variableName: "", label: "", displayUnit: ""))
                            } label: {
                                Label("添加", systemImage: "plus.circle.fill")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.teal)
                        }

                        ForEach($resultFields) { $field in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    TextField("展示名称", text: $field.label)
                                        .font(.subheadline.weight(.semibold))
                                        .textFieldStyle(.roundedBorder)

                                    if resultFields.count > 1 {
                                        Button {
                                            resultFields.removeAll { $0.id == field.id }
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(.red.opacity(0.65))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                HStack(spacing: 8) {
                                    TextField("变量名", text: $field.variableName)
                                        .font(.subheadline.monospacedDigit())
                                        .textFieldStyle(.roundedBorder)
                                    CustomUnitPicker(selection: $field.displayUnit)
                                }
                            }
                            .padding(12)
                            .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    CustomReferenceTableSection(
                        rows: $referenceRows,
                        onAdd: {
                            let row = CustomReferenceRow(name: "参考项", condition: "", value: "", note: "")
                            referenceRows.append(row)
                            editingReferenceRow = row
                        },
                        onEdit: { editingReferenceRow = $0 },
                        onDelete: { id in referenceRows.removeAll { $0.id == id } }
                    )

                    // Result
                    VStack(alignment: .leading, spacing: 12) {
                        Text("计算结果")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        switch workflowValidation {
                        case .success(let output):
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(output.lines) { line in
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(line.label)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.teal)
                                        Spacer(minLength: 12)
                                        Text(CustomFormulaUnit.format(line.value))
                                            .font(.title3.monospacedDigit().weight(.bold))
                                            .foregroundStyle(.teal)
                                        if !line.unit.isEmpty {
                                            Text(line.unit)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.teal)
                                        }
                                    }
                                }
                            }
                        case .failure(let message):
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }

                        HStack(spacing: 10) {
                            Button {
                                guard let output = workflowOutput else {
                                    if case .failure(let message) = workflowValidation {
                                        alertMessage = message
                                    }
                                    return
                                }
                                Clipboard.copy(output.clipboardText)
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                            } label: {
                                Label(copied ? "已复制" : "复制结果", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(workflowOutput == nil)

                            Button {
                                switch workflowValidation {
                                case .success(let output):
                                    let record = CalculationRecord(
                                        id: UUID().uuidString,
                                        mode: CalculatorMode.custom.rawValue,
                                        label: resultLabel.trimmingCharacters(in: .whitespaces).isEmpty ? "自定义公式" : resultLabel,
                                        result: output.clipboardText,
                                        date: Date(),
                                        inputs: currentInputs
                                    )
                                    onSave(record)
                                    dismiss()
                                case .failure(let message):
                                    alertMessage = message
                                }
                            } label: {
                                Label("保存结果", systemImage: "checkmark.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(workflowOutput == nil)
                        }

                        Button {
                            switch workflowValidation {
                            case .success:
                                break
                            case .failure(let message):
                                alertMessage = message
                                return
                            }
                            let label = resultLabel.trimmingCharacters(in: .whitespaces).isEmpty ? "自定义公式" : resultLabel
                            let saved = SavedFormula(
                                id: UUID().uuidString,
                                label: label,
                                formula: formulaSummary,
                                variableNames: variables.map { $0.name },
                                variableValues: variables.map { $0.value },
                                variableUnits: variables.map { $0.unit },
                                resultUnit: "",
                                steps: steps,
                                resultFields: resultFields,
                                referenceRows: referenceRows
                            )
                            onSaveFormula?(saved)
                            dismiss()
                        } label: {
                            Label("保存为工作流模板", systemImage: "square.and.arrow.down.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(workflowOutput == nil)
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
            .alert("公式或输入不正确", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
            .sheet(item: $editingReferenceRow) { row in
                CustomReferenceRowEditSheet(
                    row: row,
                    canDelete: true,
                    onSave: { updated in
                        if let index = referenceRows.firstIndex(where: { $0.id == updated.id }) {
                            referenceRows[index] = updated
                        }
                    },
                    onDelete: {
                        referenceRows.removeAll { $0.id == row.id }
                    }
                )
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
