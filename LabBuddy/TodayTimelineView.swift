import SwiftUI

private enum TimelineZoom {
    case overview   // full day, compressed
    case focused    // ~6h window centred on current time / first run
}

struct DayTimelineView: View {
    let targetDay: PlanTargetDay
    let runs: [LabRun]
    let completedStepIDs: Set<String>
    let activeTimers: [ActiveLabTimer]
    let projects: [Project]
    let addAtTime: (String) -> Void
    let startTimer: (LabRun, LabStep?, Int?) -> Void
    let showDataCard: (LabRun) -> Void
    let openBenchMode: (LabRun) -> Void
    let removeRun: (LabRun) -> Void
    let onUpdateRun: (LabRun) -> Void
    let toggleStep: (String) -> Void
    let pauseTimer: (ActiveLabTimer) -> Void
    let resumeTimer: (ActiveLabTimer) -> Void
    let stopTimer: (ActiveLabTimer) -> Void

    @AppStorage("preferencesCompactCards") private var compactCards = false
    @AppStorage("preferencesShowStepDuration") private var showStepDuration = true
    @State private var zoom: TimelineZoom = .overview
    @State private var showRunDetail: LabRun? = nil

    // Hour-row heights — different for each mode
    private var hourH: CGFloat {
        zoom == .overview ? 88 : 240  // overview: 88pt/hr (44pt per 30min), focused: 240pt/hr (4pt per min)
    }

    private var displayHours: [Int] { Array(0...23) }

    // Group hours into segments: consecutive empty hours are collapsed
    private var hourSegments: [(startHour: Int, endHour: Int, hasRuns: Bool)] {
        var segments: [(Int, Int, Bool)] = []
        var currentStart = 0
        var currentHasRuns = hasRunCovering(hour: 0)

        for hour in 1...23 {
            let hasRuns = hasRunCovering(hour: hour)
            if hasRuns != currentHasRuns {
                segments.append((currentStart, hour - 1, currentHasRuns))
                currentStart = hour
                currentHasRuns = hasRuns
            }
        }
        segments.append((currentStart, 23, currentHasRuns))
        return segments
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row - only + button and zoom button
            HStack {
                Button {
                    addAtTime(suggestedTimeForNewRun())
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.teal)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        zoom = (zoom == .overview) ? .focused : .overview
                    }
                } label: {
                    Label(zoom == .overview ? "聚焦当前" : "全天览", systemImage: zoom == .overview ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.teal.opacity(0.12), in: Capsule())
                        .foregroundStyle(.teal)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 16)

            // Dynamic timeline layout with collapsed empty segments
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        ForEach(hourSegments, id: \.startHour) { segment in
                            if segment.hasRuns {
                                // Show all hours in this segment
                                ForEach(segment.startHour...segment.endHour, id: \.self) { hour in
                                    DynamicHourBlock(
                                        hour: hour,
                                        runs: runs.filter { hourFromLabel($0.timeLabel) == hour },
                                        zoom: zoom,
                                        targetDay: targetDay,
                                        completedStepIDs: completedStepIDs,
                                        activeTimers: activeTimers,
                                        projects: projects,
                                        compactCards: compactCards,
                                        showStepDuration: showStepDuration,
                                        onTapRun: { showRunDetail = $0 },
                                        onStart: startTimer,
                                        onCard: showDataCard,
                                        onBench: openBenchMode,
                                        onRemove: removeRun,
                                        onUpdateRun: onUpdateRun,
                                        onToggleStep: toggleStep,
                                        onPauseTimer: pauseTimer,
                                        onResumeTimer: resumeTimer,
                                        onStopTimer: stopTimer
                                    )
                                    .id(hour)
                                }
                            } else {
                                // Collapsed empty segment
                                CollapsedEmptySegment(
                                    startHour: segment.startHour,
                                    endHour: segment.endHour
                                )
                                .id(segment.startHour)
                            }
                        }
                    }
                    .padding(.bottom, 96)
                }
                .onAppear {
                    // Auto-scroll to first experiment or current hour
                    if let firstRun = runs.first, let h = hourFromLabel(firstRun.timeLabel) {
                        // Scroll to first experiment
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(h, anchor: .top)
                            }
                        }
                    } else if targetDay == .today {
                        // No experiments, scroll to current hour
                        let currentHour = Calendar.current.component(.hour, from: Date())
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(currentHour, anchor: .top)
                            }
                        }
                    }
                }
                .onChange(of: zoom) { _, _ in
                    // Re-scroll when zoom changes
                    if let firstRun = runs.first, let h = hourFromLabel(firstRun.timeLabel) {
                        withAnimation {
                            proxy.scrollTo(h, anchor: .top)
                        }
                    }
                }
            }

            // Empty state hint
            if runs.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.plus").foregroundStyle(.teal)
                    Text("点击左上角 + 添加实验")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
        .sheet(item: $showRunDetail) { run in
            RunDetailSheet(
                run: run,
                targetDay: targetDay,
                completedStepIDs: completedStepIDs,
                activeTimer: activeTimers.first { $0.runID == run.id },
                projects: projects,
                startTimer: { step, customMin in startTimer(run, step, customMin) },
                showDataCard: { showDataCard(run) },
                removeRun: { removeRun(run) },
                updateRun: { updatedRun in
                    onUpdateRun(updatedRun)
                },
                pauseTimer: { pauseTimer($0) },
                resumeTimer: { resumeTimer($0) },
                stopTimer: { stopTimer($0) }
            )
        }
    }

    private func suggestedTimeForNewRun() -> String {
        if targetDay == .today {
            let now = Date()
            let cal = Calendar.current
            let h = cal.component(.hour, from: now)
            let m = cal.component(.minute, from: now)
            let rounded = ((m + 14) / 15) * 15
            if rounded >= 60 {
                return String(format: "%02d:00", min(h + 1, 23))
            }
            return String(format: "%02d:%02d", h, rounded)
        }
        return "09:00"
    }

    private func hourFromLabel(_ label: String) -> Int? {
        let parts = label.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]) else { return nil }
        return h
    }

    private func minuteFromLabel(_ label: String) -> Int {
        let parts = label.split(separator: ":")
        guard parts.count == 2, let m = Int(parts[1]) else { return 0 }
        return m
    }

    private func roundToNearest15(_ label: String) -> String {
        let parts = label.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return label }
        let rounded = (m / 15) * 15
        return String(format: "%02d:%02d", h, rounded)
    }

    private func hasRunCovering(hour: Int) -> Bool {
        runs.contains { runCoversHour($0, hour: hour) }
    }

    private func runCoversHour(_ run: LabRun, hour: Int) -> Bool {
        let hourStart = hour * 60
        let hourEnd = min((hour + 1) * 60, 24 * 60)
        return run.startMinuteOfDay < hourEnd && run.endMinuteOfDay > hourStart
    }

}

