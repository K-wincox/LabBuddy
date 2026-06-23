import SwiftUI

struct ContentView: View {
    @State private var importedRuns: [LabRun] = []
    @State private var tomorrowRuns: [LabRun] = []
    @State private var pastDays: [ExperimentDayRecord] = []
    @State private var inventoryItems: [InventoryItem] = []
    @State private var projects: [Project] = []
    @StateObject private var authStore = AuthSessionStore()
    @AppStorage("lastLabBuddyOpenDate") private var lastOpenDate = ""
    @AppStorage("preferencesColorScheme") private var colorSchemeRaw = "system"
    @AppStorage("preferencesFontScale") private var fontScale = 1.0
    @State private var showNewDaySheet = false

    var body: some View {
        Group {
            if authStore.isAuthenticated {
                mainApp
            } else {
                AuthView(isGate: true)
            }
        }
        .onAppear {
            loadAll()
            authStore.bootstrap()
        }
        .environmentObject(authStore)
        .onChange(of: authStore.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                loadAuthenticatedWorkspace()
            }
        }
        .onChange(of: authStore.user) { _, _ in
            loadAuthenticatedWorkspace()
        }
        .onChange(of: importedRuns) { _, newValue in saveImportedRuns(newValue) }
        .onChange(of: tomorrowRuns) { _, newValue in saveTomorrowRuns(newValue) }
        .onChange(of: pastDays) { _, newValue in savePastDays(newValue) }
        .onChange(of: inventoryItems) { _, newValue in saveInventoryItems(newValue) }
        .onChange(of: projects) { _, newValue in saveProjects(newValue) }
        .sheet(isPresented: $showNewDaySheet) {
            NewDayConfirmSheet(
                confirmRollover: {
                    performRollover()
                    showNewDaySheet = false
                },
                dismiss: { showNewDaySheet = false }
            )
        }
        .preferredColorScheme(preferredColorScheme)
        .environment(\.dynamicTypeSize, preferredDynamicTypeSize)
    }

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private var preferredDynamicTypeSize: DynamicTypeSize {
        switch fontScale {
        case ..<0.95: return .small
        case 1.15..<1.25: return .large
        case 1.25...: return .xLarge
        default: return .medium
        }
    }

    private var mainApp: some View {
        NavigationStack {
            TabView {
                TodayView(importedRuns: $importedRuns, tomorrowRuns: $tomorrowRuns, pastDays: $pastDays, projects: projects, onEndDay: endDay)
                    .tabItem { Label("今日", systemImage: "calendar") }

                ProtocolLibraryView()
                    .tabItem { Label("Protocol", systemImage: "list.clipboard") }
                CalculatorToolkitView()
                    .tabItem { Label("工具", systemImage: "function") }
                NavigationStack {
                    MyWorkspaceView(items: $inventoryItems, projects: $projects, resetDemoData: resetDemoData)
                        .navigationTitle("我的")
                }
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
            }
            .tint(.teal)
        }
    }

    // MARK: - Day rollover

    private func checkNewDay() {
        let todayKey = Self.dayKey(for: Date())
        guard !importedRuns.isEmpty || !tomorrowRuns.isEmpty else {
            lastOpenDate = todayKey
            return
        }
        guard !lastOpenDate.isEmpty, lastOpenDate != todayKey else {
            if lastOpenDate.isEmpty { lastOpenDate = todayKey }
            return
        }
        showNewDaySheet = true
    }

    private func endDay() {
        performRollover()
    }

    private func performRollover() {
        let todayKey = lastOpenDate.isEmpty ? Self.dayKey(for: Date()) : lastOpenDate
        let todaysRuns = importedRuns.sortedByTimeLabel()
        if !todaysRuns.isEmpty {
            let archive = ExperimentDayRecord(
                id: "past-\(todayKey)",
                dateLabel: Self.displayDateLabel(from: todayKey),
                weekday: Self.weekdayLabel(from: todayKey),
                summary: "\(todaysRuns.count) 个实验 · 已归档",
                runs: todaysRuns
            )
            pastDays.removeAll { $0.id == archive.id }
            pastDays.insert(archive, at: 0)
        }
        importedRuns = tomorrowRuns.map {
            LabRun(id: $0.id, title: $0.title, area: $0.area, timeLabel: $0.timeLabel, status: "已排期", protocolName: $0.protocolName, scaledVolumeLabel: $0.scaledVolumeLabel, projectID: $0.projectID, steps: $0.steps)
        }
        tomorrowRuns = []
        lastOpenDate = Self.dayKey(for: Date())
    }

    // MARK: - Persistence helpers

    private func loadAuthenticatedWorkspace() {
        guard authStore.isAuthenticated else { return }
        loadAll()
        checkNewDay()
    }

    private func loadAll() {
        if let data = UserDefaults.standard.data(forKey: "importedLabRuns"),
           let runs = try? JSONDecoder().decode([LabRun].self, from: data) {
            importedRuns = runs
        } else {
            importedRuns = []
        }
        if let data = UserDefaults.standard.data(forKey: "tomorrowLabRuns"),
           let runs = try? JSONDecoder().decode([LabRun].self, from: data) {
            tomorrowRuns = runs
        } else {
            tomorrowRuns = []
        }
        if let data = UserDefaults.standard.data(forKey: "pastExperimentDays"),
           let days = try? JSONDecoder().decode([ExperimentDayRecord].self, from: data) {
            pastDays = days
        } else {
            pastDays = []
        }
        if let data = UserDefaults.standard.data(forKey: "inventoryItems"),
           let items = try? JSONDecoder().decode([InventoryItem].self, from: data) {
            inventoryItems = items
        } else {
            inventoryItems = []
        }
        if let data = UserDefaults.standard.data(forKey: "userProjects"),
           let projs = try? JSONDecoder().decode([Project].self, from: data), !projs.isEmpty {
            projects = projs
        } else {
            projects = []
        }
        normalizeImportedStepTimers()
        migrateLegacyProjects()
        seedDemoDataIfNeeded()
    }

    private func normalizeImportedStepTimers() {
        let normalizedImported = importedRuns.map(Self.normalizedStepTimers)
        let normalizedTomorrow = tomorrowRuns.map(Self.normalizedStepTimers)
        if normalizedImported != importedRuns {
            importedRuns = normalizedImported
            saveImportedRuns(importedRuns)
        }
        if normalizedTomorrow != tomorrowRuns {
            tomorrowRuns = normalizedTomorrow
            saveTomorrowRuns(tomorrowRuns)
        }
    }

    private static func normalizedStepTimers(_ run: LabRun) -> LabRun {
        guard let protocolTemplate = SampleData.protocols.first(where: { $0.name == run.protocolName }) else {
            return run
        }
        let templateDurations = Dictionary(uniqueKeysWithValues: protocolTemplate.steps.map { ($0.id, $0.durationMinutes) })
        let normalizedSteps = run.steps.map { step in
            var normalized = step
            for (templateID, duration) in templateDurations where normalized.id.hasPrefix("\(templateID)-") {
                normalized.durationMinutes = duration
                break
            }
            return normalized
        }
        guard normalizedSteps != run.steps else { return run }
        return LabRun(
            id: run.id,
            title: run.title,
            area: run.area,
            timeLabel: run.timeLabel,
            status: run.status,
            protocolName: run.protocolName,
            scaledVolumeLabel: run.scaledVolumeLabel,
            projectID: run.projectID,
            steps: normalizedSteps
        )
    }

    private func migrateLegacyProjects() {
        var needsSave = false
        let allRuns = importedRuns + tomorrowRuns + pastDays.flatMap(\.runs)
        for run in allRuns {
            if let ctx = run.projectID, !ctx.isEmpty, !projects.contains(where: { $0.id == ctx }) {
                // Legacy free-text projectContext — create a Project from it
                let newProject = Project(name: ctx, colorHex: Project.nextPaletteHex(for: projects.count), description: "")
                projects.append(newProject)
                needsSave = true
            }
        }
        // Migrate runs with legacy projectContext to projectID
        for i in importedRuns.indices {
            if let ctx = importedRuns[i].projectID, !ctx.isEmpty, projects.contains(where: { $0.id == ctx || $0.name == ctx }) {
                if let project = projects.first(where: { $0.name == ctx }) {
                    importedRuns[i].projectID = project.id
                    needsSave = true
                }
            }
        }
        if needsSave {
            saveImportedRuns(importedRuns)
            saveProjects(projects)
        }
    }

    private func saveImportedRuns(_ runs: [LabRun]) {
        guard let data = try? JSONEncoder().encode(runs) else { return }
        UserDefaults.standard.set(data, forKey: "importedLabRuns")
    }
    private func saveTomorrowRuns(_ runs: [LabRun]) {
        guard let data = try? JSONEncoder().encode(runs) else { return }
        UserDefaults.standard.set(data, forKey: "tomorrowLabRuns")
    }
    private func savePastDays(_ days: [ExperimentDayRecord]) {
        guard let data = try? JSONEncoder().encode(days) else { return }
        UserDefaults.standard.set(data, forKey: "pastExperimentDays")
    }
    private func saveInventoryItems(_ items: [InventoryItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: "inventoryItems")
    }
    private func saveProjects(_ projs: [Project]) {
        guard let data = try? JSONEncoder().encode(projs) else { return }
        UserDefaults.standard.set(data, forKey: "userProjects")
    }

    private func resetDemoData() {
        importedRuns = []
        tomorrowRuns = []
        pastDays = []
        inventoryItems = []
        projects = []
        UserDefaults.standard.removeObject(forKey: "completedStepIDs")
        UserDefaults.standard.removeObject(forKey: "activeLabTimers")
        UserDefaults.standard.removeObject(forKey: "lastLabBuddyOpenDate")
        UserDefaults.standard.removeObject(forKey: "userProjects")
        saveImportedRuns(importedRuns)
        saveTomorrowRuns(tomorrowRuns)
        savePastDays(pastDays)
        saveInventoryItems(inventoryItems)
    }

    private func seedDemoDataIfNeeded() {
        guard authStore.user?.email.lowercased() == SampleData.demoUserEmail else { return }
        let flagKey = "demoSeeded.\(SampleData.demoUserEmail).20260606.v3"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }

        importedRuns = SampleData.demoTodayRuns
        tomorrowRuns = []
        pastDays = SampleData.demoPastDays
        inventoryItems = SampleData.demoInventory
        projects = SampleData.demoProjects

        let protocols = mergeByID(SampleData.protocols + SampleData.demoProtocols)
        if let data = try? JSONEncoder().encode(protocols) {
            UserDefaults.standard.set(data, forKey: "savedProtocols")
        }
        if let data = try? JSONEncoder().encode(SampleData.demoBufferTemplates) {
            UserDefaults.standard.set(data, forKey: "customBufferTemplates")
        }

        saveImportedRuns(importedRuns)
        saveTomorrowRuns(tomorrowRuns)
        savePastDays(pastDays)
        saveInventoryItems(inventoryItems)
        saveProjects(projects)
        UserDefaults.standard.set(true, forKey: flagKey)
    }

    private func mergeByID<T: Identifiable>(_ items: [T]) -> [T] where T.ID == String {
        var seen = Set<String>()
        var merged: [T] = []
        for item in items {
            guard !seen.contains(item.id) else { continue }
            seen.insert(item.id)
            merged.append(item)
        }
        return merged
    }

    // MARK: - Date helpers

    static func dayKey(for date: Date) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func displayDateLabel(from key: String) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: key) else { return key }
        f.dateFormat = "M月d日"; return f.string(from: date)
    }

    static func weekdayLabel(from key: String) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: key) else { return "" }
        f.dateFormat = "EEE"; return f.string(from: date)
    }
}

// MARK: - New Day Confirm Sheet (Phase 4 D-08, D-09)

private struct NewDayConfirmSheet: View {
    let confirmRollover: () -> Void
    let dismiss: () -> Void

    private let messages = [
        "新的一天，继续加油 💪",
        "昨天的实验已归档，今天从头开始",
        "保持节奏，今天也会顺利的",
        "每一天的数据都值得被好好记录"
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "sunrise.fill")
                .font(.system(size: 52))
                .foregroundStyle(.teal)

            VStack(spacing: 8) {
                Text("检测到新的一天")
                    .font(.title2.bold())
                Text("是否将昨天的实验归档，并将明天的计划移入今天？")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text(messages.randomElement() ?? messages[0])
                .font(.body.italic())
                .foregroundStyle(.teal)
                .padding(.horizontal, 32)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                Button(action: confirmRollover) {
                    Text("开始新的一天")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: dismiss) {
                    Text("暂时保持现状")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(24)
        .presentationDetents([.medium])
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
