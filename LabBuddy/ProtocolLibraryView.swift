import SwiftUI

struct ProtocolLibraryView: View {
    @State private var editableProtocols: [LabProtocol] = {
        if let data = UserDefaults.standard.data(forKey: "savedProtocols"),
           let saved = try? JSONDecoder().decode([LabProtocol].self, from: data) {
            return saved
        }
        return SampleData.protocols
    }()
    @State private var searchText = ""
    @State private var selectedFilter: WorkflowArea? = nil
    @State private var selectedProtocol: LabProtocol?
    @State private var extractionSource: ProtocolSourceType?
    @State private var editingProtocol: LabProtocol?
    @State private var favoriteIDs: Set<String> = {
        let raw = UserDefaults.standard.string(forKey: "protocolFavoriteIDs") ?? ""
        return Set(raw.split(separator: ",").map(String.init))
    }()
    @State private var recentIDs: [String] = {
        let raw = UserDefaults.standard.string(forKey: "protocolRecentIDs") ?? ""
        return raw.split(separator: ",").map(String.init)
    }()

    private var filteredProtocols: [LabProtocol] {
        var list = editableProtocols
        if let area = selectedFilter {
            list = list.filter { $0.area == area }
        }
        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.area.rawValue.localizedCaseInsensitiveContains(searchText)
                || ($0.source?.title ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return list.sorted { lhs, rhs in
            let lFav = favoriteIDs.contains(lhs.id)
            let rFav = favoriteIDs.contains(rhs.id)
            if lFav != rFav { return lFav }
            let lRecent = recentIDs.firstIndex(of: lhs.id) ?? Int.max
            let rRecent = recentIDs.firstIndex(of: rhs.id) ?? Int.max
            return lRecent < rRecent
        }
    }

    var body: some View {
        ZStack {
            Color.labBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Search + filter header
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("搜索 Protocol 名称或来源", text: $searchText)
                            .autocorrectionDisabled()
                    }
                    .padding(10)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "全部", isSelected: selectedFilter == nil) {
                                selectedFilter = nil
                            }
                            ForEach(WorkflowArea.builtIn) { area in
                                FilterChip(title: area.rawValue, isSelected: selectedFilter == area) {
                                    selectedFilter = selectedFilter == area ? nil : area
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 10)

                // Protocol list
                if filteredProtocols.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "list.clipboard")
                            .font(.largeTitle)
                            .foregroundStyle(.teal.opacity(0.5))
                        Text(searchText.isEmpty ? "还没有 Protocol" : "没有匹配的 Protocol")
                            .font(.headline)
                        Text("往下翻到底部可新建或提取")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                List {
                    ForEach(filteredProtocols) { labProtocol in
                        ProtocolLibraryCard(
                            labProtocol: labProtocol,
                            onTap: {
                                recordRecent(labProtocol.id)
                                selectedProtocol = labProtocol
                            },
                            onEdit: {
                                recordRecent(labProtocol.id)
                                editingProtocol = labProtocol
                            },
                            onDelete: {
                                editableProtocols.removeAll { $0.id == labProtocol.id }
                                save()
                            }
                        )
                        .listRowBackground(Color.labBackground)
                        .listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 18))
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                editableProtocols.removeAll { $0.id == labProtocol.id }
                                save()
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }

