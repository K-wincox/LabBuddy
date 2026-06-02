import SwiftUI

private enum BenchDisplayMode {
    case detail
    case full
}

struct BenchModeView: View {
    let run: LabRun
    let completedStepIDs: Set<String>
    let activeTimer: ActiveLabTimer?
    let toggleStep: (String) -> Void
    let completeRun: () -> Void
    let startTimer: (Int?) -> Void
    let pauseTimer: () -> Void
    let resumeTimer: () -> Void
    let stopTimer: () -> Void
    let showDataCard: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var stepIndex: Int
    @State private var showingCompleteAlert = false
    @State private var showTimerFlash = false
    @State private var flashOpacity = 0.8
    @State private var showCustomTimer = false
    @State private var customHours = 0
    @State private var customMins = 5
    @State private var customSecs = 0
    @State private var displayMode: BenchDisplayMode = .detail

    init(run: LabRun, completedStepIDs: Set<String>, activeTimer: ActiveLabTimer?, toggleStep: @escaping (String) -> Void, completeRun: @escaping () -> Void, startTimer: @escaping (Int?) -> Void, pauseTimer: @escaping () -> Void, resumeTimer: @escaping () -> Void, stopTimer: @escaping () -> Void, showDataCard: @escaping () -> Void) {
        self.run = run
        self.completedStepIDs = completedStepIDs
        self.activeTimer = activeTimer
        self.toggleStep = toggleStep
        self.completeRun = completeRun
        self.startTimer = startTimer
        self.pauseTimer = pauseTimer
        self.resumeTimer = resumeTimer
        self.stopTimer = stopTimer
        self.showDataCard = showDataCard
        let firstIncomplete = run.steps.firstIndex { !completedStepIDs.contains($0.id) } ?? (run.steps.count - 1)
        _stepIndex = State(initialValue: firstIncomplete)
    }

