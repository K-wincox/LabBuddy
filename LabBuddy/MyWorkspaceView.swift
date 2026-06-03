import SwiftUI

// Shared inventory category list — single source of truth
enum InventoryCategories {
    static let builtIn = ["培养基", "血清", "抗体", "质粒", "酶试剂", "缓冲液", "耗材", "通用试剂", "其他"]
    static let udKey = "inventoryCustomCategories"

    static var all: [String] {
        let raw = UserDefaults.standard.string(forKey: udKey) ?? ""
        let custom = raw.isEmpty ? [] : raw.split(separator: ",").map(String.init)
        return builtIn + custom
    }

    static func add(_ name: String) {
        let raw = UserDefaults.standard.string(forKey: udKey) ?? ""
        var custom = raw.isEmpty ? [] : raw.split(separator: ",").map(String.init)
        guard !custom.contains(name) && !builtIn.contains(name) else { return }
        custom.append(name)
        UserDefaults.standard.set(custom.joined(separator: ","), forKey: udKey)
    }
}

// Unified unit system with categories
enum UnitCategory: String, CaseIterable, Identifiable {
    case volume = "体积"
    case mass = "质量"
    case concentration = "浓度"
    case count = "计数"
    case custom = "自定义"

    var id: String { rawValue }

    var builtInUnits: [String] {
        switch self {
        case .volume: return ["ml", "μl", "L"]
        case .mass: return ["g", "mg", "μg", "kg"]
        case .concentration: return ["M", "mM", "μM", "nM", "%", "mg/ml", "μg/ml"]
        case .count: return ["支", "个", "瓶", "盒", "片", "板", "管", "份"]
        case .custom: return []
        }
    }
}

enum UnifiedUnits {
    static let udKey = "unifiedCustomUnits"

    // Get all units for a specific category
    static func units(for category: UnitCategory) -> [String] {
        let builtIn = category.builtInUnits
        if category == .custom {
            let raw = UserDefaults.standard.string(forKey: udKey) ?? ""
            return raw.isEmpty ? [] : raw.split(separator: ",").map(String.init)
        }
        return builtIn
    }

    // Get all units (for backward compatibility)
    static var all: [String] {
        var result: [String] = []
        for category in UnitCategory.allCases {
            result.append(contentsOf: units(for: category))
        }
        return result
    }

    // Get units for inventory (volume + mass + count + custom)
    static var forInventory: [String] {
        units(for: .volume) + units(for: .mass) + units(for: .count) + units(for: .custom)
    }

    // Get units for calculator (volume + mass + concentration + custom)
    static var forCalculator: [String] {
        units(for: .volume) + units(for: .mass) + units(for: .concentration) + units(for: .custom)
    }

    // Get units for protocol (volume + mass + concentration + custom)
    static var forProtocol: [String] {
        units(for: .volume) + units(for: .mass) + units(for: .concentration) + units(for: .custom)
    }

    // Add custom unit
    static func addCustom(_ name: String) {
        let raw = UserDefaults.standard.string(forKey: udKey) ?? ""
        var custom = raw.isEmpty ? [] : raw.split(separator: ",").map(String.init)
        guard !custom.contains(name) && !all.contains(name) else { return }
        custom.append(name)
        UserDefaults.standard.set(custom.joined(separator: ","), forKey: udKey)
    }

    // Remove custom unit
    static func removeCustom(_ name: String) {
        let raw = UserDefaults.standard.string(forKey: udKey) ?? ""
        var custom = raw.isEmpty ? [] : raw.split(separator: ",").map(String.init)
        custom.removeAll { $0 == name }
        UserDefaults.standard.set(custom.joined(separator: ","), forKey: udKey)
    }
}