private struct HourRow: View {
    let hour: Int
    let hourH: CGFloat
    let isCurrentHour: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Hour label
            Text(String(format: "%02d:00", hour))
                .font(.system(size: 11, weight: isCurrentHour ? .bold : .regular, design: .monospaced))
                .foregroundStyle(isCurrentHour ? Color.teal : Color.secondary.opacity(0.7))
                .frame(width: 48, alignment: .trailing)
                .offset(y: -7)

            // Tick line
            Rectangle()
                .fill(isCurrentHour ? Color.teal.opacity(0.35) : Color.secondary.opacity(0.12))
                .frame(height: 1)
                .padding(.leading, 56)
                .offset(y: 0)

            // Half-hour sub-tick
            if hourH >= 40 {
                Rectangle()
                    .fill(Color.secondary.opacity(0.07))
                    .frame(height: 1)
                    .padding(.leading, 56)
                    .offset(y: hourH / 2)
            }
        }
        .frame(height: hourH)
    }
}

private struct CurrentTimeIndicator: View {
    let displayHours: [Int]
    let hourH: CGFloat

    private var nowFraction: CGFloat {
        let cal = Calendar.current
        let h = cal.component(.hour, from: Date())
        let m = cal.component(.minute, from: Date())
        guard let firstH = displayHours.first, displayHours.contains(h) else { return -1 }
        return CGFloat(h - firstH) * hourH + CGFloat(m) / 60.0 * hourH
    }

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { _ in
            let y = nowFraction
            if y >= 0 {
                HStack(spacing: 0) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .padding(.leading, 52)
                    Rectangle()
                        .fill(Color.red.opacity(0.7))
                        .frame(height: 1.5)
                }
                .offset(y: y)
            }
        }
    }
}

private struct RunChip: View {
    let run: LabRun
    let completedStepIDs: Set<String>
    let activeTimer: ActiveLabTimer?
    let projects: [Project]
    let compact: Bool
    let onTap: () -> Void
    let onStart: () -> Void
    let onCard: () -> Void

    private var projectName: String? {
        guard let pid = run.projectID else { return nil }
        return projects.first { $0.id == pid }?.name
    }
    private var projectColor: Color? {
        guard let pid = run.projectID, let hex = projects.first(where: { $0.id == pid })?.colorHex else { return nil }
        return Color(hex: hex)
    }