    private var steps: [LabStep] { run.steps }
    private var currentStep: LabStep { steps[safe: stepIndex] ?? steps[steps.count - 1] }
    private var isCurrentStepDone: Bool { completedStepIDs.contains(currentStep.id) }
    private var doneCount: Int { run.steps.filter { completedStepIDs.contains($0.id) }.count }
    private var isRunComplete: Bool { doneCount == steps.count }
    private var chipColor: Color {
        switch run.area {
        case .cell: return .teal
        case .cloning: return .blue
        case .blot: return .purple
        default: return .gray
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.labBackground.ignoresSafeArea()

            if displayMode == .detail {
                compactModeLayout
                    .padding(.top, 94)

                benchModeHeader
            } else {
                fullModeLayout
            }

            if showTimerFlash {
                Color.white
                    .ignoresSafeArea()
                    .opacity(flashOpacity)
                    .allowsHitTesting(false)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.3)) { flashOpacity = 0 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showTimerFlash = false
                            flashOpacity = 0.8
                        }
                    }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -80, stepIndex < steps.count - 1 {
                        withAnimation(.spring(response: 0.35)) { stepIndex += 1 }
                    } else if value.translation.width > 80, stepIndex > 0 {
                        withAnimation(.spring(response: 0.35)) { stepIndex -= 1 }
                    }
                }
        )
        .onChange(of: activeTimer?.isFinished ?? false) { _, isFinished in
            if isFinished {
                showTimerFlash = true
                flashOpacity = 0.8
            }
        }
        .sheet(isPresented: $showCustomTimer) {
            CustomTimerSheet(
                hours: $customHours,
                mins: $customMins,
                secs: $customSecs,
                onStart: {
                    let totalMins = customHours * 60 + customMins + (customSecs >= 30 ? 1 : 0)
                    startTimer(max(totalMins, 1))
                    showCustomTimer = false
                }
            )
        }
        .alert("实验完成", isPresented: $showingCompleteAlert) {
            Button("生成结果卡片") { completeRun() }
            Button("稍后处理", role: .cancel) { dismiss() }
        } message: {
            Text("所有步骤已完成，是否生成结果卡片？")
        }
    }

    private var benchModeHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(run.title)
                        .font(.title3.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .truncationMode(.tail)
                    Text("\(run.area.rawValue) · \(run.timeLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            displayMode = .full
                        }
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(chipColor)
                            .frame(width: 44, height: 44)
                            .background(chipColor.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("切换大屏模式")

                    Button(action: showDataCard) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(chipColor)
                            .frame(width: 44, height: 44)
                            .background(chipColor.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)

                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 4)
                    Capsule()
                        .fill(chipColor)
                        .frame(width: max(4, geo.size.width * CGFloat(doneCount) / CGFloat(max(1, steps.count))), height: 4)
                        .animation(.spring(response: 0.4), value: doneCount)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.labBackground)
    }

    private var compactModeLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let timer = activeTimer {
                    compactTimerDashboard(timer)
                } else if let dur = currentStep.durationMinutes, !isCurrentStepDone {
                    Button {
                        let totalSecs = dur * 60
                        customHours = totalSecs / 3600
                        customMins = (totalSecs % 3600) / 60
                        customSecs = totalSecs % 60
                        showCustomTimer = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                            Text("启动计时 \(dur) min — \(currentStep.title)")
                        }
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(chipColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { idx, step in
                        compactStepRow(idx: idx, step: step)
                        if idx < steps.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(chipColor.opacity(0.12), lineWidth: 1))

                HStack(spacing: 16) {
                    Button {
                        if stepIndex > 0 {
                            withAnimation(.spring(response: 0.35)) { stepIndex -= 1 }
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(stepIndex > 0 ? chipColor : .secondary)
                    .disabled(stepIndex == 0)

                    Button {
                        if isRunComplete {
                            showingCompleteAlert = true
                        } else {
                            if !isCurrentStepDone {
                                toggleStep(currentStep.id)
                            }
                            let nextIdx = steps.firstIndex { !completedStepIDs.contains($0.id) }
                            if let next = nextIdx {
                                withAnimation(.spring(response: 0.35)) { stepIndex = next }
                            } else if doneCount + 1 >= steps.count {
                                showingCompleteAlert = true
                            }
                        }
                    } label: {
                        Label(
                            isRunComplete ? "完成实验" : "完成此步骤",
                            systemImage: isRunComplete ? "checkmark.seal.fill" : "checkmark.circle.fill"
                        )
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isRunComplete ? .teal : chipColor)

                    Button {
                        if stepIndex < steps.count - 1 {
                            withAnimation(.spring(response: 0.35)) { stepIndex += 1 }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title2.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(stepIndex < steps.count - 1 ? chipColor : .secondary)
                    .disabled(stepIndex >= steps.count - 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private var fullModeLayout: some View {
        GeometryReader { geo in
            let safeWidth = max(0, geo.size.width - 40)
            let contentWidth = min(safeWidth, 430)

            VStack(spacing: 0) {
                fullModeHeader(contentWidth: contentWidth)

                Spacer(minLength: 18)

                VStack(spacing: 12) {
                    Text("步骤 \(stepIndex + 1)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(chipColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(currentStep.title)
                        .font(.system(size: 36, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.58)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: contentWidth)

                    Text(highlightedLabParameters(currentStep.detail))
                        .font(.system(size: 18, weight: .regular))
                        .multilineTextAlignment(.center)
                        .lineLimit(6)
                        .minimumScaleFactor(0.68)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: contentWidth)
                }
                .frame(width: contentWidth)
                .padding(.horizontal, 20)

                fullModeTimerSection(contentWidth: contentWidth)

                Spacer(minLength: 18)

                fullModeStepDots(contentWidth: contentWidth)
                    .padding(.bottom, 18)

                fullModeFooter(contentWidth: contentWidth)
                    .padding(.bottom, max(10, geo.safeAreaInsets.bottom + 8))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func fullModeHeader(contentWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(run.title)
                        .font(.title3.bold())
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .truncationMode(.tail)
                    Text("\(run.area.rawValue) · \(run.timeLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            displayMode = .detail
                        }
                    } label: {
                        Image(systemName: "rectangle.split.1x2")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(chipColor)
                            .frame(width: 44, height: 44)
                            .background(chipColor.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("切换详情模式")

                    Button(action: showDataCard) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(chipColor)
                            .frame(width: 44, height: 44)
                            .background(chipColor.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)

                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .frame(width: contentWidth)
            .padding(.top, 16)
            .padding(.bottom, 10)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 4)
                    Capsule()
                        .fill(chipColor)
                        .frame(width: max(4, geo.size.width * CGFloat(doneCount) / CGFloat(max(1, steps.count))), height: 4)
                }
            }
            .frame(width: contentWidth, height: 4)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity)
        .background(Color.labBackground)
    }

    @ViewBuilder
    private func fullModeTimerSection(contentWidth: CGFloat) -> some View {
        if let dur = currentStep.durationMinutes {
            if let timer = activeTimer, timer.stepTitle == currentStep.title {
                VStack(spacing: 14) {
                    if timer.isPaused {
                        VStack(spacing: 4) {
                            Text(formatDuration(timer.remainingSeconds))
                                .font(.system(size: 42, weight: .bold, design: .monospaced))
                                .foregroundStyle(.orange)
                            Text("已暂停")
                                .font(.caption)
                                .foregroundStyle(.orange.opacity(0.6))
                        }
                    } else {
                        CircularTimerView(totalSeconds: dur * 60, endsAt: timer.endsAt)
                    }

                    HStack(spacing: 16) {
                        if timer.isPaused {
                            Button { resumeTimer() } label: {
                                Label("继续", systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(chipColor)
                        } else {
                            Button { pauseTimer() } label: {
                                Label("暂停", systemImage: "pause.fill")
                            }
                            .buttonStyle(.bordered)
                            .tint(chipColor)
                        }
                        Button { stopTimer() } label: {
                            Label("取消", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .frame(width: contentWidth)
                .padding(.top, 14)
            } else if !isCurrentStepDone {
                Button {
                    let totalSecs = dur * 60
                    customHours = totalSecs / 3600
                    customMins = (totalSecs % 3600) / 60
                    customSecs = totalSecs % 60
                    showCustomTimer = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                        Text("启动计时 \(dur) min")
                    }
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .frame(maxWidth: contentWidth)
                    .background(chipColor, in: Capsule())
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
            }
        }
    }

    private func fullModeStepDots(contentWidth: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { idx, step in
                    Button {
                        withAnimation(.spring(response: 0.35)) { stepIndex = idx }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    idx == stepIndex ? chipColor :
                                    completedStepIDs.contains(step.id) ? chipColor.opacity(0.35) :
                                    Color.secondary.opacity(0.2)
                                )
                                .frame(width: idx == stepIndex ? 34 : 28, height: idx == stepIndex ? 34 : 28)
                            if completedStepIDs.contains(step.id) {
                                Image(systemName: "checkmark")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                            } else if idx == stepIndex {
                                Text("\(idx + 1)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(width: contentWidth)
    }

    private func fullModeFooter(contentWidth: CGFloat) -> some View {
        HStack(spacing: 18) {
            Button {
                if stepIndex > 0 {
                    withAnimation(.spring(response: 0.35)) { stepIndex -= 1 }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 54)
            }
            .buttonStyle(.bordered)
            .tint(stepIndex > 0 ? chipColor : .secondary)
            .disabled(stepIndex == 0)

            Button {
                if isRunComplete {
                    showingCompleteAlert = true
                } else {
                    if !isCurrentStepDone { toggleStep(currentStep.id) }
                    let nextIdx = steps.firstIndex { !completedStepIDs.contains($0.id) }
                    if let next = nextIdx {
                        withAnimation(.spring(response: 0.35)) { stepIndex = next }
                    } else if doneCount + 1 >= steps.count {
                        showingCompleteAlert = true
                    }
                }
            } label: {
                Label(isRunComplete ? "完成实验" : "完成此步骤", systemImage: isRunComplete ? "checkmark.seal.fill" : "checkmark.circle.fill")
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, minHeight: 58)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(isRunComplete ? .teal : chipColor)

            Button {
                if stepIndex < steps.count - 1 {
                    withAnimation(.spring(response: 0.35)) { stepIndex += 1 }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 54)
            }
            .buttonStyle(.bordered)
            .tint(stepIndex < steps.count - 1 ? chipColor : .secondary)
            .disabled(stepIndex >= steps.count - 1)
        }
        .frame(width: contentWidth)
    }

    private func compactTimerDashboard(_ timer: ActiveLabTimer) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: timer.isPaused ? "pause.circle.fill" : (timer.isFinished ? "bell.fill" : "timer"))
                    .font(.title2)
                    .foregroundStyle(timer.isPaused || timer.isFinished ? .orange : chipColor)
                Text(timer.stepTitle)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if timer.isPaused {
                    Text("已暂停")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.orange)
                } else if timer.isFinished {
                    Text("到点")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.orange)
                } else {
                    TimelineView(.periodic(from: Date(), by: 1)) { _ in
                        Text(formatDuration(timer.remainingSeconds))
                            .font(.title.monospacedDigit().weight(.bold))
                            .foregroundStyle(chipColor)
                    }
                }
            }

            if !timer.isFinished {
                HStack(spacing: 12) {
                    if timer.isPaused {
                        Button { resumeTimer() } label: {
                            Label("继续", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(chipColor)
                    } else {
                        Button { pauseTimer() } label: {
                            Label("暂停", systemImage: "pause.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(chipColor)
                    }
                    Button { stopTimer() } label: {
                        Label("取消", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
        }
        .padding(14)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(chipColor.opacity(0.15), lineWidth: 1))
    }

    private func compactStepRow(idx: Int, step: LabStep) -> some View {
        let isDone = completedStepIDs.contains(step.id)
        let isCurrent = idx == stepIndex
        let hasActiveTimer = activeTimer?.stepTitle == step.title && !(activeTimer?.isFinished ?? true)

        return Button {
            withAnimation(.spring(response: 0.35)) { stepIndex = idx }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                isCurrent ? chipColor :
                                isDone ? chipColor.opacity(0.25) :
                                Color.secondary.opacity(0.12)
                            )
                            .frame(width: isCurrent ? 34 : 30, height: isCurrent ? 34 : 30)
                        if isDone {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(idx + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(isCurrent ? .white : .secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.title)
                            .font(isCurrent ? .title3.weight(.bold) : .body.weight(.medium))
                            .strikethrough(isDone)
                            .foregroundStyle(isCurrent ? .primary : (isDone ? .secondary : .secondary))
                        Text(highlightedLabParameters(step.detail))
                            .font(isCurrent ? .body : .subheadline)
                            .lineLimit(isCurrent ? nil : 2)
                            .fixedSize(horizontal: false, vertical: isCurrent)
                    }
                    Spacer()
                    if let dur = step.durationMinutes {
                        if hasActiveTimer {
                            TimelineView(.periodic(from: Date(), by: 1)) { _ in
                                Text(formatDuration(activeTimer?.remainingSeconds ?? dur * 60))
                                    .font(.caption.monospacedDigit().weight(.bold))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.12), in: Capsule())
                            }
                        } else {
                            Label("\(dur)m", systemImage: "timer")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isCurrent ? .blue : .blue.opacity(0.6))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(isCurrent ? 0.1 : 0.06), in: Capsule())
                        }
                    }
                }

                if isCurrent && !step.reagents.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(step.reagents) { reagent in
                            reagentCompactPill(reagent)
                        }
                    }
                    .padding(.leading, 40)
                }
            }
            .padding(12)
            .background(isCurrent ? chipColor.opacity(0.06) : Color.clear)
            .overlay(alignment: .leading) {
                if isCurrent {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(chipColor)
                        .frame(width: 4)
                        .padding(.vertical, 8)
                        .padding(.leading, 2)
                }
            }
            .opacity(isCurrent ? 1 : 0.55)
        }
        .buttonStyle(.plain)
    }

    private func reagentCompactPill(_ reagent: StepReagent) -> some View {
        let amount = reagent.calculateAmount(variables: [:])
        return AnyView(
            HStack(spacing: 2) {
                Text(reagent.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let val = amount {
                    Text("\(formatCalcAmount(val))\(reagent.unit)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(chipColor)
                } else {
                    Text("\(reagent.amountExpression)\(reagent.unit)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(chipColor)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(chipColor.opacity(0.08), in: Capsule())
        )
    }

    private func formatCalcAmount(_ value: Double) -> String {
        if value >= 100 { return String(format: "%.0f", value) }
        if value >= 10 { return String(format: "%.1f", value) }
        return String(format: "%.2f", value)
    }
}


// MARK: - Circular Timer View
