import SwiftUI

enum PlanTargetDay: String {
    case today
    case tomorrow
}

struct ScheduleRequest: Identifiable {
    let id = UUID()
    let targetDay: PlanTargetDay
    let timeLabel: String
}

private enum AddExperimentPath: String, CaseIterable, Identifiable {
    case importProtocol = "导入 Protocol"
    case manual = "手动实验"
    case carryOver = "顺延占位"
    var id: String { rawValue }
}

struct AddExperimentSheet: View {
    let request: ScheduleRequest
    let projects: [Project]
    let onAdd: (LabRun) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var path: AddExperimentPath = .importProtocol
    @State private var selectedProtocolID = SampleData.protocols.first?.id ?? ""
    @State private var targetVolume = 50.0
    @State private var targetVolumeText = "50"
    @State private var experimentName = ""
    @State private var selectedProjectID: String? = nil
    @State private var manualTitle = ""
    @State private var manualArea: WorkflowArea = .cell
    @State private var manualNote = ""
    @State private var carryOverTitle = ""
    @State private var editingTime = false
    @State private var selectedHour = 9
    @State private var selectedMinute = 0
    @State private var draftTimeLabel = ""

    private var selectedProtocol: LabProtocol {
        SampleData.protocols.first { $0.id == selectedProtocolID } ?? SampleData.protocols[0]
    }

