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
                            ForEach(WorkflowArea.allCases) { area in
                                FilterChip(title: area.rawValue, isSelected: selectedFilter == area) {
                                    selectedFilter = selectedFilter == area ? nil : area
                                }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            editingProtocol = emptyProtocol()
                        } label: {
                            Label("新建", systemImage: "plus.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
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
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 10)

                if filteredProtocols.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "list.clipboard")
                            .font(.largeTitle)
                            .foregroundStyle(.teal.opacity(0.5))
                        Text(searchText.isEmpty ? "还没有 Protocol" : "没有匹配的 Protocol")
                            .font(.headline)
                        Text("新建一个或从文献、试剂盒手册中提取")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredProtocols) { labProtocol in
                                ProtocolLibraryCard(
                                    labProtocol: labProtocol,
                                    isFavorite: favoriteIDs.contains(labProtocol.id),
                                    toggleFavorite: { toggleFavorite(labProtocol.id) },
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
                            }
                        }
                        .padding(18)
                    }
                }
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.teal : Color.labPanel, in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Protocol Library Card

struct ProtocolLibraryCard: View {
    let labProtocol: LabProtocol
    let isFavorite: Bool
    let toggleFavorite: () -> Void
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
                    Button(action: toggleFavorite) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundStyle(isFavorite ? .yellow : .secondary)
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

