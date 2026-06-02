import SwiftUI
import PhotosUI
import PDFKit
@preconcurrency import Vision
#if os(iOS)
import UIKit
#endif

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
    @State private var selectedStepIndex: Int?

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
        case .animal: return .orange
        case .nucleic: return .indigo
        case .protein: return .pink
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

                                if let idx = selectedStepIndex, labProtocol.steps.indices.contains(idx) {
                                    // Focused step card
                                    let step = labProtocol.steps[idx]
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("第 \(idx + 1) 步 / 共 \(labProtocol.steps.count) 步")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Button {
                                                withAnimation { selectedStepIndex = nil }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        DetailStepCard(
                                            index: idx + 1,
                                            step: step,
                                            variables: resolvedVariables,
                                            areaColor: areaColor
                                        )
                                        .frame(maxWidth: .infinity)

                                        // Prev / Next navigation
                                        HStack(spacing: 12) {
                                            Button {
                                                if idx > 0 {
                                                    withAnimation { selectedStepIndex = idx - 1 }
                                                }
                                            } label: {
                                                Label("上一步", systemImage: "chevron.left")
                                                    .font(.subheadline.weight(.semibold))
                                                    .frame(maxWidth: .infinity)
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.regular)
                                            .disabled(idx == 0)

                                            Button {
                                                if idx < labProtocol.steps.count - 1 {
                                                    withAnimation { selectedStepIndex = idx + 1 }
                                                }
                                            } label: {
                                                Label("下一步", systemImage: "chevron.right")
                                                    .font(.subheadline.weight(.semibold))
                                                    .frame(maxWidth: .infinity)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .controlSize(.regular)
                                            .tint(areaColor)
                                            .disabled(idx == labProtocol.steps.count - 1)
                                        }
                                    }
                                    .padding(16)
                                    .background(areaColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(areaColor.opacity(0.18), lineWidth: 1))
                                }

                                // Step cards tappable for switching
                                ForEach(Array(labProtocol.steps.enumerated()), id: \.element.id) { index, step in
                                    Button {
                                        withAnimation { selectedStepIndex = index }
                                    } label: {
                                        DetailStepCard(
                                            index: index + 1,
                                            step: step,
                                            variables: resolvedVariables,
                                            areaColor: areaColor
                                        )
                                        .frame(maxWidth: .infinity)
                                        .overlay(RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedStepIndex == index ? areaColor : Color.clear, lineWidth: 2))
                                    }
                                    .buttonStyle(.plain)
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
        case .animal: return .orange
        case .nucleic: return .indigo
        case .protein: return .pink
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
                    ForEach($draft.steps) { $step in
                        let idx = draft.steps.firstIndex(where: { $0.id == step.id }) ?? 0
                        VStack(alignment: .leading, spacing: 10) {
                            // 步骤标题行
                            HStack(spacing: 8) {
                                Text("\(idx + 1)")
                                    .font(.caption.monospacedDigit().weight(.bold))
                                    .frame(width: 24, height: 24)
                                    .background(accent.opacity(0.15), in: Circle())
                                    .foregroundStyle(accent)
                                TextField("步骤名称", text: $step.title)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                            }

                            // 操作描述（多行）
                            TextField("操作描述", text: $step.detail, axis: .vertical)
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
                                    get: { step.durationMinutes },
                                    set: { $step.wrappedValue.durationMinutes = $0 }
                                ), format: .number)
                                .font(.subheadline)
                                .frame(width: 80)
                                .keyboardType(.numberPad)
                                Text("min").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .padding(.leading, 32)

                            // 试剂列表（长按删除）
                            if !step.reagents.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach($step.reagents) { $reagent in
                                        ReagentEditorRow(
                                            reagent: $reagent,
                                            variables: draft.variables,
                                            accent: accent,
                                            onDelete: {
                                                $step.wrappedValue.reagents.removeAll { $0.id == reagent.id }
                                            }
                                        )
                                        .padding(.vertical, 4)
                                    }
                                }
                                .padding(.leading, 32)
                            }

                            // 增加试剂按钮
                            Button {
                                $step.wrappedValue.reagents.append(
                                    StepReagent(id: UUID().uuidString, name: "新试剂", amountExpression: "1", unit: draft.volumeUnit)
                                )
                            } label: {
                                Label("增加试剂", systemImage: "plus.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(accent)
                            }
                            .buttonStyle(.plain)
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
    var onDelete: (() -> Void)? = nil
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
            // 删除按钮（最左边，与增加试剂按钮对齐）
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red.opacity(0.7))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }

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
    @State private var extractedText = ""
    @State private var extractedName = ""
    @State private var extractedVolume = 50.0
    @State private var selectedArea: WorkflowArea = .cell
    @State private var isProcessing = false
    @State private var statusMessage = "选择来源后会生成可编辑草稿。"
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showPDFImporter = false
    @State private var errorMessage: String?

    private var canAccept: Bool {
        !extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var previewProtocol: LabProtocol {
        ProtocolDraftParser.protocolFromText(
            extractedText,
            sourceType: sourceType,
            sourceTitle: sourceTitle,
            fallbackName: extractedName,
            baseVolume: extractedVolume,
            area: selectedArea
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    sourceHeader
                    sourceActions
                    sourceMetadata
                    extractionPreview
                    draftPreview
                    acceptButton
                }
                .padding(18)
            }
            .background(Color.labBackground.ignoresSafeArea())
            .navigationTitle("提取 Protocol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .fileImporter(isPresented: $showPDFImporter, allowedContentTypes: [.pdf]) { result in
                handlePDFImport(result)
            }
            .sheet(isPresented: $showCamera) {
                CameraCaptureView { image in
                    Task { await extractText(from: image) }
                }
            }
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                Task { await handlePhotoItem(item) }
            }
            .alert("提取失败", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("知道了", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var sourceHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(sourceType.rawValue, systemImage: sourceIcon)
                .font(.headline)
            Text(sourceDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
    }

    private var sourceActions: some View {
        VStack(spacing: 10) {
            switch sourceType {
            case .image:
                HStack(spacing: 10) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("拍照识别", systemImage: "camera.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .controlSize(.large)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("相册导入", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

            case .kitManual, .sop, .literature:
                Button {
                    showPDFImporter = true
                } label: {
                    Label(sourceType == .literature ? "选择文献 PDF" : "选择 PDF 文件", systemImage: "doc.richtext")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .controlSize(.large)
            }

            if isProcessing {
                ProgressView(statusMessage)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
    }

    private var sourceMetadata: some View {
        VStack(spacing: 12) {
            TextField("来源标题 / 文件名 / DOI / SOP 编号", text: $sourceTitle)
                .textFieldStyle(.roundedBorder)
            TextField("Protocol 名称，可留空自动推断", text: $extractedName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Picker("实验类型", selection: $selectedArea) {
                    ForEach(WorkflowArea.builtIn) { area in
                        Text(area.rawValue).tag(area)
                    }
                }
                .pickerStyle(.menu)
                Spacer()
                TextField("基准体积", value: $extractedVolume, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 96)
            }
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
    }

    private var extractionPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("提取原文")
                    .font(.headline)
                Spacer()
                Button("清空") {
                    extractedText = ""
                    statusMessage = "已清空，重新选择来源。"
                }
                .font(.caption)
                .disabled(extractedText.isEmpty)
            }
            TextEditor(text: $extractedText)
                .font(.caption)
                .frame(minHeight: 140)
                .padding(8)
                .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
            Text("可直接修改原文。下方草稿会根据这里的文本实时生成，保存前仍会进入正式编辑页核对。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
    }

    private var draftPreview: some View {
        let draft = previewProtocol
        return VStack(alignment: .leading, spacing: 10) {
            Text("草稿预览")
                .font(.headline)
            HStack {
                Text(draft.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(draft.area.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.teal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.teal.opacity(0.12), in: Capsule())
            }
            HStack {
                Label("\(draft.ingredients.count) 个试剂", systemImage: "drop")
                Label("\(draft.steps.count) 个步骤", systemImage: "list.number")
                Label(draft.expectedDuration, systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(draft.ingredients.prefix(4)) { ingredient in
                    Text("\(ingredient.name) · \(ingredient.scaled(by: 1))")
                        .font(.caption)
                }
                if draft.ingredients.count > 4 {
                    Text("还有 \(draft.ingredients.count - 4) 个试剂")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if !ProtocolDraftParser.warnings(for: extractedText).isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(ProtocolDraftParser.warnings(for: extractedText), id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
    }

    private var acceptButton: some View {
        Button {
            accept(previewProtocol)
            dismiss()
        } label: {
            Label("生成草稿并继续编辑", systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.teal)
        .controlSize(.large)
        .disabled(!canAccept || isProcessing)
    }

    private var sourceIcon: String {
        switch sourceType {
        case .image: "photo.on.rectangle.angled"
        case .literature: "doc.text.magnifyingglass"
        case .kitManual: "shippingbox"
        case .sop: "doc.text"
        }
    }

    private var sourceDescription: String {
        switch sourceType {
        case .image:
            "拍摄纸质材料，或从相册选择已有图片/截图，并用本地 OCR 识别 Protocol。"
        case .kitManual:
            "从 SOP 或试剂盒 PDF 提取文字；扫描版 PDF 暂时请先转成图片再用 OCR。"
        case .sop:
            "从实验室标准操作规程 PDF 中提取步骤、时间、温度、转速和试剂。"
        case .literature:
            "从文献 PDF 中优先提取 Methods 相关段落，并整理成可编辑草稿。"
        }
    }

    private func handlePhotoItem(_ item: PhotosPickerItem) async {
        isProcessing = true
        statusMessage = "正在读取相册图片..."
        defer { isProcessing = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "无法读取图片。"
                return
            }
            await extractText(from: image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func extractText(from image: UIImage) async {
        isProcessing = true
        statusMessage = "正在进行本地 OCR..."
        defer { isProcessing = false }
        do {
            let text = try await ProtocolTextExtractionService.recognizeText(in: image)
            extractedText = text
            statusMessage = text.isEmpty ? "没有识别到文字，请换一张更清晰的图片。" : "OCR 完成，请核对原文和草稿。"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "OCR 失败。"
        }
    }

    private func handlePDFImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            isProcessing = true
            statusMessage = "正在读取 PDF..."
            Task {
                do {
                    let text = try ProtocolTextExtractionService.extractText(fromPDF: url, preferMethods: sourceType == .literature)
                    await MainActor.run {
                        sourceTitle = sourceTitle.isEmpty ? url.deletingPathExtension().lastPathComponent : sourceTitle
                        extractedText = text
                        statusMessage = text.isEmpty ? "PDF 没有可提取文本。扫描版请先使用拍照或相册 OCR。" : "PDF 文本提取完成，请核对草稿。"
                        isProcessing = false
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        statusMessage = "PDF 提取失败。"
                        isProcessing = false
                    }
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

enum ProtocolTextExtractionService {
    static func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { return "" }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func extractText(fromPDF url: URL, preferMethods: Bool) throws -> String {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart { url.stopAccessingSecurityScopedResource() }
        }
        guard let document = PDFDocument(url: url) else { return "" }
        var pages: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index), let text = page.string else { continue }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { pages.append(trimmed) }
        }
        let fullText = pages.joined(separator: "\n\n")
        guard preferMethods else { return fullText }
        return methodsSection(from: fullText)
    }

    private static func methodsSection(from text: String) -> String {
        let lower = text.lowercased()
        let starts = ["materials and methods", "methods", "experimental procedures", "method"]
        let ends = ["results", "discussion", "references", "acknowledg"]
        guard let start = starts.compactMap({ lower.range(of: $0)?.lowerBound }).min() else {
            return text
        }
        let afterStart = lower[start...]
        let end = ends.compactMap { marker -> String.Index? in
            guard let range = afterStart.range(of: marker) else { return nil }
            return range.lowerBound > start ? range.lowerBound : nil
        }.min() ?? text.endIndex
        return String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ProtocolDraftParser {
    static func protocolFromText(_ text: String, sourceType: ProtocolSourceType, sourceTitle: String, fallbackName: String, baseVolume: Double, area: WorkflowArea) -> LabProtocol {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = fallbackName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? inferredName(from: cleanText, sourceType: sourceType)
            : fallbackName.trimmingCharacters(in: .whitespacesAndNewlines)
        let duration = totalDurationLabel(from: cleanText)
        let ingredients = inferredIngredients(from: cleanText, fallbackVolume: baseVolume)
        let steps = inferredSteps(from: cleanText)
        let unit = ingredients.first?.unit ?? (area == .cloning ? "ul" : "ml")
        return LabProtocol(
            id: "extracted-\(sourceType.id)-\(Int(Date().timeIntervalSince1970))",
            name: name,
            area: area,
            baseVolume: max(baseVolume, 1),
            volumeUnit: unit,
            expectedDuration: duration,
            ingredients: ingredients.isEmpty ? [ProtocolIngredient(name: "待核对试剂", standardAmount: max(baseVolume, 1), unit: unit)] : ingredients,
            steps: steps,
            variables: [
                ProtocolVariable(symbol: "V_total", name: "总体积", baseValue: max(baseVolume, 1), unit: unit, isScalable: true, minValue: 1, maxValue: 10000)
            ],
            source: ProtocolSource(type: sourceType, title: sourceTitle.isEmpty ? "待补充来源标题" : sourceTitle, confidence: confidence(for: cleanText))
        )
    }

    static func warnings(for text: String) -> [String] {
        let lower = text.lowercased()
        var warnings: [String] = []
        if text.trimmingCharacters(in: .whitespacesAndNewlines).count < 30 {
            warnings.append("原文较短，建议核对是否漏选段落。")
        }
        if !lower.contains("ml") && !lower.contains("µl") && !lower.contains("ul") && !lower.contains("mg") && !lower.contains("g") {
            warnings.append("没有识别到明确用量单位。")
        }
        if !lower.contains("min") && !lower.contains("hour") && !lower.contains("h") && !text.contains("分钟") && !text.contains("小时") {
            warnings.append("没有识别到明确时间参数。")
        }
        return warnings
    }

    private static func inferredName(from text: String, sourceType: ProtocolSourceType) -> String {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let cleaned = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count >= 4 && cleaned.count <= 48 { return cleaned }
        return "\(sourceType.rawValue) Protocol 草稿"
    }

    private static func inferredIngredients(from text: String, fallbackVolume: Double) -> [ProtocolIngredient] {
        let patterns = [
            #"([A-Za-z0-9α-ωΑ-Ωµμ\-\+\.\s/%]+?)\s*(\d+(?:\.\d+)?)\s*(mL|ml|µL|μL|uL|ul|L|g|mg|µg|ug|ng)"#,
            #"([\p{Han}A-Za-z0-9α-ωΑ-Ωµμ\-\+\.\s/%]+?)(\d+(?:\.\d+)?)\s*(mL|ml|µL|μL|uL|ul|L|g|mg|µg|ug|ng)"#
        ]
        var found: [ProtocolIngredient] = []
        for pattern in patterns {
            found.append(contentsOf: matches(pattern: pattern, in: text).compactMap { groups in
                guard groups.count >= 3, let amount = Double(groups[1]) else { return nil }
                let name = cleanupName(groups[0])
                guard !name.isEmpty, name.count <= 50 else { return nil }
                return ProtocolIngredient(name: name, standardAmount: amount, unit: normalizedUnit(groups[2]))
            })
        }
        var unique: [ProtocolIngredient] = []
        for item in found where !unique.contains(where: { $0.name == item.name && $0.unit == item.unit }) {
            unique.append(item)
        }
        if unique.isEmpty && fallbackVolume > 0 {
            return [ProtocolIngredient(name: "待核对总体积", standardAmount: fallbackVolume, unit: "ml")]
        }
        return Array(unique.prefix(12))
    }

    private static func inferredSteps(from text: String) -> [LabStep] {
        let rawLines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let candidateLines = rawLines.filter { line in
            line.count > 8 && (
                line.range(of: #"^\s*(\d+[\.\)]|Step\s+\d+|步骤\s*\d+)"#, options: .regularExpression) != nil
                || containsActionVerb(line)
                || containsCondition(line)
            )
        }
        let lines = candidateLines.isEmpty ? Array(rawLines.prefix(6)) : candidateLines
        let steps = lines.prefix(14).enumerated().map { index, line in
            let title = inferredStepTitle(from: line, index: index)
            return LabStep(
                id: UUID().uuidString,
                title: title,
                detail: line,
                durationMinutes: inferredDuration(from: line),
                isCarryOver: isCarryOver(line)
            )
        }
        return steps.isEmpty ? [
            LabStep(id: UUID().uuidString, title: "核对提取原文", detail: "检查试剂、用量、温度、时间和转速后再使用。", durationMinutes: nil, isCarryOver: false)
        ] : steps
    }

    private static func totalDurationLabel(from text: String) -> String {
        let minutes = inferredSteps(from: text).compactMap(\.durationMinutes).reduce(0, +)
        guard minutes > 0 else { return "待核对" }
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }

    private static func inferredDuration(from line: String) -> Int? {
        let patterns = [
            #"(\d+(?:\.\d+)?)\s*(?:min|mins|minute|minutes|分钟)"#,
            #"(\d+(?:\.\d+)?)\s*(?:h|hr|hrs|hour|hours|小时)"#
        ]
        for (idx, pattern) in patterns.enumerated() {
            if let value = firstNumber(pattern: pattern, in: line) {
                return idx == 0 ? Int(value.rounded()) : Int((value * 60).rounded())
            }
        }
        return nil
    }

    private static func confidence(for text: String) -> Double {
        let w = warnings(for: text).count
        if text.isEmpty { return 0.2 }
        return max(0.45, 0.82 - Double(w) * 0.12)
    }

    private static func isCarryOver(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.contains("overnight") || line.contains("过夜")
    }

    private static func containsActionVerb(_ line: String) -> Bool {
        let tokens = ["add", "mix", "incubate", "centrifuge", "wash", "transfer", "加入", "混匀", "孵育", "离心", "洗涤", "转移", "配置", "观察"]
        let lower = line.lowercased()
        return tokens.contains { lower.contains($0.lowercased()) }
    }

    private static func containsCondition(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.contains("rpm") || lower.contains("°c") || lower.contains("℃") || lower.contains("min") || lower.contains("ml") || lower.contains("ul") || lower.contains("µl")
    }

    private static func inferredStepTitle(from line: String, index: Int) -> String {
        var title = line.replacingOccurrences(of: #"^\s*(\d+[\.\)]|Step\s+\d+|步骤\s*\d+)\s*[:：-]?\s*"#, with: "", options: .regularExpression)
        if let separator = title.firstIndex(where: { "。.;；".contains($0) }) {
            title = String(title[..<separator])
        }
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.count > 18 { title = String(title.prefix(18)) + "..." }
        return title.isEmpty ? "步骤 \(index + 1)" : title
    }

    private static func matches(pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let nsText = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).map { match in
            (1..<match.numberOfRanges).compactMap { idx in
                let range = match.range(at: idx)
                guard range.location != NSNotFound else { return nil }
                return nsText.substring(with: range)
            }
        }
    }

    private static func firstNumber(pattern: String, in text: String) -> Double? {
        matches(pattern: pattern, in: text).first?.first.flatMap(Double.init)
    }

    private static func cleanupName(_ name: String) -> String {
        name
            .replacingOccurrences(of: #"^[\s,，。;；:\-+/\d\.]+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedUnit(_ unit: String) -> String {
        switch unit.lowercased() {
        case "μl", "µl", "ul": "ul"
        case "ml": "ml"
        default: unit
        }
    }
}

#if os(iOS)
struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: DismissAction

        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            if let image { onCapture(image) }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
#endif

// Consistency check helper (shared)
func protocolConsistencyIssues(_ labProtocol: LabProtocol) -> [String] {
    var issues: [String] = []
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
        case .animal: return .orange
        case .nucleic: return .indigo
        case .protein: return .pink
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