    private var destinationTitle: String {
        let timeStr = draftTimeLabel.isEmpty ? request.timeLabel : draftTimeLabel
        return request.targetDay == .today ? "今天 \(timeStr)" : "明天 \(timeStr)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("添加方式", selection: $path) {
                        ForEach(AddExperimentPath.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("插入位置") {
                    Button {
                        editingTime.toggle()
                    } label: {
                        HStack {
                            Label(destinationTitle, systemImage: "calendar.badge.plus")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: editingTime ? "checkmark.circle.fill" : "pencil.circle")
                                .foregroundStyle(.teal)
                        }
                    }
                    .buttonStyle(.plain)

                    if editingTime {
                        HStack {
                            Picker("小时", selection: $selectedHour) {
                                ForEach(0..<24) { h in
                                    Text(String(format: "%02d", h)).tag(h)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80)
                            .onChange(of: selectedHour) { _, _ in
                                draftTimeLabel = String(format: "%02d:%02d", selectedHour, selectedMinute)
                            }

                            Text(":").font(.title2.bold())

                            Picker("分钟", selection: $selectedMinute) {
                                ForEach([0, 15, 30, 45], id: \.self) { m in
                                    Text(String(format: "%02d", m)).tag(m)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80)
                            .onChange(of: selectedMinute) { _, _ in
                                draftTimeLabel = String(format: "%02d:%02d", selectedHour, selectedMinute)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                switch path {
                case .importProtocol:
                    Section("选择 Protocol") {
                        Picker("Protocol", selection: $selectedProtocolID) {
                            ForEach(SampleData.protocols) { p in Text(p.name).tag(p.id) }
                        }
                        .onChange(of: selectedProtocolID) { _, _ in
                            if experimentName.isEmpty || experimentName == SampleData.protocols.first(where: { $0.id == selectedProtocolID })?.name {
                                experimentName = selectedProtocol.name
                            }
                        }
                    }

                    Section("实验命名") {
                        TextField("实验名称", text: $experimentName, prompt: Text(selectedProtocol.name))
                            .font(.body)
                        if !projects.isEmpty {
                            Picker("所属项目", selection: $selectedProjectID) {
                                Text("无项目").tag(nil as String?)
                                ForEach(projects) { project in
                                    HStack {
                                        Circle()
                                            .fill(Color(hex: project.colorHex))
                                            .frame(width: 8, height: 8)
                                        Text(project.name)
                                    }
                                    .tag(project.id as String?)
                                }
                            }
                            .font(.subheadline)
                        }
                    }

                    Section("体积与预览") {
                        HStack {
                            Text("目标体积")
                            Spacer()
                            TextField("体积", text: $targetVolumeText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .onChange(of: targetVolumeText) { _, newValue in
                                    if let val = Double(newValue), val >= 10, val <= 200 {
                                        targetVolume = val
                                    }
                                }
                            Text(selectedProtocol.volumeUnit)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Section("预览") {
                        LabeledContent("实验类型", value: selectedProtocol.area.rawValue)
                        LabeledContent("预计时长", value: selectedProtocol.expectedDuration)
                    }

                case .manual:
                    Section("手动实验") {
                        TextField("实验名称", text: $manualTitle)
                        Picker("实验类型", selection: $manualArea) {
                            ForEach(WorkflowArea.builtIn) { area in Text(area.rawValue).tag(area) }
                        }
                        TextField("备注（可选）", text: $manualNote)
                    }

                case .carryOver:
                    Section("顺延占位") {
                        TextField("实验名称（如：WB 一抗孵育中）", text: $carryOverTitle)
                    }
                    Section {
                        Label("顺延占位代表跨夜或长时间实验，不计入今日完成计数。", systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        let run = buildRun()
                        onAdd(run)
                        dismiss()
                    } label: {
                        Label("加入时间流", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(path == .manual && manualTitle.isEmpty || path == .carryOver && carryOverTitle.isEmpty)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .onAppear {
                if draftTimeLabel.isEmpty {
                    draftTimeLabel = request.timeLabel
                    let parts = request.timeLabel.split(separator: ":")
                    if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                        selectedHour = h
                        selectedMinute = m
                    }
                }
                if experimentName.isEmpty {
                    experimentName = selectedProtocol.name
                }
            }
        }
    }

    private func buildRun() -> LabRun {
        let ts = Int(Date().timeIntervalSince1970)
        let finalTimeLabel = draftTimeLabel.isEmpty ? request.timeLabel : draftTimeLabel

        switch path {
        case .importProtocol:
            let factor = targetVolume / selectedProtocol.baseVolume
            let recipeSummary = selectedProtocol.ingredients.prefix(3).map { "\($0.name) \($0.scaled(by: factor))" }.joined(separator: " / ")
            let dur = estimatedMinutes(from: selectedProtocol.expectedDuration)
            let steps: [LabStep] = [
                LabStep(id: "review-\(ts)", title: "核对换算配方", detail: recipeSummary, durationMinutes: nil, isCarryOver: false)
            ] + (selectedProtocol.steps.isEmpty ? [LabStep(id: "exec-\(ts)", title: "执行 Protocol", detail: selectedProtocol.name, durationMinutes: dur, isCarryOver: false)] : selectedProtocol.steps.map { s in
                LabStep(id: "\(s.id)-\(ts)", title: s.title, detail: s.detail, durationMinutes: s.durationMinutes, isCarryOver: s.isCarryOver)
            }) + [LabStep(id: "record-\(ts)", title: "记录结果", detail: "完成后生成结果卡片", durationMinutes: nil, isCarryOver: false)]

            let finalName = experimentName.trimmingCharacters(in: .whitespaces).isEmpty ? selectedProtocol.name : experimentName
            let volumeLabel = "\(formatVol(targetVolume)) \(selectedProtocol.volumeUnit) · x\(String(format: "%.2f", factor))"
            let project = selectedProjectID

            return LabRun(
                id: "import-\(request.targetDay.rawValue)-\(selectedProtocol.id)-\(ts)",
                title: finalName,
                area: selectedProtocol.area,
                timeLabel: finalTimeLabel,
                status: request.targetDay == .today ? "已排期" : "明日计划",
                protocolName: selectedProtocol.name,
                scaledVolumeLabel: volumeLabel,
                projectID: project,
                steps: steps
            )

        case .manual:
            return LabRun(
                id: "manual-\(ts)",
                title: manualTitle,
                area: manualArea,
                timeLabel: finalTimeLabel,
                status: request.targetDay == .today ? "手动" : "明日手动",
                protocolName: "手动实验",
                scaledVolumeLabel: "",
                projectID: nil,
                steps: [
                    LabStep(id: "manual-step-\(ts)", title: manualTitle, detail: manualNote.isEmpty ? "手动实验" : manualNote, durationMinutes: nil, isCarryOver: false)
                ]
            )

        case .carryOver:
            return LabRun(
                id: "carryover-\(ts)",
                title: carryOverTitle,
                area: .cell,
                timeLabel: finalTimeLabel,
                status: "顺延占位",
                protocolName: "顺延占位",
                scaledVolumeLabel: "",
                projectID: nil,
                steps: [
                    LabStep(id: "co-step-\(ts)", title: carryOverTitle, detail: "跨夜或长时间进行中", durationMinutes: nil, isCarryOver: true)
                ]
            )
        }
    }

    private func estimatedMinutes(from text: String) -> Int? {
        let digits = text.prefix { $0.isNumber }
        guard let m = Int(digits), m > 0 else { return nil }
        return m
    }

    private func formatVol(_ v: Double) -> String {
        v.rounded() == v ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}

// MARK: - Today Mode