struct MyWorkspaceView: View {
    @Binding var items: [InventoryItem]
    @Binding var projects: [Project]
    let resetDemoData: () -> Void
    @AppStorage("profileDisplayName") private var displayName = "未登录用户"
    @AppStorage("profileLabName") private var labName = "个人本地工作区"
    @AppStorage("profileLargeBenchMode") private var largeBenchMode = true
    @AppStorage("profileDataCardWatermark") private var dataCardWatermark = true
    @State private var showInventoryPage = false
    @State private var showPreferences = false
    @State private var showCreateProject = false
    @State private var showAuth = false
    @EnvironmentObject private var authStore: AuthSessionStore
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
                                Text(authStore.user?.displayName.isEmpty == false ? authStore.user?.displayName ?? displayName : displayName)
                                    .font(.title3.bold())
                                Text(authStore.user?.email ?? labName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(authStore.isAuthenticated ? "已登录 · 本地数据仍存本机" : "未登录 · 本地个人工具")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(Color.teal.opacity(0.12), in: Capsule())
                                    .foregroundStyle(.teal)
                            }
                            Spacer()
                            if authStore.isAuthenticated {
                                Button {
                                    authStore.signOut()
                                } label: {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button {
                                    showAuth = true
                                } label: {
                                    Text("登录")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color.teal, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            Button {
                                showPreferences = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
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
                                    if items.isEmpty {
                                        Text("点击添加")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.teal)
                                    } else if lowStockItems.isEmpty {
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

                            if items.isEmpty {
                                // Empty state in card
                                HStack(spacing: 10) {
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(.teal.opacity(0.6))
                                    Text("还没有添加任何试剂")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            } else {
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
                        }
                        .padding(16)
                        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    // Project management
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("项目管理")
                                .font(.headline)
                            Spacer()
                            Button {
                                showCreateProject = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.teal)
                            }
                            .buttonStyle(.plain)
                        }

                        if projects.isEmpty {
                            Text("暂无项目，点击 + 新建")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(projects) { project in
                                ProjectRowView(project: project)
                            }
                        }
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
                        MyActionRow(icon: "trash", title: "清理缓存与演示数据", subtitle: "清除本机缓存与初始化数据，项目需登录后由用户自行创建", tint: .red) {
                            resetDemoData()
                        }
                    }
                    .padding(16)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    // Account and future capabilities
                    VStack(alignment: .leading, spacing: 12) {
                        Text("账号")
                            .font(.headline)
                        if authStore.isAuthenticated {
                            MyActionRow(icon: "checkmark.seal", title: "已登录", subtitle: authStore.user?.email ?? "LabBuddy 账号") {}
                            MyActionRow(icon: "rectangle.portrait.and.arrow.right", title: "退出登录", subtitle: "退出后本机实验数据不会删除", tint: .red) {
                                authStore.signOut()
                            }
                        } else {
                            MyActionRow(icon: "person.badge.key", title: "注册 / 登录", subtitle: "用于未来 Pro 权益和云备份；当前实验数据仍保存在本机") {
                                showAuth = true
                            }
                        }
                        MyActionRow(icon: "icloud", title: "云同步与协作", subtitle: "v1 保持关闭，数据仅存本机", disabled: true) {}
                        MyActionRow(icon: "creditcard", title: "Pro 订阅", subtitle: "去除结果卡片水印、AI 助手、语音调度等 · 即将推出", disabled: true) {}
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
        .sheet(isPresented: $showPreferences) {
            PreferencesSheet(largeBenchMode: $largeBenchMode, displayName: $displayName, labName: $labName)
        }
        .sheet(isPresented: $showCreateProject) {
            CreateProjectSheet { newProject in
                projects.append(newProject)
            }
        }
        .sheet(isPresented: $showAuth) {
            AuthView()
                .environmentObject(authStore)
        }
    }

    private func saveTransactions() {
        guard let data = try? JSONEncoder().encode(transactions) else { return }
        UserDefaults.standard.set(data, forKey: "inventoryTransactions")
    }
}

// MARK: - Preferences Sheet

struct PreferencesSheet: View {
    @Binding var largeBenchMode: Bool
    @Binding var displayName: String
    @Binding var labName: String
    @AppStorage("preferencesFontScale") private var fontScale = 1.0
    @AppStorage("preferencesColorScheme") private var colorSchemeRaw = "system"
    @AppStorage("preferencesHaptics") private var hapticsEnabled = true
    @AppStorage("preferencesTimerSound") private var timerSound = true
    @AppStorage("preferencesVoiceAnnouncementTemplate") private var voiceAnnouncementTemplate = "{实验}，{步骤}已完成"
    @AppStorage("isProUser") private var isProUser = false
    @AppStorage("preferencesAutoSave") private var autoSave = true
    @AppStorage("preferencesShowStepDuration") private var showStepDuration = true
    @AppStorage("preferencesCompactCards") private var compactCards = false
    @AppStorage("authAPIBaseURL") private var authAPIBaseURL = "http://172.16.8.18:8088"
    @Environment(\.dismiss) private var dismiss

    private let fontScaleOptions: [(String, Double)] = [("小", 0.85), ("标准", 1.0), ("大", 1.15), ("超大", 1.3)]
    private let schemeOptions = [("跟随系统", "system"), ("浅色", "light"), ("深色", "dark")]

    private var customWorkflowAreaCount: Int {
        let raw = UserDefaults.standard.string(forKey: "customWorkflowAreas") ?? ""
        return raw.isEmpty ? 0 : raw.split(separator: ",").count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("个人信息") {
                    TextField("显示名称", text: $displayName)
                    TextField("实验室 / 项目空间", text: $labName)
                }

                Section("服务器") {
                    TextField("API 地址", text: $authAPIBaseURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("同一局域网真机测试使用 http://172.16.8.18:8088；公网测试时改为你的公网地址。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("外观") {
                    Picker("主题", selection: $colorSchemeRaw) {
                        ForEach(schemeOptions, id: \.1) { label, value in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    HStack {
                        Text("字体大小")
                        Spacer()
                        Picker("", selection: $fontScale) {
                            ForEach(fontScaleOptions, id: \.1) { label, value in
                                Text(label).tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }

                    Toggle("紧凑卡片模式", isOn: $compactCards)
                }

                Section("实验台") {
                    Toggle("大字号实验台模式", isOn: $largeBenchMode)
                    Toggle("显示步骤计时时长", isOn: $showStepDuration)
                    Toggle("自动保存实验记录", isOn: $autoSave)
                }

                Section("通知与反馈") {
                    Toggle("计时结束提示音", isOn: $timerSound)
                    Toggle("触感反馈（Haptics）", isOn: $hapticsEnabled)
                }

                Section("单位管理") {
                    NavigationLink {
                        UnitManagementView()
                    } label: {
                        HStack {
                            Label("自定义单位", systemImage: "ruler")
                            Spacer()
                            Text("\(UnifiedUnits.units(for: .custom).count) 个")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink {
                        ExperimentTypeManagementView()
                    } label: {
                        HStack {
                            Label("自定义实验类型", systemImage: "flask")
                            Spacer()
                            Text("\(customWorkflowAreaCount) 个")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("语音播报内容").font(.headline)
                            if !isProUser {
                                Text("Pro 功能：计时到点时自动语音播报")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if isProUser {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.teal)
                        } else {
                            Text("Pro")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.teal.opacity(0.15), in: Capsule())
                                .foregroundStyle(.teal)
                        }
                    }

                    if isProUser {
                        Toggle("启用语音播报", isOn: $timerSound)
                        if timerSound {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("播报模板").font(.caption).foregroundStyle(.secondary)
                                TextField("播报内容", text: $voiceAnnouncementTemplate)
                                    .textFieldStyle(.roundedBorder)
                                Text("可用变量：{实验} {步骤}")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                HStack {
                                    Button("恢复默认") {
                                        voiceAnnouncementTemplate = "{实验}，{步骤}已完成"
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.teal)
                                    Spacer()
                                    Text("预览")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(voiceAnnouncementTemplate
                                        .replacingOccurrences(of: "{实验}", with: "293T 细胞传代")
                                        .replacingOccurrences(of: "{步骤}", with: "胰酶消化"))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.teal)
                                }
                            }
                        }
                    } else {
                        Button {
                            // Pro subscription flow - placeholder
                        } label: {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.yellow)
                                Text("升级 Pro 解锁语音自定义")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.teal)
                            }
                        }
                    }
                }

                Section {
                    MyActionRow(icon: "creditcard", title: "Pro 订阅权益", subtitle: isProUser ? "已解锁：AI 助手 · 语音调度" : "去除结果卡片水印 · AI 助手 · 语音调度 · 即将推出", disabled: !isProUser) {}
                }
            }
            .navigationTitle("偏好设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Full Inventory Page

struct InventoryPageView: View {
    @Binding var items: [InventoryItem]
    @Binding var transactions: [InventoryTransaction]
    let onTransactionSaved: () -> Void
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var showAddItem = false

    private var allCategories: [String] { InventoryCategories.all }

    private var filtered: [InventoryItem] {
        var list = items
        if let cat = selectedCategory { list = list.filter { $0.category == cat } }
        if !searchText.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.category.localizedCaseInsensitiveContains(searchText) }
        }
        return list.sorted { $0.isLowStock && !$1.isLowStock }
    }

    var body: some View {
        ZStack {
            Color.labBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("搜索试剂名称或分类", text: $searchText).autocorrectionDisabled()
                    }
                    .padding(10)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    if !allCategories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(title: "全部", isSelected: selectedCategory == nil) {
                                    selectedCategory = nil
                                }
                                ForEach(allCategories, id: \.self) { cat in
                                    FilterChip(title: cat, isSelected: selectedCategory == cat) {
                                        selectedCategory = selectedCategory == cat ? nil : cat
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 10)

                if filtered.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: items.isEmpty ? "tray.2" : "magnifyingglass")
                            .font(.system(size: 64))
                            .foregroundStyle(.teal.opacity(0.3))
                        Text(items.isEmpty ? "库存为空" : "没有匹配的试剂")
                            .font(.title3.weight(.semibold))
                        Text(items.isEmpty ? "点击右上角 + 添加试剂到库存" : "尝试调整搜索条件或分类筛选")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        if items.isEmpty {
                            Button {
                                showAddItem = true
                            } label: {
                                Label("添加试剂", systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.teal)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                } else {
                    List {
                        ForEach(filtered) { item in
                            InventoryItemDetailCard(
                                item: binding(for: item),
                                onDeduct: { delta in record(item: item, delta: -delta) },
                                onRestock: { delta in record(item: item, delta: delta) }
                            )
                            .listRowBackground(Color.labBackground)
                            .listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 18))
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    items.removeAll { $0.id == item.id }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("库存管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { showAddItem = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddInventoryItemSheet { newItem in
                items.insert(newItem, at: 0)
            }
        }
    }

    private func binding(for item: InventoryItem) -> Binding<InventoryItem> {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return .constant(item) }
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

    @State private var deductAmount: Double = 1
    @State private var showEdit = false

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

            // Deduct / amount / restock — symmetric compact row
            HStack(spacing: 10) {
                // Deduct
                Button {
                    item.quantity = max(0, item.quantity - deductAmount)
                    onDeduct(deductAmount)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                // Amount input
                HStack(spacing: 4) {
                    TextField("用量", value: $deductAmount, format: .number)
                        .multilineTextAlignment(.center)
                        .keyboardType(.decimalPad)
                        .frame(width: 56)
                        .font(.body.monospacedDigit().weight(.semibold))
                    Text(item.unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))

                Spacer()

                // Restock
                Button {
                    item.quantity += deductAmount
                    onRestock(deductAmount)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.teal)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
        .onTapGesture { showEdit = true }
        .overlay(
            item.isLowStock
                ? RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1)
                : nil
        )
        .sheet(isPresented: $showEdit) {
            EditInventoryItemSheet(item: $item)
        }
    }
}

// MARK: - Add Inventory Item Sheet

struct AddInventoryItemSheet: View {
    let onSave: (InventoryItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = "培养基"
    @State private var quantity = 0.0
    @State private var unit = "ml"
    @State private var threshold = 10.0
    @State private var storage = ""
    @State private var supplier = ""
    @State private var lotNumber = ""
    @State private var notes = ""
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    // Trigger re-read of shared lists after adding
    @State private var categoriesVersion = 0
    @State private var unitsVersion = 0

    private var allCategories: [String] {
        _ = categoriesVersion
        return InventoryCategories.all
    }

    private var allUnits: [String] {
        _ = unitsVersion
        return UnifiedUnits.forInventory
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("试剂名称", text: $name)

                    Picker("分类", selection: $category) {
                        ForEach(allCategories, id: \.self) { Text($0) }
                    }

                    Button {
                        newCategoryName = ""
                        showingAddCategory = true
                    } label: {
                        Label("新建分类", systemImage: "plus.circle")
                            .foregroundStyle(.teal)
                    }
                    .alert("新建分类", isPresented: $showingAddCategory) {
                        TextField("分类名称", text: $newCategoryName)
                        Button("添加") {
                            let n = newCategoryName.trimmingCharacters(in: .whitespaces)
                            guard !n.isEmpty else { return }
                            InventoryCategories.add(n)
                            categoriesVersion += 1
                            category = n
                        }
                        Button("取消", role: .cancel) { }
                    } message: { Text("新分类将出现在分类选择中") }

                    HStack {
                        Text("当前数量")
                        Spacer()
                        TextField("0", value: $quantity, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                            .keyboardType(.decimalPad)
                            .font(.body.monospacedDigit())
                        Picker("", selection: $unit) {
                            ForEach(allUnits, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 60)
                    }
                    HStack {
                        Text("低库存阈值")
                        Spacer()
                        TextField("0", value: $threshold, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                            .keyboardType(.decimalPad)
                            .font(.body.monospacedDigit())
                        Text(unit.isEmpty ? "单位" : unit)
                            .frame(width: 44, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }
                    TextField("存储位置", text: $storage)
                }
                Section("溯源信息（可选）") {
                    TextField("供应商", text: $supplier)
                    TextField("批号", text: $lotNumber)
                    TextField("备注", text: $notes)
                }
            }
            .navigationTitle("新增库存项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard !name.isEmpty else { return }
                        let item = InventoryItem(id: UUID().uuidString, name: name, category: category, quantity: quantity, unit: unit, threshold: threshold, storage: storage, lotNumber: lotNumber, supplier: supplier, notes: notes)
                        onSave(item)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Inventory Item Sheet

struct EditInventoryItemSheet: View {
    @Binding var item: InventoryItem
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var category: String
    @State private var quantity: Double
    @State private var unit: String
    @State private var threshold: Double
    @State private var storage: String
    @State private var supplier: String
    @State private var lotNumber: String
    @State private var notes: String
    @State private var unitsVersion = 0

    init(item: Binding<InventoryItem>) {
        self._item = item
        let it = item.wrappedValue
        _name = State(initialValue: it.name)
        _category = State(initialValue: it.category)
        _quantity = State(initialValue: it.quantity)
        _unit = State(initialValue: it.unit)
        _threshold = State(initialValue: it.threshold)
        _storage = State(initialValue: it.storage)
        _supplier = State(initialValue: it.supplier)
        _lotNumber = State(initialValue: it.lotNumber)
        _notes = State(initialValue: it.notes)
    }

    private var allCategories: [String] { InventoryCategories.all }
    private var allUnits: [String] {
        _ = unitsVersion
        return UnifiedUnits.forInventory
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("试剂名称", text: $name)
                    Picker("分类", selection: $category) {
                        ForEach(allCategories, id: \.self) { Text($0) }
                    }
                    HStack {
                        Text("当前数量")
                        Spacer()
                        TextField("0", value: $quantity, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                            .keyboardType(.decimalPad)
                            .font(.body.monospacedDigit())
                        Picker("", selection: $unit) {
                            ForEach(allUnits, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 60)
                    }
                    HStack {
                        Text("低库存阈值")
                        Spacer()
                        TextField("0", value: $threshold, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                            .keyboardType(.decimalPad)
                            .font(.body.monospacedDigit())
                        Text(unit.isEmpty ? "单位" : unit)
                            .frame(width: 44, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }
                    TextField("存储位置", text: $storage)
                }
                Section("溯源信息（可选）") {
                    TextField("供应商", text: $supplier)
                    TextField("批号", text: $lotNumber)
                    TextField("备注", text: $notes)
                }
            }
            .navigationTitle("编辑库存")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard !name.isEmpty else { return }
                        item.name = name
                        item.category = category
                        item.quantity = quantity
                        item.unit = unit
                        item.threshold = threshold
                        item.storage = storage
                        item.supplier = supplier
                        item.lotNumber = lotNumber
                        item.notes = notes
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
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

// MARK: - Project Row View

struct ProjectRowView: View {
    let project: Project
    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: project.colorHex))
                    .frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 3) {
                    Text(project.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if !project.description.isEmpty {
                        Text(project.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            ProjectDetailView(project: project)
        }
    }
}

// MARK: - Create Project Sheet

struct CreateProjectSheet: View {
    let onSave: (Project) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedColorHex = Project.palette[0].hex
    @State private var description = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        NavigationStack {
            Form {
                Section("项目名称") {
                    TextField("例如：CRISPR 敲除验证", text: $name)
                }
                Section("颜色标识") {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Project.palette, id: \.hex) { item in
                            ZStack {
                                Circle()
                                    .fill(Color(hex: item.hex))
                                    .frame(width: 40, height: 40)
                                    .onTapGesture { selectedColorHex = item.hex }
                                if selectedColorHex == item.hex {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("描述（可选）") {
                    TextField("项目目标或备注", text: $description)
                }
            }
            .navigationTitle("新建项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        let project = Project(name: name.trimmingCharacters(in: .whitespaces), colorHex: selectedColorHex, description: description.trimmingCharacters(in: .whitespaces))
                        onSave(project)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Project Detail View

struct ProjectDetailView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("项目信息") {
                    HStack {
                        Text("名称")
                        Spacer()
                        Text(project.name).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("颜色")
                        Spacer()
                        Circle()
                            .fill(Color(hex: project.colorHex))
                            .frame(width: 18, height: 18)
                    }
                    if !project.description.isEmpty {
                        HStack {
                            Text("描述")
                            Spacer()
                            Text(project.description).foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Text("创建时间")
                        Spacer()
                        Text(project.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(project.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}


// MARK: - Unit Management View

struct UnitManagementView: View {
    @State private var customUnits: [String] = UnifiedUnits.units(for: .custom)
    @State private var showingAddUnit = false
    @State private var newUnitName = ""
    @State private var selectedCategory: UnitCategory = .volume
    @AppStorage("isProUser") private var isProUser = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(UnitCategory.allCases.filter { $0 != .custom }, id: \.self) { category in
                    DisclosureGroup {
                        ForEach(UnifiedUnits.units(for: category), id: \.self) { unit in
                            HStack {
                                Text(unit)
                                    .font(.body.monospacedDigit())
                                Spacer()
                                if isProUser {
                                    Text("内置")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.1), in: Capsule())
                                } else {
                                    Image(systemName: "lock.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(category.rawValue)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(UnifiedUnits.units(for: category).count) 个")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("内置单位")
                    Spacer()
                    if !isProUser {
                        Text("Pro 可修改")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.teal.opacity(0.12), in: Capsule())
                            .foregroundStyle(.teal)
                    }
                }
            } footer: {
                Text("内置单位根据使用场景自动显示：库存管理显示体积、质量、计数单位；计算工具显示体积、质量、浓度单位")
            }

            Section {
                ForEach(customUnits, id: \.self) { unit in
                    HStack {
                        Text(unit)
                            .font(.body.monospacedDigit())
                        Spacer()
                        Button(role: .destructive) {
                            UnifiedUnits.removeCustom(unit)
                            customUnits = UnifiedUnits.units(for: .custom)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    showingAddUnit = true
                } label: {
                    Label("添加自定义单位", systemImage: "plus.circle.fill")
                        .foregroundStyle(.teal)
                }
            } header: {
                Text("自定义单位")
            } footer: {
                Text("自定义单位会在所有场景（库存、计算工具、实验方案）中显示")
            }
        }
        .navigationTitle("单位管理")
        .navigationBarTitleDisplayMode(.inline)
        .alert("添加自定义单位", isPresented: $showingAddUnit) {
            TextField("单位名称（如：U、IU、次等）", text: $newUnitName)
            Button("添加") {
                let n = newUnitName.trimmingCharacters(in: .whitespaces)
                guard !n.isEmpty else { return }
                UnifiedUnits.addCustom(n)
                customUnits = UnifiedUnits.units(for: .custom)
                newUnitName = ""
            }
            Button("取消", role: .cancel) {
                newUnitName = ""
            }
        } message: {
            Text("自定义单位将在库存管理、计算工具和实验方案中可用")
        }
    }
}

// MARK: - Experiment Type Management View

struct ExperimentTypeManagementView: View {
    @State private var customAreas: [String] = {
        let raw = UserDefaults.standard.string(forKey: "customWorkflowAreas") ?? ""
        return raw.isEmpty ? [] : raw.split(separator: ",").map(String.init)
    }()
    @State private var showingAddArea = false
    @State private var newAreaName = ""
    @AppStorage("isProUser") private var isProUser = false

    private func saveAreas() {
        UserDefaults.standard.set(customAreas.joined(separator: ","), forKey: "customWorkflowAreas")
    }

    var body: some View {
        List {
            Section {
                ForEach(WorkflowArea.builtIn) { area in
                    HStack {
                        Text(area.rawValue)
                            .foregroundStyle(isProUser ? .primary : .secondary)
                        Spacer()
                        if !isProUser {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("内置实验类型")
                    Spacer()
                    if !isProUser {
                        Text("Pro 可修改")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.teal.opacity(0.12), in: Capsule())
                            .foregroundStyle(.teal)
                    }
                }
            }

            Section {
                ForEach(customAreas, id: \.self) { area in
                    Text(area)
                }
                .onDelete { offsets in
                    customAreas.remove(atOffsets: offsets)
                    saveAreas()
                }

                Button {
                    newAreaName = ""
                    showingAddArea = true
                } label: {
                    Label("添加自定义实验类型", systemImage: "plus.circle.fill")
                        .foregroundStyle(.teal)
                }
            } header: {
                Text("自定义实验类型")
            } footer: {
                Text("自定义类型将在新建实验和 Protocol 编辑中可用")
            }
        }
        .navigationTitle("实验类型管理")
        .navigationBarTitleDisplayMode(.inline)
        .alert("添加实验类型", isPresented: $showingAddArea) {
            TextField("类型名称（如：免疫实验）", text: $newAreaName)
            Button("添加") {
                let name = newAreaName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty, !customAreas.contains(name) else { return }
                customAreas.append(name)
                saveAreas()
                newAreaName = ""
            }
            Button("取消", role: .cancel) { newAreaName = "" }
        } message: {
            Text("自定义类型将在实验类型选择中显示")
        }
    }
}