                    // Bottom action row — scroll down to reach
                    Section {
                        HStack(spacing: 12) {
                            Button {
                                editingProtocol = emptyProtocol()
                            } label: {
                                Label("新建", systemImage: "plus.circle")
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.teal)
                            .controlSize(.large)

                            Menu {
                                ForEach(ProtocolSourceType.allCases) { sourceType in
                                    Button(sourceType.rawValue) {
                                        extractionSource = sourceType
                                    }
                                }
                            } label: {
                                Label("提取", systemImage: "doc.text.viewfinder")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.labBackground)
                        .listRowInsets(EdgeInsets(top: 12, leading: 18, bottom: 20, trailing: 18))
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .sheet(item: $selectedProtocol) { labProtocol in
            ProtocolDetailView(
                labProtocol: labProtocol,
                onEdit: {
                    selectedProtocol = nil
                    editingProtocol = labProtocol
                }
            )
        }
        .sheet(item: $editingProtocol) { labProtocol in
            ProtocolEditorSheet(
                labProtocol: labProtocol,
                saveProtocol: { updated in
                    upsert(updated)
                }
            )
        }
        .sheet(item: $extractionSource) { sourceType in
            ProtocolExtractionSheet(sourceType: sourceType) { extracted in
                upsert(extracted)
                editingProtocol = extracted
            }
        }
    }

    private func upsert(_ labProtocol: LabProtocol) {
        if let index = editableProtocols.firstIndex(where: { $0.id == labProtocol.id }) {
            editableProtocols[index] = labProtocol
        } else {
            editableProtocols.insert(labProtocol, at: 0)
        }
        save()
    }

    private func toggleFavorite(_ id: String) {
        if favoriteIDs.contains(id) {
            favoriteIDs.remove(id)
        } else {
            favoriteIDs.insert(id)
        }
        UserDefaults.standard.set(favoriteIDs.joined(separator: ","), forKey: "protocolFavoriteIDs")
    }

    private func recordRecent(_ id: String) {
        recentIDs.removeAll { $0 == id }
        recentIDs.insert(id, at: 0)
        if recentIDs.count > 20 { recentIDs = Array(recentIDs.prefix(20)) }
        UserDefaults.standard.set(recentIDs.joined(separator: ","), forKey: "protocolRecentIDs")
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(editableProtocols) else { return }
        UserDefaults.standard.set(data, forKey: "savedProtocols")
    }

    private func emptyProtocol() -> LabProtocol {
        LabProtocol(
            id: "custom-\(Int(Date().timeIntervalSince1970))",
            name: "新 Protocol",
            area: .cell,
            baseVolume: 50,
            volumeUnit: "ml",
            expectedDuration: "15 min",
            ingredients: [ProtocolIngredient(name: "成分 A", standardAmount: 50, unit: "ml")],
            steps: [LabStep(id: UUID().uuidString, title: "第一步", detail: "填写操作条件", durationMinutes: nil, isCarryOver: false)],
            variables: [],
            source: ProtocolSource(type: .sop, title: "手动创建", confidence: 1.0)
        )
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var accentColor: Color = .teal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? accentColor : Color.labPanel, in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Protocol Library Card

struct ProtocolLibraryCard: View {
    let labProtocol: LabProtocol
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var consistencyIssues: [String] {
        protocolConsistencyIssues(labProtocol)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(labProtocol.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        HStack(spacing: 6) {
                            AreaBadge(area: labProtocol.area)
                            Text("基准 \(Int(labProtocol.baseVolume)) \(labProtocol.volumeUnit)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("· \(labProtocol.expectedDuration)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button(action: onEdit) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(.teal)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }

                if let source = labProtocol.source {
                    Label("\(source.type.rawValue) · \(source.title)", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Reagent recipe preview — visually prominent
                if !labProtocol.ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("配方")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.teal)
                        ForEach(labProtocol.ingredients.prefix(3)) { ing in
                            HStack {
                                Circle()
                                    .fill(Color.teal.opacity(0.4))
                                    .frame(width: 5, height: 5)
                                Text(ing.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(ing.standardAmount >= 10 ? String(format: "%.0f", ing.standardAmount) : String(format: "%.2f", ing.standardAmount)) \(ing.unit)")
                                    .font(.subheadline.monospacedDigit().weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if labProtocol.ingredients.count > 3 {
                            Text("还有 \(labProtocol.ingredients.count - 3) 项成分")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }

                if !consistencyIssues.isEmpty {
                    Label("\(consistencyIssues.count) 项待检查", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            .padding(16)
            .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Protocol Detail View (read-only with variable adjustment)

struct ProtocolDetailView: View {
    let labProtocol: LabProtocol
    let onEdit: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var variableValues: [String: Double] = [:]
    @State private var showShareSheet = false

    @MainActor
    private func makeShareImage() -> Image {
        let card = ProtocolShareCard(
            labProtocol: labProtocol,
            resolvedVariables: resolvedVariables,
            variableValues: variableValues
        )
        let renderer = ImageRenderer(content: card.frame(width: 360))
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "doc")
    }

    private var areaColor: Color {
        switch labProtocol.area {
        case .cell: return .teal
        case .cloning: return .blue
        case .blot: return .purple
        default: return .gray
        }
    }

    private var resolvedVariables: [String: Double] {
        var dict: [String: Double] = [:]
        for v in labProtocol.variables {
            let raw = variableValues[v.symbol] ?? v.baseValue
            let computed = v.unit.trimmingCharacters(in: .whitespaces) == "%" ? raw / 100.0 : raw
            dict[v.symbol] = computed
            dict[v.name] = computed
        }
        return dict
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero header
                    VStack(spacing: 12) {
                        // Area + duration row
                        HStack(spacing: 8) {
                            AreaBadge(area: labProtocol.area)
                            Text(labProtocol.expectedDuration)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Color.labPanel, in: Capsule())
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let source = labProtocol.source {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.caption)
                                        .foregroundStyle(areaColor.opacity(0.7))
                                    Text("\(Int(source.confidence * 100))%")
                                        .font(.caption.monospacedDigit().weight(.semibold))
                                        .foregroundStyle(areaColor)
                                }
                            }
                        }

                        // Centered title
                        Text(labProtocol.name)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        // Source info
                        if let source = labProtocol.source {
                            Label("\(source.type.rawValue) · \(source.title)", systemImage: "doc.text")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }

                        // Base volume pill
                        HStack(spacing: 6) {
                            Image(systemName: "flask.fill")
                                .font(.caption)
                                .foregroundStyle(areaColor)
                            Text("基准 \(ExpressionEvaluator.format(labProtocol.baseVolume)) \(labProtocol.volumeUnit)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(areaColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(areaColor.opacity(0.1), in: Capsule())
                    }
                    .padding(20)
                    .background(Color.labPanel)

                    VStack(alignment: .leading, spacing: 16) {

                        // Steps with per-step reagents
                        if !labProtocol.steps.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("实验步骤", systemImage: "list.number")
                                    .font(.headline)
                                    .padding(.horizontal, 2)

                                ForEach(Array(labProtocol.steps.enumerated()), id: \.element.id) { index, step in
                                    DetailStepCard(
                                        index: index + 1,
                                        step: step,
                                        variables: resolvedVariables,
                                        areaColor: areaColor
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 12))
                        }

                        // Variable adjustment panel
                        if !labProtocol.variables.isEmpty {
                            VariableAdjustPanel(
                                variables: labProtocol.variables,
                                values: $variableValues,
                                areaColor: areaColor
                            )
                        }

                        // Reagent summary (calculated)
                        if !labProtocol.ingredients.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("配方总览", systemImage: "flask.fill")
                                    .font(.headline)
                                    .foregroundStyle(areaColor)
                                    .padding(.horizontal, 2)

                                ForEach(labProtocol.ingredients) { ing in
                                    let scaleFactor: Double = {
                                        // Use primary scalable variable's scale factor if available
                                        if let primary = labProtocol.variables.first(where: { $0.isScalable }) {
                                            let current = variableValues[primary.symbol] ?? primary.baseValue
                                            return primary.baseValue > 0 ? current / primary.baseValue : 1.0
                                        }
                                        return 1.0
                                    }()
                                    let scaled = ing.standardAmount * scaleFactor
                                    let isChanged = abs(scaleFactor - 1.0) > 0.001
                                    HStack {
                                        Text(ing.name)
                                            .font(.subheadline.weight(.medium))
                                        Spacer()
                                        if isChanged {
                                            Text("\(ing.standardAmount >= 10 ? String(format: "%.0f", ing.standardAmount) : String(format: "%.2f", ing.standardAmount)) \(ing.unit)")
                                                .font(.caption.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                                .strikethrough()
                                            Image(systemName: "arrow.right")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text("\(scaled >= 10 ? String(format: "%.0f", scaled) : String(format: "%.2f", scaled)) \(ing.unit)")
                                            .font(.subheadline.monospacedDigit().weight(.semibold))
                                            .foregroundStyle(isChanged ? areaColor : .primary)
                                    }
                                    .padding(.vertical, 5)
                                    Divider()
                                }
                            }
                            .padding(16)
                            .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(areaColor.opacity(0.18), lineWidth: 1))
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color.labBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(labProtocol.name)
                        .font(.headline)
                        .lineLimit(1)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: makeShareImage(), preview: SharePreview(labProtocol.name, image: makeShareImage())) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                // Initialize variable values from base values
                var dict: [String: Double] = [:]
                for v in labProtocol.variables {
                    dict[v.symbol] = v.currentValue
                }
                variableValues = dict
            }
        }
    }
}

// MARK: - Detail Step Card

private struct DetailStepCard: View {
    let index: Int
    let step: LabStep
    let variables: [String: Double]
    let areaColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Step header
            HStack(alignment: .top, spacing: 10) {
                Text("\(index)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .frame(width: 26, height: 26)
                    .background(areaColor.opacity(0.14), in: Circle())
                    .foregroundStyle(areaColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(.subheadline.weight(.semibold))

                    Text(step.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        if let dur = step.durationMinutes {
                            Label("\(dur) min", systemImage: "timer")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                        if step.isCarryOver {
                            Label("顺延", systemImage: "arrow.right.circle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .padding(12)

            // Per-step reagents
            if !step.reagents.isEmpty {
                Divider().padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 6) {
                    Text("本步试剂")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)

                    ForEach(step.reagents) { reagent in
                        let amount = reagent.calculateAmount(variables: variables)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(areaColor.opacity(0.35))
                                .frame(width: 5, height: 5)
                            Text(reagent.name)
                                .font(.caption)
                                .foregroundStyle(.primary)
                            Spacer()
                            if let val = amount {
                                Text("\(ExpressionEvaluator.format(val)) \(reagent.unit)")
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(areaColor)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(areaColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                            } else {
                                Text(reagent.amountExpression + " \(reagent.unit)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(areaColor.opacity(0.04))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(areaColor.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Variable Adjust Panel

private struct VariableAdjustPanel: View {
    let variables: [ProtocolVariable]
    @Binding var values: [String: Double]
    let areaColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("参数调整", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Spacer()
                Button {
                    for v in variables { values[v.symbol] = v.baseValue }
                } label: {
                    Text("重置")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(areaColor)
                }
            }
            .padding(.horizontal, 2)

            ForEach(variables) { variable in
                let binding = Binding<Double>(
                    get: { values[variable.symbol] ?? variable.baseValue },
                    set: { values[variable.symbol] = $0 }
                )
                HStack {
                    Text(variable.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(areaColor)
                    if variable.isScalable {
                        Text("同比")
                            .font(.caption2)
                            .foregroundStyle(areaColor.opacity(0.6))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(areaColor.opacity(0.1), in: Capsule())
                    }
                    Spacer()
                    TextField("", value: binding, format: .number)
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 72)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.labInset, in: RoundedRectangle(cornerRadius: 6))
                        .keyboardType(.decimalPad)
                    Text(variable.unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .leading)
                }
                .padding(12)
                .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(areaColor.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - Area Badge

struct AreaBadge: View {
    let area: WorkflowArea

    var color: Color {
        switch area {
        case .cell: return .teal
        case .cloning: return .blue
        case .blot: return .purple
        default: return .gray
        }
    }

    var body: some View {
        Text(area.rawValue)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }
}

// MARK: - Protocol Editor Sheet (renamed from ProtocolEditorView)

struct ProtocolEditorSheet: View {
    @State private var draft: LabProtocol
    let saveProtocol: (LabProtocol) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var customAreas: [String] = {
        let raw = UserDefaults.standard.string(forKey: "customWorkflowAreas") ?? ""
        return raw.isEmpty ? [] : raw.split(separator: ",").map(String.init)
    }()
    @State private var showingAddArea = false
    @State private var newAreaName = ""
    @State private var durationValue: Double
    @State private var durationUnit: String

    init(labProtocol: LabProtocol, saveProtocol: @escaping (LabProtocol) -> Void) {
        _draft = State(initialValue: labProtocol)
        self.saveProtocol = saveProtocol
        // Parse expectedDuration like "15 min" into value and unit
        let parts = labProtocol.expectedDuration.split(separator: " ")
        if parts.count >= 2, let val = Double(parts[0]) {
            _durationValue = State(initialValue: val)
            _durationUnit = State(initialValue: String(parts[1]))
        } else {
            _durationValue = State(initialValue: 15)
            _durationUnit = State(initialValue: "min")
        }
    }

    private var durationUnits = ["s", "min", "h", "day"]

    private var consistencyIssues: [String] { protocolConsistencyIssues(draft) }
    private var scaleFactor: Double { draft.baseVolume > 0 ? 1.0 : 1.0 }
    private let accent = Color.teal

    private var allAreas: [WorkflowArea] {
        WorkflowArea.builtIn + customAreas.map { WorkflowArea.custom($0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: 基础信息
                Section {
                    TextField("Protocol 名称", text: $draft.name)

                    Picker("实验类型", selection: $draft.area) {
                        ForEach(allAreas) { area in
                            Text(area.rawValue).tag(area)
                        }
                    }

                    Button {
                        newAreaName = ""
                        showingAddArea = true
                    } label: {
                        Label("新建实验类型", systemImage: "plus.circle")
                            .foregroundStyle(.teal)
                    }

                    HStack {
                        Text("基准体积")
                        Spacer()
                        TextField("0", value: $draft.baseVolume, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                            .keyboardType(.decimalPad)
                            .font(.body.monospacedDigit())
                        Picker("单位", selection: $draft.volumeUnit) {
                            Text("ml").tag("ml")
                            Text("L").tag("L")
                            Text("μl").tag("μl")
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 64)
                    }
                    HStack {
                        Text("预计时长")
                        Spacer()
                        TextField("0", value: $durationValue, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                            .keyboardType(.decimalPad)
                            .font(.body.monospacedDigit())
                        Picker("单位", selection: $durationUnit) {
                            ForEach(durationUnits, id: \.self) { u in
                                Text(u).tag(u)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 72)
                    }
                } header: {
                    Label("基础信息", systemImage: "doc.text")
                        .foregroundStyle(accent)
                }
                .alert("新建实验类型", isPresented: $showingAddArea) {
                    TextField("类型名称", text: $newAreaName)
                    Button("添加") {
                        let name = newAreaName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        customAreas.append(name)
                        UserDefaults.standard.set(customAreas.joined(separator: ","), forKey: "customWorkflowAreas")
                        draft.area = .custom(name)
                    }
                    Button("取消", role: .cancel) { }
                } message: {
                    Text("新类型将出现在实验类型选择栏中")
                }

                // MARK: 配方成分
                Section {
                    ForEach($draft.ingredients) { $ing in
                        HStack(spacing: 10) {
                            TextField("成分名称", text: $ing.name)
                            Spacer()
                            TextField("用量", value: $ing.standardAmount, format: .number)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 72)
                                .keyboardType(.decimalPad)
                            TextField("单位", text: $ing.unit)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 48)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { draft.ingredients.remove(atOffsets: $0) }
                    Button {
                        draft.ingredients.append(ProtocolIngredient(name: "新成分", standardAmount: 1, unit: draft.volumeUnit))
                    } label: { Label("增加成分", systemImage: "plus.circle") }
                } header: {
                    Label("配方成分", systemImage: "flask.fill")
                        .foregroundStyle(accent)
                }

                // MARK: 公式变量
                Section {
                    ForEach($draft.variables) { $variable in
                        HStack(spacing: 10) {
                            TextField("变量名称", text: $variable.name)
                            Spacer()
                            TextField("数值", value: $variable.baseValue, format: .number)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 72)
                                .keyboardType(.decimalPad)
                            Picker("", selection: $variable.unit) {
                                ForEach(UnifiedUnits.forProtocol, id: \.self) { u in
                                    Text(u).tag(u)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .fixedSize()
                            Toggle("", isOn: $variable.isScalable)
                                .labelsHidden()
                                .tint(accent)
                        }
                    }
                    .onDelete { draft.variables.remove(atOffsets: $0) }
                    Button {
                        draft.variables.append(ProtocolVariable(symbol: "v\(draft.variables.count + 1)", name: "新变量", baseValue: 1, unit: draft.volumeUnit, isScalable: true, minValue: 0, maxValue: 100))
                    } label: { Label("增加变量", systemImage: "plus.circle") }
                } header: {
                    Label("公式变量", systemImage: "function")
                        .foregroundStyle(accent)
                }

                // MARK: 实验步骤
                Section {
                    ForEach($draft.steps.indices, id: \.self) { idx in
                        let stepBinding = $draft.steps[idx]
                        VStack(alignment: .leading, spacing: 10) {
                            // 步骤标题行
                            HStack(spacing: 8) {
                                Text("\(idx + 1)")
                                    .font(.caption.monospacedDigit().weight(.bold))
                                    .frame(width: 24, height: 24)
                                    .background(accent.opacity(0.15), in: Circle())
                                    .foregroundStyle(accent)
                                TextField("步骤名称", text: stepBinding.title)
                                    .font(.subheadline.weight(.semibold))
                            }

                            // 操作描述（多行）
                            TextField("操作描述", text: stepBinding.detail, axis: .vertical)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2...6)
                                .padding(.leading, 32)

                            // 计时
                            HStack(spacing: 6) {
                                Image(systemName: "timer")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("时长（分钟）", value: Binding(
                                    get: { stepBinding.wrappedValue.durationMinutes },
                                    set: { stepBinding.wrappedValue.durationMinutes = $0 }
                                ), format: .number)
                                .font(.subheadline)
                                .frame(width: 80)
                                .keyboardType(.numberPad)
                                Text("min").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .padding(.leading, 32)

                            // 试剂列表
                            if !stepBinding.wrappedValue.reagents.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(stepBinding.reagents) { $reagent in
                                        ReagentEditorRow(
                                            reagent: $reagent,
                                            variables: draft.variables,
                                            accent: accent
                                        )
                                    }
                                    .onDelete { offsets in
                                        stepBinding.wrappedValue.reagents.remove(atOffsets: offsets)
                                    }
                                }
                                .padding(.leading, 32)
                            }

                            // 增加试剂按钮
                            Button {
                                stepBinding.wrappedValue.reagents.append(
                                    StepReagent(id: UUID().uuidString, name: "新试剂", amountExpression: "1", unit: draft.volumeUnit)
                                )
                            } label: {
                                Label("增加试剂", systemImage: "plus.circle")
                                    .font(.caption)
                                    .foregroundStyle(accent)
                            }
                            .padding(.leading, 32)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { draft.steps.remove(atOffsets: $0) }

                    Button {
                        draft.steps.append(LabStep(id: UUID().uuidString, title: "新步骤", detail: "", durationMinutes: nil, isCarryOver: false))
                    } label: { Label("增加步骤", systemImage: "plus.circle") }
                } header: {
                    Label("实验步骤", systemImage: "list.number")
                        .foregroundStyle(accent)
                }

                // MARK: 来源（系统识别 + 可选择）
                Section {
                    Picker("来源类型", selection: Binding(
                        get: { draft.source?.type },
                        set: { newType in
                            if let t = newType {
                                draft.source = ProtocolSource(type: t, title: draft.source?.title ?? "", confidence: draft.source?.confidence ?? 1.0)
                            } else {
                                draft.source = nil
                            }
                        }
                    )) {
                        Text("手动创建").tag(Optional<ProtocolSourceType>.none)
                        ForEach(ProtocolSourceType.allCases) { t in
                            Text(t.rawValue + " 导入").tag(Optional(t))
                        }
                    }
                } header: {
                    Label("来源", systemImage: "doc.text.viewfinder")
                        .foregroundStyle(accent)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var updated = draft
                        updated.expectedDuration = "\(Int(durationValue)) \(durationUnit)"
                        saveProtocol(updated)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Reagent Editor Row

private struct ReagentEditorRow: View {
    @Binding var reagent: StepReagent
    let variables: [ProtocolVariable]
    let accent: Color
    @State private var showFormulaPicker = false

    private var varDict: [String: Double] {
        var d: [String: Double] = [:]
        for v in variables {
            d[v.name] = v.computedBaseValue
            d[v.symbol] = v.computedBaseValue
        }
        return d
    }

    private var resolvedPreview: String? {
        guard reagent.isFormula, !reagent.amountExpression.isEmpty else { return nil }
        if let val = ExpressionEvaluator.evaluate(reagent.amountExpression, variables: varDict) {
            return "\(ExpressionEvaluator.format(val)) \(reagent.unit)"
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(accent.opacity(0.35)).frame(width: 5, height: 5)

            // 试剂名
            TextField("试剂名称", text: $reagent.name)
                .font(.subheadline)

            Spacer()

            if reagent.isFormula {
                // 公式模式：显示计算结果（点击进入公式编辑）
                Button { showFormulaPicker = true } label: {
                    if let preview = resolvedPreview {
                        Text(preview)
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(accent)
                    } else if reagent.amountExpression.isEmpty {
                        Text("输入公式")
                            .font(.subheadline)
                            .foregroundStyle(accent.opacity(0.5))
                    } else {
                        Text("无法计算")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
                .buttonStyle(.plain)
            } else {
                // 固定值模式：直接输入数字 + 单位
                TextField("用量", text: $reagent.amountExpression)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .keyboardType(.decimalPad)
                TextField("单位", text: $reagent.unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 36)
            }

            // 模式切换：小圆点，公式=teal，固定值=灰
            Button {
                reagent.isFormula.toggle()
                if !reagent.isFormula, Double(reagent.amountExpression) == nil {
                    reagent.amountExpression = ""
                }
            } label: {
                Circle()
                    .fill(reagent.isFormula ? accent : Color(.systemGray4))
                    .frame(width: 8, height: 8)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showFormulaPicker) {
            FormulaPickerSheet(
                variables: variables,
                unit: reagent.unit,
                currentExpression: $reagent.amountExpression,
                unitBinding: $reagent.unit
            )
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Formula Picker Sheet

private struct FormulaPickerSheet: View {
    let variables: [ProtocolVariable]
    let unit: String
    @Binding var currentExpression: String
    @Binding var unitBinding: String
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String

    init(variables: [ProtocolVariable], unit: String, currentExpression: Binding<String>, unitBinding: Binding<String>) {
        self.variables = variables
        self.unit = unit
        self._currentExpression = currentExpression
        self._unitBinding = unitBinding
        self._draft = State(initialValue: currentExpression.wrappedValue)
    }

    private var previewResult: String {
        var dict: [String: Double] = [:]
        for v in variables {
            dict[v.name] = v.computedBaseValue
            dict[v.symbol] = v.computedBaseValue
        }
        if let val = ExpressionEvaluator.evaluate(draft, variables: dict) {
            return "\(ExpressionEvaluator.format(val)) \(unitBinding)"
        }
        return draft.isEmpty ? "" : "无法计算"
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    // 结果预览（大字）
                    HStack {
                        Text(previewResult.isEmpty ? "—" : previewResult)
                            .font(.title2.monospacedDigit().weight(.bold))
                            .foregroundStyle(previewResult.hasPrefix("无") ? .orange : .teal)
                        Spacer()
                        // 单位编辑
                        HStack(spacing: 4) {
                            Text("单位")
                                .font(.caption).foregroundStyle(.secondary)
                            TextField("单位", text: $unitBinding)
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 48)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(.bottom, 4)

                    // 公式输入框
                    HStack {
                        TextField("输入公式，如：总体积 * 0.9", text: $draft)
                            .font(.body.monospaced())
                        if !draft.isEmpty {
                            Button { draft = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(16)

                Divider()

                List {
                    Section("点击插入变量") {
                        ForEach(variables) { v in
                            Button {
                                draft += (draft.isEmpty ? "" : " * ") + v.name
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(v.name).font(.subheadline.weight(.medium))
                                        Text("基准值：\(ExpressionEvaluator.format(v.baseValue)) \(v.unit)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle").foregroundStyle(.teal)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Section("运算符") {
                        let ops = [("×", " * "), ("÷", " / "), ("+", " + "), ("−", " - "), ("(", "("), (")", ")")]
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                            ForEach(ops, id: \.0) { label, op in
                                Button { draft += op } label: {
                                    Text(label)
                                        .font(.title3.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("插入公式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") { currentExpression = draft; dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Protocol Extraction Sheet

struct ProtocolExtractionSheet: View {
    let sourceType: ProtocolSourceType
    let accept: (LabProtocol) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var sourceTitle = ""
    @State private var extractedName = ""
    @State private var extractedVolume = 50.0

    private var previewProtocol: LabProtocol {
        LabProtocol(
            id: "extracted-\(sourceType.rawValue)-\(Int(Date().timeIntervalSince1970))",
            name: extractedName.isEmpty ? "\(sourceType.rawValue) 提取 Protocol" : extractedName,
            area: sourceType == .kitManual ? .cloning : .cell,
            baseVolume: extractedVolume,
            volumeUnit: sourceType == .kitManual ? "ul" : "ml",
            expectedDuration: "20 min",
            ingredients: [
                ProtocolIngredient(name: "提取成分 A", standardAmount: extractedVolume * 0.8, unit: sourceType == .kitManual ? "ul" : "ml"),
                ProtocolIngredient(name: "提取成分 B", standardAmount: extractedVolume * 0.2, unit: sourceType == .kitManual ? "ul" : "ml")
            ],
            steps: [
                LabStep(id: UUID().uuidString, title: "核对来源参数", detail: "检查温度、时间、转速和体积", durationMinutes: nil, isCarryOver: false),
                LabStep(id: UUID().uuidString, title: "执行提取方法", detail: "按来源方法完成关键步骤", durationMinutes: 20, isCarryOver: false)
            ],
            variables: [
                ProtocolVariable(symbol: "V_total", name: "总体积", baseValue: extractedVolume, unit: sourceType == .kitManual ? "ul" : "ml", isScalable: true, minValue: 10, maxValue: 500)
            ],
            source: ProtocolSource(type: sourceType, title: sourceTitle.isEmpty ? "待补充来源标题" : sourceTitle, confidence: 0.72)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("来源信息") {
                    Text(sourceType.rawValue).font(.headline)
                    TextField("文献题名 / 手册名称 / SOP 编号", text: $sourceTitle)
                    TextField("提取后的 Protocol 名称", text: $extractedName)
                    HStack {
                        Text("基准体积")
                        Spacer()
                        TextField("0", value: $extractedVolume, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 92)
                    }
                }
                Section("说明") {
                    Label("v1 使用人工核对流程：输入来源标题后，接受草稿并手动补充成分和步骤。自动 AI 提取为后续版本功能。", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button {
                        accept(previewProtocol)
                        dismiss()
                    } label: {
                        Label("接受草稿并继续编辑", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("提取 Protocol")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
    }
}

// Consistency check helper (shared)
func protocolConsistencyIssues(_ labProtocol: LabProtocol) -> [String] {
    var issues: [String] = []
    let ingredientTotal = labProtocol.ingredients.reduce(0) { $0 + $1.standardAmount }
    if abs(ingredientTotal - labProtocol.baseVolume) > max(0.2, labProtocol.baseVolume * 0.08) {
        issues.append("成分总量与基准体积不一致")
    }
    let symbols = Set(labProtocol.variables.map(\.symbol))
    let missingRefs = labProtocol.steps.flatMap(\.variableRefs).filter { !symbols.contains($0) }
    if let first = missingRefs.first { issues.append("步骤引用了未定义变量 \(first)") }
    // Check for duplicate variable symbols
    let dupes = Dictionary(grouping: labProtocol.variables.map(\.symbol), by: { $0 }).filter { $0.value.count > 1 }.map(\.key)
    if let dup = dupes.first { issues.append("变量 \(dup) 重复定义") }
    return issues
}

// MARK: - Protocol Share Card (rendered to image)

struct ProtocolShareCard: View {
    let labProtocol: LabProtocol
    let resolvedVariables: [String: Double]
    let variableValues: [String: Double]

    private var areaColor: Color {
        switch labProtocol.area {
        case .cell: return .teal
        case .cloning: return .blue
        case .blot: return .purple
        default: return .gray
        }
    }

    private var scaleFactor: Double {
        if let p = labProtocol.variables.first(where: { $0.isScalable }) {
            let cur = variableValues[p.symbol] ?? p.baseValue
            return p.baseValue > 0 ? cur / p.baseValue : 1.0
        }
        return 1.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(labProtocol.area.rawValue)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(areaColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(areaColor)
                    Text(labProtocol.expectedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(labProtocol.name)
                    .font(.title3.weight(.bold))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)

            Divider()

            // 参数
            if !labProtocol.variables.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("参数").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(labProtocol.variables) { v in
                        let cur = variableValues[v.symbol] ?? v.baseValue
                        HStack {
                            Text(v.name).font(.subheadline.weight(.medium)).foregroundStyle(areaColor)
                            Spacer()
                            Text("\(ExpressionEvaluator.format(cur)) \(v.unit)")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                        }
                    }
                }
                .padding(16)
                .background(areaColor.opacity(0.04))
                Divider()
            }

            // 配方
            if !labProtocol.ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("配方").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(labProtocol.ingredients) { ing in
                        let amt = ing.standardAmount * scaleFactor
                        HStack {
                            Text(ing.name).font(.subheadline)
                            Spacer()
                            Text("\(ExpressionEvaluator.format(amt)) \(ing.unit)")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(areaColor)
                        }
                    }
                }
                .padding(16)
                .background(Color.white)
                Divider()
            }

            // 步骤
            if !labProtocol.steps.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("步骤").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(Array(labProtocol.steps.enumerated()), id: \.element.id) { i, step in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("\(i + 1)")
                                    .font(.caption.weight(.bold))
                                    .frame(width: 20, height: 20)
                                    .background(areaColor.opacity(0.15), in: Circle())
                                    .foregroundStyle(areaColor)
                                Text(step.title).font(.subheadline.weight(.semibold))
                                if let dur = step.durationMinutes {
                                    Spacer()
                                    Text("⏱ \(dur) min").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            ForEach(step.reagents) { r in
                                let amt = r.calculateAmount(variables: resolvedVariables)
                                HStack {
                                    Text("• \(r.name)").font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    if let val = amt {
                                        Text("\(ExpressionEvaluator.format(val)) \(r.unit)")
                                            .font(.caption.monospacedDigit().weight(.semibold))
                                            .foregroundStyle(areaColor)
                                    }
                                }
                                .padding(.leading, 26)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.white)
            }

            // Footer
            HStack {
                Spacer()
                Text("由 LabBuddy 导出")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Color(.systemGray6))
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .padding(16)
        .background(Color(.systemGray5))
    }
}