    private var doneCount: Int { run.steps.filter { completedStepIDs.contains($0.id) }.count }
    private var chipColor: Color { run.eventColor }

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(chipColor)
                .frame(width: 3)
                .frame(height: compact ? 28 : 34)
            VStack(alignment: .leading, spacing: compact ? 1 : 2) {
                Text(run.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(run.timeRangeLabel) · \(doneCount)/\(run.steps.count)步").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 3) {
                Text(run.area.rawValue)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(chipColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(chipColor)
                if let name = projectName, let color = projectColor {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(color)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(chipColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

private struct CompactOverlapRunChip: View {
    let run: LabRun
    let compact: Bool
    let onTap: () -> Void

    private var chipColor: Color { run.eventColor }

    var body: some View {
        HStack(spacing: compact ? 5 : 7) {
            RoundedRectangle(cornerRadius: 2)
                .fill(chipColor)
                .frame(width: 3, height: compact ? 24 : 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(run.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(run.timeRangeLabel)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 5 : 7)
        .background(chipColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(chipColor.opacity(0.18), lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

struct StepDetailText: View {
    let detail: String
    let isDone: Bool
    let lineLimit: Int?

    private var lines: [String] {
        detail
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if let substep = parseSubstep(line) {
                    HStack(alignment: .top, spacing: 6) {
                        Text(substep.index)
                            .font(.caption2.monospacedDigit().weight(.bold))
                            .foregroundStyle(.teal)
                            .frame(width: 18, alignment: .leading)
                        Text(highlightedLabParameters(substep.text))
                            .font(.subheadline)
                            .strikethrough(isDone)
                    }
                } else {
                    Text(highlightedLabParameters(line))
                        .font(.subheadline)
                        .strikethrough(isDone)
                }
            }
        }
        .lineLimit(lineLimit)
    }

    private func parseSubstep(_ line: String) -> (index: String, text: String)? {
        guard let match = line.range(of: #"^\d+[\.\、]\s*"#, options: .regularExpression) else { return nil }
        let index = String(line[match]).trimmingCharacters(in: CharacterSet(charactersIn: ".、 "))
        let text = String(line[match.upperBound...]).trimmingCharacters(in: .whitespaces)
        return (index, text)
    }
}

// MARK: - Expanded Run Card (for focused mode)

private struct ExpandedRunCard: View {
    let run: LabRun
    let completedStepIDs: Set<String>
    let activeTimer: ActiveLabTimer?
    let projects: [Project]
    let compact: Bool
    let showStepDuration: Bool
    let onTap: () -> Void
    let onStart: (LabStep?) -> Void
    let onCard: () -> Void
    let onBench: () -> Void
    let onRemove: (() -> Void)?
    let onToggleStep: (String) -> Void
    let onPause: (() -> Void)?
    let onResume: (() -> Void)?
    let onStop: (() -> Void)?

    private var projectName: String? {
        guard let pid = run.projectID else { return nil }
        return projects.first { $0.id == pid }?.name
    }
    private var projectColor: Color? {
        guard let pid = run.projectID, let hex = projects.first(where: { $0.id == pid })?.colorHex else { return nil }
        return Color(hex: hex)
    }

    private var doneCount: Int { run.steps.filter { completedStepIDs.contains($0.id) }.count }
    private var chipColor: Color { run.eventColor }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 10) {
            // Header - title tappable only
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(chipColor)
                    .frame(width: 4, height: compact ? 34 : 44)
                Button(action: onTap) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(run.title).font(.headline).lineLimit(1)
                        HStack(spacing: 4) {
                            Text(run.timeRangeLabel).font(.caption.monospacedDigit()).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(run.area.rawValue)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(chipColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(chipColor)
                    if let name = projectName, let color = projectColor {
                        Text(name)
                            .font(.caption2)
                            .foregroundStyle(color)
                            .lineLimit(1)
                    }
                }
            }

            // Steps list
            VStack(spacing: compact ? 3 : 6) {
                ForEach(run.steps) { step in
                    HStack(spacing: 8) {
                        Button {
                            onToggleStep(step.id)
                        } label: {
                            Image(systemName: completedStepIDs.contains(step.id) ? "checkmark.circle.fill" : "circle")
                                .font(.body)
                                .foregroundStyle(completedStepIDs.contains(step.id) ? chipColor : .secondary.opacity(0.5))
                                .frame(width: 24)
                        }
                        .buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.body.weight(.medium))
                                .strikethrough(completedStepIDs.contains(step.id))
                            StepDetailText(detail: step.detail, isDone: completedStepIDs.contains(step.id), lineLimit: 2)
                        }
                        Spacer()
                        if showStepDuration, let dur = step.durationMinutes {
                            Button {
                                onStart(step)
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "timer").font(.caption2)
                                    Text("\(dur)m").font(.caption.weight(.semibold))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.12), in: Capsule())
                                .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, compact ? 2 : 4)
                }
            }

            // Timer display
            if let timer = activeTimer {
                TimelineView(.periodic(from: Date(), by: 1)) { _ in
                    HStack {
                        Image(systemName: timer.isPaused ? "pause.circle.fill" : (timer.isFinished ? "bell.fill" : "timer"))
                            .foregroundStyle(timer.isPaused ? .orange : (timer.isFinished ? .orange : chipColor))
                        Text(timer.stepTitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        if timer.isPaused {
                            Text("已暂停")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.orange)
                        } else {
                            Text(timer.isFinished ? "到点" : formatDuration(timer.remainingSeconds))
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(timer.isFinished ? .orange : chipColor)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        timer.isPaused ? Color.orange.opacity(0.12) :
                        (timer.isFinished ? Color.orange.opacity(0.12) : chipColor.opacity(0.08)),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }
                // Pause/Resume/Stop mini controls
                if !timer.isFinished {
                    HStack(spacing: 8) {
                        if timer.isPaused {
                            Button(action: { onResume?() }) {
                                Label("继续", systemImage: "play.fill")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.mini)
                            .tint(chipColor)
                        } else {
                            Button(action: { onPause?() }) {
                                Label("暂停", systemImage: "pause.fill")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .tint(chipColor)
                        }
                        Button(action: { onStop?() }) {
                            Label("取消", systemImage: "stop.fill")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .tint(.red)
                    }
                }
            }
        }
        .padding(compact ? 9 : 12)
        .background(chipColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(chipColor.opacity(0.2), lineWidth: 1.5))
    }
}

private struct SwipeDeleteContainer<Content: View>: View {
    @Binding var isRevealed: Bool
    @Binding var dragOffset: CGFloat
    let onDelete: () -> Void
    var onSwipeStateChanged: (Bool) -> Void = { _ in }
    var fixedHeight: CGFloat? = nil
    @ViewBuilder let content: Content
    @State private var contentHeight: CGFloat = 44

    private let actionWidth: CGFloat = 82
    private let revealThreshold: CGFloat = 44

    private var actionHeight: CGFloat {
        max(fixedHeight ?? 0, contentHeight)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                onDelete()
                isRevealed = false
                dragOffset = 0
                onSwipeStateChanged(false)
            } label: {
                VStack(spacing: 5) {
                    Image(systemName: "trash.fill")
                        .font(.headline)
                    Text("删除")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(width: actionWidth)
                .frame(height: actionHeight)
                .background(Color.red, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .opacity(currentOffset < -1 ? 1 : 0)
            .allowsHitTesting(isRevealed)
            .zIndex(0)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: SwipeDeleteHeightKey.self, value: proxy.size.height)
                    }
                )
                .offset(x: currentOffset)
                .contentShape(Rectangle())
                .simultaneousGesture(deleteDrag)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        guard isRevealed else { return }
                        isRevealed = false
                        dragOffset = 0
                        onSwipeStateChanged(false)
                    }
                )
                .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isRevealed)
                .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.88), value: dragOffset)
                .zIndex(1)
        }
        .frame(maxWidth: .infinity, minHeight: actionHeight, alignment: .trailing)
        .onPreferenceChange(SwipeDeleteHeightKey.self) { height in
            if height > 0 { contentHeight = height }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var currentOffset: CGFloat {
        let base = isRevealed ? -actionWidth : 0
        return min(0, max(-actionWidth, base + dragOffset))
    }

    private var deleteDrag: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                guard isHorizontalSwipe(value) else { return }
                let horizontal = value.translation.width
                onSwipeStateChanged(true)
                dragOffset = min(max(horizontal, -actionWidth), actionWidth)
            }
            .onEnded { value in
                guard isHorizontalSwipe(value) else {
                    dragOffset = 0
                    onSwipeStateChanged(isRevealed)
                    return
                }
                let projected = currentOffset + value.predictedEndTranslation.width * 0.18
                isRevealed = projected < -revealThreshold
                onSwipeStateChanged(isRevealed)
                dragOffset = 0
            }
    }

    private func isHorizontalSwipe(_ value: DragGesture.Value) -> Bool {
        abs(value.translation.width) > abs(value.translation.height) * 1.25
    }
}

private struct SwipeDeleteHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 44

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Run Detail Sheet (from timeline chip tap)

private struct EditableDetailStepRow: View {
    let index: Int
    let step: LabStep
    let isDone: Bool
    let onTimer: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text("\(index + 1)")
                .font(.title2.monospacedDigit().weight(.bold))
                .foregroundStyle(.teal)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 38, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.headline)
                    .strikethrough(isDone)
                if !step.detail.isEmpty {
                    StepDetailText(detail: step.detail, isDone: isDone, lineLimit: nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if step.durationMinutes != nil {
                Button(action: onTimer) {
                    HStack(spacing: 3) {
                        Image(systemName: "timer").font(.caption2)
                        Text("\(step.durationMinutes ?? 0)m").font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12), in: Capsule())
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            Button(action: onEdit) {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.labInset, in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
    }
}

private struct RunDetailSheet: View {
    let run: LabRun
    let targetDay: PlanTargetDay
    let completedStepIDs: Set<String>
    let activeTimer: ActiveLabTimer?
    let projects: [Project]
    let startTimer: (LabStep?, Int?) -> Void  // (step, customMinutes)
    let showDataCard: () -> Void
    let removeRun: (() -> Void)?
    let updateRun: ((LabRun) -> Void)?
    let pauseTimer: ((ActiveLabTimer) -> Void)?
    let resumeTimer: ((ActiveLabTimer) -> Void)?
    let stopTimer: ((ActiveLabTimer) -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var editedTitle = ""
    @State private var selectedProjectID: String? = nil
    @State private var selectedHour = 9
    @State private var selectedMinute = 0
    @State private var editableSteps: [LabStep] = []
    @State private var editingStep: LabStep?
    @State private var showCustomTimer = false
    @State private var pendingStep: LabStep?
    @State private var customHours = 0
    @State private var customMins = 5
    @State private var customSecs = 0
    @State private var showingTimePicker = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("实验信息")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("实验名称", text: $editedTitle)
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if !projects.isEmpty {
                                Picker("项目", selection: $selectedProjectID) {
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
                                .pickerStyle(.menu)
                                .tint(.secondary)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                        .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("时间")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Button {
                                let parts = run.timeLabel.split(separator: ":")
                                if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                                    selectedHour = h
                                    selectedMinute = m
                                }
                                showingTimePicker = true
                            } label: {
                                Text(run.timeLabel)
                                    .font(.body.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(.teal)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                        .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                Section {
                    ForEach(Array(editableSteps.enumerated()), id: \.element.id) { index, step in
                        EditableDetailStepRow(
                            index: index,
                            step: step,
                            isDone: completedStepIDs.contains(step.id),
                            onTimer: {
                                pendingStep = step
                                if let dur = step.durationMinutes {
                                    let totalSecs = dur * 60
                                    customHours = totalSecs / 3600
                                    customMins = (totalSecs % 3600) / 60
                                    customSecs = totalSecs % 60
                                    showCustomTimer = true
                                }
                            },
                            onEdit: { editingStep = step }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteStep(id: step.id)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    Button {
                        let newStep = LabStep(
                            id: "step-\(UUID().uuidString)",
                            title: "新步骤",
                            detail: "",
                            durationMinutes: nil,
                            isCarryOver: false,
                            variableRefs: [],
                            reagents: []
                        )
                        editableSteps.append(newStep)
                        editingStep = newStep
                    } label: {
                        Label("添加步骤", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.teal)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 16, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } header: {
                    Text("步骤")
                }

                if let timer = activeTimer {
                    Section {
                        TimelineView(.periodic(from: Date(), by: 1)) { _ in
                            VStack(spacing: 10) {
                                HStack {
                                    Image(systemName: "timer")
                                        .foregroundStyle(timer.isFinished ? .orange : .teal)
                                    Text(timer.stepTitle).font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    if timer.isPaused {
                                        Text("已暂停")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.orange)
                                    }
                                    Text(timer.isFinished ? "到点" : formatDuration(timer.remainingSeconds))
                                        .font(.title3.monospacedDigit().weight(.bold))
                                        .foregroundStyle(timer.isFinished ? .orange : timer.isPaused ? .orange : .teal)
                                }
                                HStack(spacing: 12) {
                                    if timer.isPaused {
                                        Button { resumeTimer?(timer) } label: {
                                            Label("继续", systemImage: "play.fill").frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.borderedProminent).tint(.teal)
                                    } else if !timer.isFinished {
                                        Button { pauseTimer?(timer) } label: {
                                            Label("暂停", systemImage: "pause.fill").frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.bordered).tint(.teal)
                                    }
                                    Button { stopTimer?(timer) } label: {
                                        Label("取消", systemImage: "stop.fill").frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered).tint(.red)
                                }
                            }
                            .padding(12)
                            .background(timer.isFinished ? Color.orange.opacity(0.12) : timer.isPaused ? Color.orange.opacity(0.08) : Color.labInset, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 16, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("运行中的计时器")
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.labBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(editedTitle.isEmpty ? run.title : editedTitle)
                        .font(.headline)
                        .lineLimit(1)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("保存") {
                        updateRun?(updatedRunFromState())
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showDataCard()
                        dismiss()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingTimePicker) {
                TimePickerSheet(
                    hour: $selectedHour,
                    minute: $selectedMinute,
                    onApply: {
                        showingTimePicker = false
                    }
                )
            }
            .sheet(item: $editingStep) { step in
                StepEditorSheet(
                    step: step,
                    onSave: { updated in
                        if let idx = editableSteps.firstIndex(where: { $0.id == updated.id }) {
                            editableSteps[idx] = updated
                        }
                    }
                )
            }
            .sheet(isPresented: $showCustomTimer) {
                CustomTimerSheet(
                    hours: $customHours,
                    mins: $customMins,
                    secs: $customSecs,
                    onStart: {
                        let totalMins = customHours * 60 + customMins + (customSecs >= 30 ? 1 : 0)
                        startTimer(pendingStep, max(totalMins, 1))
                        showCustomTimer = false
                    }
                )
            }
        }
        .onAppear {
            editedTitle = run.title
            selectedProjectID = run.projectID
            editableSteps = run.steps
            let parts = run.timeLabel.split(separator: ":")
            if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                selectedHour = h
                selectedMinute = m
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func updatedRunFromState() -> LabRun {
        let trimmedTitle = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return LabRun(
            id: run.id,
            title: trimmedTitle.isEmpty ? run.title : trimmedTitle,
            area: run.area,
            timeLabel: String(format: "%02d:%02d", selectedHour, selectedMinute),
            status: run.status,
            protocolName: run.protocolName,
            scaledVolumeLabel: run.scaledVolumeLabel,
            projectID: selectedProjectID,
            steps: editableSteps
        )
    }

    private func deleteStep(id: String) {
        editableSteps.removeAll { $0.id == id }
        updateRun?(updatedRunFromState())
    }

}

// MARK: - Custom Timer Sheet


private struct TimePickerSheet: View {
    @Binding var hour: Int
    @Binding var minute: Int
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                HStack(spacing: 0) {
                    Picker("时", selection: $hour) {
                        ForEach(0..<24) { h in Text(String(format: "%02d", h)).tag(h) }
                    }
                    .pickerStyle(.wheel).frame(width: 80)
                    Text(":").font(.title2.bold())
                    Picker("分", selection: $minute) {
                        ForEach([0, 15, 30, 45], id: \.self) { m in Text(String(format: "%02d", m)).tag(m) }
                    }
                    .pickerStyle(.wheel).frame(width: 80)
                }
                .frame(height: 180)

                Button {
                    onApply()
                    dismiss()
                } label: {
                    Text("应用").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(.teal).padding(.horizontal)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
        .presentationDetents([.height(280)])
    }
}

// MARK: - Step Editor Sheet

private struct StepEditorSheet: View {
    let step: LabStep
    let onSave: (LabStep) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var detail: String
    @State private var durationMinutes: Int?
    @State private var hasDuration: Bool
    @State private var durValue = 5

    init(step: LabStep, onSave: @escaping (LabStep) -> Void) {
        self.step = step
        self.onSave = onSave
        _title = State(initialValue: step.title)
        _detail = State(initialValue: step.detail)
        _durationMinutes = State(initialValue: step.durationMinutes)
        _hasDuration = State(initialValue: step.durationMinutes != nil)
        if let d = step.durationMinutes { _durValue = State(initialValue: d) }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("步骤名称", text: $title)
                TextField("详细说明（可选）", text: $detail, axis: .vertical)
                    .lineLimit(3...8)
                Button {
                    appendSubstep()
                } label: {
                    Label("添加分步骤", systemImage: "list.number")
                }
                Toggle("需要计时", isOn: $hasDuration)
                if hasDuration {
                    HStack {
                        Text("时长（分钟）")
                        Spacer()
                        TextField("分钟", value: $durValue, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle("编辑步骤")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var updated = step
                        updated.title = title
                        updated.detail = detail
                        updated.durationMinutes = hasDuration ? durValue : nil
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
    }

    private func appendSubstep() {
        let existing = detail
            .split(separator: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).range(of: #"^\d+\."#, options: .regularExpression) != nil }
            .count
        let prefix = detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\n"
        detail += "\(prefix)\(existing + 1). 新分步骤"
    }
}

// MARK: - Run Card

private struct RunCard: View {
    let run: LabRun
    let completedStepIDs: Set<String>
    let activeTimer: ActiveLabTimer?
    let toggleStep: (String) -> Void
    let startTimer: () -> Void
    let showDataCard: () -> Void
    let openBenchMode: () -> Void
    let removeRun: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(run.timeLabel).font(.title2.monospacedDigit().bold())
                    Text(run.status).font(.caption.weight(.semibold))
                        .foregroundStyle(run.status == "顺延占位" ? .orange : .teal)
                }
                .frame(width: 76, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text(run.title).font(.headline)
                    Text("\(run.area.rawValue) · \(run.protocolName)").font(.subheadline).foregroundStyle(.secondary)
                    if !run.scaledVolumeLabel.isEmpty {
                        Text(run.scaledVolumeLabel).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            VStack(spacing: 10) {
                ForEach(run.steps) { step in
                    StepRow(step: step, isDone: completedStepIDs.contains(step.id), toggle: { toggleStep(step.id) })
                }
            }

            HStack(spacing: 10) {
                Button(action: openBenchMode) {
                    Label("实验台", systemImage: "rectangle.portrait.and.arrow.right").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)

                Button(action: startTimer) {
                    Label(activeTimer == nil ? "启动计时" : "重新计时", systemImage: activeTimer == nil ? "play.fill" : "arrow.clockwise").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)

                if let t = activeTimer {
                    TimelineView(.periodic(from: Date(), by: 1)) { _ in
                        Text(t.isFinished ? "到点" : formatDuration(t.remainingSeconds))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(t.isFinished ? .orange : .teal)
                            .frame(width: 82, height: 44)
                            .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                Button(action: showDataCard) {
                    Image(systemName: "square.and.arrow.up").frame(width: 46, height: 28)
                }
                .buttonStyle(.bordered).controlSize(.large).accessibilityLabel("生成结果卡片")

                if let removeRun {
                    Button(action: removeRun) {
                        Image(systemName: "trash").frame(width: 46, height: 28)
                    }
                    .buttonStyle(.bordered).controlSize(.large).foregroundStyle(.red).accessibilityLabel("移除实验")
                }
            }
        }
        .padding(16)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Step Row

private struct StepRow: View {
    let step: LabStep
    let isDone: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundStyle(isDone ? .teal : .secondary).frame(width: 44, height: 44)
            }
            .accessibilityLabel(isDone ? "标记未完成" : "标记完成")

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title).font(.subheadline.weight(.semibold)).strikethrough(isDone)
                Text(highlightedLabParameters(step.detail)).font(.caption)
            }
            Spacer()
            if let dur = step.durationMinutes {
                Label("\(dur)m", systemImage: "timer")
                    .font(.caption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Color.blue.opacity(0.12), in: Capsule()).foregroundStyle(.blue)
            }
        }
        .padding(10)
        .background(Color.labInset, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Bench Mode (Electronic Protocol Display)



private struct CollapsedEmptySegment: View {
    let startHour: Int
    let endHour: Int

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Text(String(format: "%02d:00", startHour))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .frame(width: 48, alignment: .trailing)

                Rectangle()
                    .fill(Color.secondary.opacity(0.08))
                    .frame(height: 1)

                Text(String(format: "%02d:00", endHour))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 8)

            Text("· · ·")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.3))
        }
        .frame(height: 32)
        .padding(.vertical, 4)
    }
}

// MARK: - Dynamic Hour Block

private struct OverviewRunPlacement: Identifiable {
    let run: LabRun
    let column: Int
    let columnCount: Int

    var id: String { run.id }
}

private struct DynamicHourBlock: View {
    let hour: Int
    let runs: [LabRun]
    let zoom: TimelineZoom
    let targetDay: PlanTargetDay
    let completedStepIDs: Set<String>
    let activeTimers: [ActiveLabTimer]
    let projects: [Project]
    let compactCards: Bool
    let showStepDuration: Bool
    let onTapRun: (LabRun) -> Void
    let onStart: (LabRun, LabStep?, Int?) -> Void
    let onCard: (LabRun) -> Void
    let onBench: (LabRun) -> Void
    let onRemove: (LabRun) -> Void
    let onUpdateRun: (LabRun) -> Void
    let onToggleStep: (String) -> Void
    let onPauseTimer: ((ActiveLabTimer) -> Void)?
    let onResumeTimer: ((ActiveLabTimer) -> Void)?
    let onStopTimer: ((ActiveLabTimer) -> Void)?

    private var isCurrentHour: Bool {
        targetDay == .today && Calendar.current.component(.hour, from: Date()) == hour
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TimelineTimeRule(
                label: String(format: "%02d:00", hour),
                tint: isCurrentHour ? Color.teal : Color.secondary,
                prominence: isCurrentHour ? 0.35 : 0.12,
                labelOpacity: isCurrentHour ? 1 : 0.7,
                labelWeight: isCurrentHour ? .bold : .regular
            )

            // Experiment content area
            if runs.isEmpty {
                // Empty space - minimal
                Color.clear
                    .frame(height: zoom == .overview ? 24 : 32)
            } else {
                Group {
                    if zoom == .overview {
                        GeometryReader { proxy in
                            let placements = overviewPlacements()
                            let isParallel = placements.first?.columnCount ?? 1 > 1
                            let spacing: CGFloat = 0
                            let columns = CGFloat(min(max(placements.first?.columnCount ?? 1, 1), 3))
                            let leadingGutter: CGFloat = isParallel ? 62 : 0
                            let columnWidth = max(44, (proxy.size.width - leadingGutter - spacing * (columns - 1)) / columns)

                            ZStack(alignment: .topLeading) {
                                ForEach(placements) { placement in
                                    let layout = eventLayout(for: placement.run, isOverlapping: placement.columnCount > 1)
                                    durationEvent(for: placement.run, minHeight: layout.cardHeight, isOverlapping: placement.columnCount > 1)
                                        .frame(width: columnWidth, alignment: .leading)
                                        .offset(
                                            x: leadingGutter + CGFloat(placement.column) * (columnWidth + spacing),
                                            y: layout.y
                                        )
                                }
                            }
                        }
                        .frame(height: eventAreaHeight)
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(runs.sorted(by: { minuteFrom($0.timeLabel) < minuteFrom($1.timeLabel) })) { run in
                                let layout = eventLayout(for: run)
                                durationEvent(for: run, minHeight: 0, isOverlapping: false)
                                    .padding(.top, layout.y)
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
                .padding(.trailing, 8)
            }

            // Current time indicator (if applicable)
            if targetDay == .today && isCurrentHour {
                CurrentTimeIndicatorInHour()
            }
        }
    }

    private func minuteFrom(_ label: String) -> Int {
        let parts = label.split(separator: ":")
        guard parts.count == 2, let m = Int(parts[1]) else { return 0 }
        return m
    }

    private var eventAreaHeight: CGFloat {
        let fallback: CGFloat = zoom == .overview ? 72 : 160
        let placements = overviewPlacements()
        if zoom == .overview, !placements.isEmpty {
            return max(fallback, placements.map { eventLayout(for: $0.run, isOverlapping: $0.columnCount > 1).bottom }.max() ?? fallback)
        }
        return max(fallback, runs.map { eventLayout(for: $0).bottom }.max() ?? fallback)
    }

    private func overviewPlacements() -> [OverviewRunPlacement] {
        let sorted = runs.sorted {
            if $0.startMinuteOfDay == $1.startMinuteOfDay {
                return $0.endMinuteOfDay < $1.endMinuteOfDay
            }
            return $0.startMinuteOfDay < $1.startMinuteOfDay
        }

        var active: [(run: LabRun, column: Int)] = []
        var assigned: [(run: LabRun, column: Int)] = []

        for run in sorted {
            active.removeAll { $0.run.endMinuteOfDay <= run.startMinuteOfDay }
            let usedColumns = Set(active.map(\.column))
            var column = 0
            while usedColumns.contains(column), column < 2 {
                column += 1
            }
            active.append((run, column))
            assigned.append((run, column))
        }

        let columnCount = max((assigned.map(\.column).max() ?? 0) + 1, 1)
        return assigned.map { OverviewRunPlacement(run: $0.run, column: $0.column, columnCount: columnCount) }
    }

    private func eventLayout(for run: LabRun, isOverlapping: Bool = false) -> (y: CGFloat, cardHeight: CGFloat, bottom: CGFloat) {
        let minuteHeight = max(1.2, (zoom == .overview ? 1.2 : 2.8))
        let startOffset = CGFloat(run.startMinuteOfDay - hour * 60)
        let y = max(0, startOffset) * minuteHeight
        let durationHeight = CGFloat(run.scheduledDurationMinutes) * minuteHeight
        let overviewMinimum: CGFloat = compactCards ? (isOverlapping ? 38 : 52) : (isOverlapping ? 46 : 64)
        let focusedStepHeight = compactCards ? 42 : 58
        let focusedMinimum = CGFloat(max(compactCards ? 190 : 240, run.steps.count * focusedStepHeight + (compactCards ? 112 : 150)))
        let contentMinimum: CGFloat = zoom == .overview ? overviewMinimum : focusedMinimum
        let cardHeight = max(durationHeight, contentMinimum)
        let startRuleHeight: CGFloat = run.startMinuteOfDay % 60 == 0 ? 0 : 18
        let endRuleHeight: CGFloat = 34
        return (y, cardHeight, y + startRuleHeight + cardHeight + endRuleHeight)
    }

    private func durationEvent(for run: LabRun, minHeight: CGFloat, isOverlapping: Bool) -> some View {
        RunDurationEvent(
            run: run,
            zoom: zoom,
            minHeight: minHeight,
            isOverlapping: isOverlapping,
            startsOnHourLine: run.startMinuteOfDay % 60 == 0,
            completedStepIDs: completedStepIDs,
            activeTimer: activeTimers.first { $0.runID == run.id },
            projects: projects,
            compact: compactCards,
            showStepDuration: showStepDuration,
            onTapRun: { onTapRun(run) },
            onStart: { step in onStart(run, step, nil) },
            onCard: { onCard(run) },
            onBench: { onBench(run) },
            onRemove: { onRemove(run) },
            onUpdateRun: { onUpdateRun($0) },
            suppressTimelineGutter: zoom == .overview && isOverlapping,
            onToggleStep: onToggleStep,
            onPause: { if let t = activeTimers.first(where: { $0.runID == run.id }) { onPauseTimer?(t) } },
            onResume: { if let t = activeTimers.first(where: { $0.runID == run.id }) { onResumeTimer?(t) } },
            onStop: { if let t = activeTimers.first(where: { $0.runID == run.id }) { onStopTimer?(t) } }
        )
    }
}

private struct RunDurationEvent: View {
    let run: LabRun
    let zoom: TimelineZoom
    let minHeight: CGFloat
    let isOverlapping: Bool
    let startsOnHourLine: Bool
    let completedStepIDs: Set<String>
    let activeTimer: ActiveLabTimer?
    let projects: [Project]
    let compact: Bool
    let showStepDuration: Bool
    let onTapRun: () -> Void
    let onStart: (LabStep?) -> Void
    let onCard: () -> Void
    let onBench: () -> Void
    let onRemove: () -> Void
    let onUpdateRun: (LabRun) -> Void
    let suppressTimelineGutter: Bool
    let onToggleStep: (String) -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    @State private var runDragOffset: CGFloat = 0
    @State private var isRunDeleteRevealed = false
    @State private var suppressNextTap = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !startsOnHourLine {
                TimelineTimeRule(
                    label: run.timeLabel,
                    tint: .secondary,
                    prominence: 0.12,
                    labelOpacity: 0.58,
                    labelWeight: .regular
                )
            }

            HStack(alignment: .top, spacing: 0) {
                if !suppressTimelineGutter {
                    Color.clear.frame(width: 54)
                }

                if zoom == .overview {
                    SwipeDeleteContainer(
                        isRevealed: $isRunDeleteRevealed,
                        dragOffset: $runDragOffset,
                        onDelete: onRemove,
                        onSwipeStateChanged: { isDraggingOrOpen in
                            if isDraggingOrOpen { suppressNextTap = true }
                        }
                    ) {
                        if isOverlapping {
                            CompactOverlapRunChip(
                                run: run,
                                compact: compact,
                                onTap: {
                                    guard !suppressNextTap && !isRunDeleteRevealed else {
                                        suppressNextTap = false
                                        return
                                    }
                                    onTapRun()
                                }
                            )
                        } else {
                            RunChip(
                                run: run,
                                completedStepIDs: completedStepIDs,
                                activeTimer: activeTimer,
                                projects: projects,
                                compact: compact,
                                onTap: {
                                    guard !suppressNextTap && !isRunDeleteRevealed else {
                                        suppressNextTap = false
                                        return
                                    }
                                    onTapRun()
                                },
                                onStart: { onStart(nil) },
                                onCard: onCard
                            )
                        }
                    }
                    .frame(minHeight: minHeight, alignment: .top)
                    .padding(.leading, suppressTimelineGutter ? 0 : 8)
                } else {
                    ExpandedRunCard(
                        run: run,
                        completedStepIDs: completedStepIDs,
                        activeTimer: activeTimer,
                        projects: projects,
                        compact: compact,
                        showStepDuration: showStepDuration,
                        onTap: onBench,
                        onStart: onStart,
                        onCard: onCard,
                        onBench: onBench,
                        onRemove: onRemove,
                        onToggleStep: onToggleStep,
                        onPause: onPause,
                        onResume: onResume,
                        onStop: onStop
                    )
                    .frame(minHeight: minHeight, alignment: .top)
                    .padding(.leading, suppressTimelineGutter ? 0 : 8)
                }
            }
            .padding(.bottom, 8)

            TimelineTimeRule(
                label: timeLabelFromMinutes(run.endMinuteOfDay),
                tint: .secondary,
                prominence: 0.12,
                labelOpacity: 0.58,
                labelWeight: .regular
            )
        }
    }
}

private struct TimelineTimeRule: View {
    let label: String
    let tint: Color
    let prominence: Double
    let labelOpacity: Double
    let labelWeight: Font.Weight

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 11, weight: labelWeight, design: .monospaced))
                .foregroundStyle(tint.opacity(labelOpacity))
                .frame(width: 48, alignment: .trailing)

            Rectangle()
                .fill(tint.opacity(prominence))
                .frame(height: 1)
                .padding(.leading, 8)
        }
    }
}

private struct CurrentTimeIndicatorInHour: View {
    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { _ in
            let minute = Calendar.current.component(.minute, from: Date())
            HStack(spacing: 0) {
                Text(String(format: ":%02d", minute))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red)
                    .frame(width: 48, alignment: .trailing)

                HStack(spacing: 0) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                        .padding(.leading, 5)
                    Rectangle()
                        .fill(Color.red.opacity(0.7))
                        .frame(height: 1.5)
                }
            }
        }
    }
}
