import SwiftUI

struct MyWorkspaceView: View {
    @Binding var items: [InventoryItem]
    let resetDemoData: () -> Void
    @AppStorage("profileDisplayName") private var displayName = "未登录用户"
    @AppStorage("profileLabName") private var labName = "个人本地工作区"
    @AppStorage("profileLargeBenchMode") private var largeBenchMode = true
    @AppStorage("profileDataCardWatermark") private var dataCardWatermark = true
    @State private var showInventoryPage = false
    @State private var transactions: [InventoryTransaction] = {
        guard let data = UserDefaults.standard.data(forKey: "inventoryTransactions"),
              let tx = try? JSONDecoder().decode([InventoryTransaction].self, from: data) else { return [] }
        return tx
    }()

    private var lowStockItems: [InventoryItem] { items.filter(\.isLowStock) }
    private var recentItems: [InventoryItem] { Array(items.prefix(3)) }

    var body: some View {
        ZStack {
            Color.labBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    // Identity card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(Color.teal.opacity(0.18))
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
                                Text("本地个人工具 · v1")
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

                    // Inventory summary card
                    Button {
                        showInventoryPage = true
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("个人库存", systemImage: "tray.2")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                HStack(spacing: 4) {
                                    if lowStockItems.isEmpty {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.teal)
                                    } else {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                        Text("\(lowStockItems.count) 项低库存")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.orange)
                                    }
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.tertiary)
                            }

                            // Low-stock warnings
                            if !lowStockItems.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(lowStockItems.prefix(3)) { item in
                                        HStack {
                                            Image(systemName: "exclamationmark.circle.fill")
                                                .foregroundStyle(.orange)
                                                .font(.caption)
                                            Text(item.name)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            Text("\(item.quantity >= 10 ? String(format: "%.0f", item.quantity) : String(format: "%.1f", item.quantity)) \(item.unit) 剩余")
                                                .font(.caption.monospacedDigit())
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                }
                                .padding(10)
                                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                            }

                            // Recent/common items
                            VStack(alignment: .leading, spacing: 6) {
                                Text("常用试剂")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(recentItems) { item in
                                    HStack {
                                        Circle()
                                            .fill(item.isLowStock ? Color.orange : Color.teal)
                                            .frame(width: 6, height: 6)
                                        Text(item.name)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Text("\(item.quantity >= 10 ? String(format: "%.0f", item.quantity) : String(format: "%.1f", item.quantity)) \(item.unit)")
                                            .font(.caption.monospacedDigit().weight(.medium))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Text("查看全部 \(items.count) 项库存")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.teal)
                        }
                        .padding(16)
                        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    // Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("实验台偏好")
                            .font(.headline)
                        Toggle("大字号实验台模式", isOn: $largeBenchMode)
                        Toggle("结果卡片显示 LabBuddy 水印", isOn: $dataCardWatermark)
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    // Local data management
                    VStack(alignment: .leading, spacing: 12) {
                        Text("本地数据管理")
                            .font(.headline)
                        MyActionRow(icon: "square.and.arrow.up", title: "导出备份", subtitle: "将本机所有 Protocol、记录、库存导出为文件") {
                            // v1: entry point only
                        }
                        MyActionRow(icon: "square.and.arrow.down", title: "导入恢复", subtitle: "从已导出的备份文件中恢复数据") {
                            // v1: entry point only
                        }
                        MyActionRow(icon: "trash", title: "清理缓存与演示数据", subtitle: "清除所有本地演示数据，保留用户创建内容", tint: .red) {
                            resetDemoData()
                        }
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    // Future placeholders
                    VStack(alignment: .leading, spacing: 12) {
                        Text("未来账号能力（当前不可用）")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        MyActionRow(icon: "person.badge.key", title: "登录与身份", subtitle: "为 Pro 版和云备份预留 · 本地模式不启用", disabled: true) {}
                        MyActionRow(icon: "icloud", title: "云同步与协作", subtitle: "v1 保持关闭，数据仅存本机", disabled: true) {}
                        MyActionRow(icon: "creditcard", title: "Pro 订阅", subtitle: "AI 助手、语音调度等高强度功能 · 即将推出", disabled: true) {}
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(18)
            }
        }
        .navigationDestination(isPresented: $showInventoryPage) {
            InventoryPageView(items: $items, transactions: $transactions, onTransactionSaved: saveTransactions)
        }
    }

    private func saveTransactions() {
        guard let data = try? JSONEncoder().encode(transactions) else { return }
        UserDefaults.standard.set(data, forKey: "inventoryTransactions")
    }
}

// MARK: - Full Inventory Page

struct InventoryPageView: View {
    @Binding var items: [InventoryItem]
    @Binding var transactions: [InventoryTransaction]
    let onTransactionSaved: () -> Void
    @State private var searchText = ""
    @State private var editingItem: InventoryItem?
    @State private var showAddItem = false

    private var filtered: [InventoryItem] {
        if searchText.isEmpty { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.category.localizedCaseInsensitiveContains(searchText) }
    }

    private var lowStockFirst: [InventoryItem] {
        filtered.sorted { $0.isLowStock && !$1.isLowStock }
    }