                HStack(spacing: 10) {
                    Button(action: onEdit) {
                        Label("编辑", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: onTap) {
                        Label("查看", systemImage: "eye")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .frame(width: 44, height: 28)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .foregroundStyle(.red)
                    .accessibilityLabel("删除 Protocol")
                }
            }
            .padding(16)
            .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Protocol Detail View (read-only)

struct ProtocolDetailView: View {
    let labProtocol: LabProtocol
    let onEdit: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            AreaBadge(area: labProtocol.area)
                            Spacer()
                            Text(labProtocol.expectedDuration)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        if let source = labProtocol.source {
                            Label("\(source.type.rawValue) · \(source.title)", systemImage: "doc.text")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text("置信度")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ProgressView(value: source.confidence)
                                    .tint(.teal)
                                    .frame(width: 80)
                                Text("\(Int(source.confidence * 100))%")
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(.teal)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    // Reagent recipe — priority section
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("配方成分", systemImage: "flask.fill")
                                .font(.headline)
                                .foregroundStyle(.teal)
                            Spacer()
                            Text("基准 \(Int(labProtocol.baseVolume)) \(labProtocol.volumeUnit)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        ForEach(labProtocol.ingredients) { ing in
                            HStack {
                                Text(ing.name)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text("\(ing.standardAmount >= 10 ? String(format: "%.0f", ing.standardAmount) : String(format: "%.2f", ing.standardAmount)) \(ing.unit)")
                                    .font(.subheadline.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.teal.opacity(0.2), lineWidth: 1))

                    // Steps
                    if !labProtocol.steps.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("实验步骤", systemImage: "list.number")
                                .font(.headline)
                            ForEach(Array(labProtocol.steps.enumerated()), id: \.element.id) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.caption.monospacedDigit().weight(.bold))
                                        .frame(width: 24, height: 24)
                                        .background(Color.teal.opacity(0.12), in: Circle())
                                        .foregroundStyle(.teal)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(step.title)
                                            .font(.subheadline.weight(.semibold))
                                        Text(step.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
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
                                .padding(10)
                                .background(Color.labInset, in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .padding(16)
                        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
                    }

                    // Variables
                    if !labProtocol.variables.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("公式变量", systemImage: "function")
                                .font(.headline)
                            ForEach(labProtocol.variables) { variable in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(variable.symbol)
                                            .font(.body.monospaced().weight(.semibold))
                                        Text(variable.name)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(variable.value >= 10 ? String(format: "%.0f", variable.value) : String(format: "%.2f", variable.value)) \(variable.unit)")
                                            .font(.subheadline.monospacedDigit().weight(.semibold))
                                        Text(variable.formula)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(10)
                                .background(Color.labInset, in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .padding(16)
                        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
                    }

                    // Consistency check
                    let issues = protocolConsistencyIssues(labProtocol)
                    if !issues.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("一致性检查", systemImage: "checkmark.shield")
                                .font(.headline)
                            ForEach(issues, id: \.self) { issue in
                                Label(issue, systemImage: "exclamationmark.triangle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(16)
                        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(18)
            }
            .background(Color.labBackground)
            .navigationTitle(labProtocol.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("编辑") { onEdit() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
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

    init(labProtocol: LabProtocol, saveProtocol: @escaping (LabProtocol) -> Void) {
        _draft = State(initialValue: labProtocol)
        self.saveProtocol = saveProtocol
    }

    private var consistencyIssues: [String] { protocolConsistencyIssues(draft) }
    private var scaleFactor: Double { draft.baseVolume > 0 ? 1.0 : 1.0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("基础信息") {
                    TextField("Protocol 名称", text: $draft.name)
                    Picker("实验类型", selection: $draft.area) {
                        ForEach(WorkflowArea.allCases) { area in Text(area.rawValue).tag(area) }
                    }
                    HStack {
                        Text("基准体积")
                        Spacer()
                        TextField("0", value: $draft.baseVolume, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        TextField("单位", text: $draft.volumeUnit)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 54)
                    }
                    TextField("预计时长", text: $draft.expectedDuration)
                }

                // Reagent recipe — priority section
                Section {
                    ForEach($draft.ingredients) { $ing in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("成分名称", text: $ing.name)
                                .font(.headline)
                            HStack {
                                TextField("基准用量", value: $ing.standardAmount, format: .number)
                                    .font(.title3.monospacedDigit())
                                    .frame(width: 100)
                                TextField("单位", text: $ing.unit)
                                    .frame(width: 70)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { draft.ingredients.remove(atOffsets: $0) }
                    Button {
                        draft.ingredients.append(ProtocolIngredient(name: "新成分", standardAmount: 1, unit: draft.volumeUnit))
                    } label: { Label("增加成分", systemImage: "plus.circle") }
                } header: {
                    Label("配方成分（直接可编辑）", systemImage: "flask.fill")
                        .foregroundStyle(.teal)
                }

                Section("来源") {
                    if let source = draft.source {
                        HStack {
                            Label(source.type.rawValue, systemImage: "doc.text.viewfinder")
                            Spacer()
                            Text("\(Int(source.confidence * 100))%").font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(.secondary)
                        }
                        Text(source.title).font(.subheadline)
                    } else {
                        Text("无来源信息").foregroundStyle(.secondary)
                    }
                    if consistencyIssues.isEmpty {
                        Label("变量与成分一致", systemImage: "checkmark.seal.fill").foregroundStyle(.teal)
                    } else {
                        ForEach(consistencyIssues, id: \.self) { issue in
                            Label(issue, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        }
                    }
                }

                Section("公式变量") {
                    ForEach($draft.variables) { $variable in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                TextField("符号", text: $variable.symbol).frame(width: 88)
                                TextField("名称", text: $variable.name)
                            }
                            HStack {
                                TextField("数值", value: $variable.value, format: .number)
                                TextField("单位", text: $variable.unit).frame(width: 70)
                            }
                            TextField("公式定义", text: $variable.formula).font(.body.monospaced())
                        }
                    }
                    .onDelete { draft.variables.remove(atOffsets: $0) }
                    Button {
                        draft.variables.append(ProtocolVariable(symbol: "x", name: "新变量", value: 1, unit: draft.volumeUnit, formula: ""))
                    } label: { Label("增加变量", systemImage: "plus.circle") }
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
                                    value: Binding(get: { step.durationMinutes ?? 0 }, set: { step.durationMinutes = $0 == 0 ? nil : $0 }),
                                    in: 0...240, step: 5
                                )
                            }
                            Toggle("顺延占位", isOn: $step.isCarryOver)
                        }
                    }
                    .onDelete { draft.steps.remove(atOffsets: $0) }
                    Button {
                        draft.steps.append(LabStep(id: UUID().uuidString, title: "新步骤", detail: "", durationMinutes: nil, isCarryOver: false))
                    } label: { Label("增加步骤", systemImage: "plus.circle") }
                }
            }
            .navigationTitle("编辑 Protocol")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveProtocol(draft); dismiss() }
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
                ProtocolVariable(symbol: "V_total", name: "总体积", value: extractedVolume, unit: sourceType == .kitManual ? "ul" : "ml", formula: "source.totalVolume")
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
    for v in labProtocol.variables where v.formula.contains("step.duration") {
        if !labProtocol.steps.contains(where: { $0.variableRefs.contains(v.symbol) && $0.durationMinutes != nil }) {
            issues.append("\(v.symbol) 缺少计时步骤")
        }
    }
    let dupes = Dictionary(grouping: labProtocol.variables.map(\.symbol), by: { $0 }).filter { $0.value.count > 1 }.map(\.key)
    if let dup = dupes.first { issues.append("变量 \(dup) 重复定义") }
    return issues
}