    var body: some View {
        ZStack {
            Color.labBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("搜索试剂名称或分类", text: $searchText).autocorrectionDisabled()
                }
                .padding(10)
                .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 10)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(lowStockFirst) { item in
                            InventoryItemDetailCard(
                                item: binding(for: item),
                                onDeduct: { delta in record(item: item, delta: -delta) },
                                onRestock: { delta in record(item: item, delta: delta) }
                            )
                        }
                    }
                    .padding(18)
                }
            }
        }
        .navigationTitle("库存管理")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    showAddItem = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddInventoryItemSheet { newItem in
                items.insert(newItem, at: 0)
            }
        }
    }

    private func binding(for item: InventoryItem) -> Binding<InventoryItem> {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return .constant(item)
        }
        return $items[index]
    }

    private func record(item: InventoryItem, delta: Double) {
        let tx = InventoryTransaction(
            id: UUID().uuidString,
            itemID: item.id,
            itemName: item.name,
            delta: delta,
            unit: item.unit,
            note: delta < 0 ? "手动扣减" : "手动补货",
            date: Date()
        )
        transactions.insert(tx, at: 0)
        onTransactionSaved()
    }
}

// MARK: - Inventory Item Detail Card

struct InventoryItemDetailCard: View {
    @Binding var item: InventoryItem
    let onDeduct: (Double) -> Void
    let onRestock: (Double) -> Void

    private var progress: Double {
        guard item.threshold > 0 else { return 1 }
        return min(1, item.quantity / (item.threshold * 3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                    Text("\(item.category) · \(item.storage)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(item.isLowStock ? "低库存" : "充足")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background((item.isLowStock ? Color.orange : Color.teal).opacity(0.14), in: Capsule())
                    .foregroundStyle(item.isLowStock ? .orange : .teal)
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(item.quantity >= 10 ? String(format: "%.0f", item.quantity) : String(format: "%.1f", item.quantity))
                    .font(.title2.monospacedDigit().bold())
                Text(item.unit).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("阈值 \(item.threshold >= 10 ? String(format: "%.0f", item.threshold) : String(format: "%.1f", item.threshold)) \(item.unit)")
                    .font(.caption).foregroundStyle(.secondary)
            }

            ProgressView(value: progress).tint(item.isLowStock ? .orange : .teal)

            if !item.supplier.isEmpty || !item.lotNumber.isEmpty {
                HStack(spacing: 8) {
                    if !item.supplier.isEmpty {
                        Label(item.supplier, systemImage: "building.2")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if !item.lotNumber.isEmpty {
                        Label("批号 \(item.lotNumber)", systemImage: "number")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    let step = defaultDeduction(for: item.unit)
                    item.quantity = max(0, item.quantity - step)
                    onDeduct(step)
                } label: {
                    Label("扣减", systemImage: "minus.circle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)

                Button {
                    let step = defaultRestock(for: item.unit)
                    item.quantity += step
                    onRestock(step)
                } label: {
                    Label("补货", systemImage: "plus.circle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
            }
        }
        .padding(16)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            item.isLowStock
                ? RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1)
                : nil
        )
    }
}

// MARK: - Add Inventory Item Sheet

struct AddInventoryItemSheet: View {
    let onSave: (InventoryItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = "细胞实验"
    @State private var quantity = 0.0
    @State private var unit = "ml"
    @State private var threshold = 10.0
    @State private var storage = ""
    @State private var supplier = ""
    @State private var lotNumber = ""
    @State private var notes = ""

    private let categories = ["培养基", "血清", "细胞实验", "分子克隆", "WB/跑胶", "通用试剂", "其他"]

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("试剂名称", text: $name)
                    Picker("分类", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    HStack {
                        Text("当前数量")
                        Spacer()
                        TextField("0", value: $quantity, format: .number).multilineTextAlignment(.trailing).frame(width: 80)
                        TextField("单位", text: $unit).frame(width: 54)
                    }
                    HStack {
                        Text("低库存阈值")
                        Spacer()
                        TextField("0", value: $threshold, format: .number).multilineTextAlignment(.trailing).frame(width: 80)
                        Text(unit).frame(width: 54).foregroundStyle(.secondary)
                    }
                    TextField("存储位置", text: $storage)
                }
                Section("溯源信息（可选）") {
                    TextField("供应商", text: $supplier)
                    TextField("批号", text: $lotNumber)
                    TextField("备注", text: $notes)
                }
                Section {
                    Button {
                        guard !name.isEmpty else { return }
                        let item = InventoryItem(id: UUID().uuidString, name: name, category: category, quantity: quantity, unit: unit, threshold: threshold, storage: storage, lotNumber: lotNumber, supplier: supplier, notes: notes)
                        onSave(item)
                        dismiss()
                    } label: {
                        Label("添加到库存", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty)
                }
            }
            .navigationTitle("新增库存项")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
    }
}

// MARK: - My action row

struct MyActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var tint: Color = .teal
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: disabled ? {} : action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(disabled ? .secondary : tint)
                    .frame(width: 34, height: 34)
                    .background((disabled ? Color.secondary : tint).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(disabled ? .secondary : .primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if disabled {
                    Text("即将推出")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(10)
            .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

private func defaultDeduction(for unit: String) -> Double {
    switch unit {
    case "ul": return 1
    case "sheets": return 1
    default: return 10
    }
}

private func defaultRestock(for unit: String) -> Double {
    switch unit {
    case "ul": return 5
    case "sheets": return 1
    default: return 50
    }
}
