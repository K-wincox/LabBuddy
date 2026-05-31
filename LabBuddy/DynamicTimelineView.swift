import SwiftUI

// MARK: - Dynamic Hour Block

struct DynamicHourBlock: View {
    let hour: Int
    let runs: [LabRun]
    let zoom: TimelineZoom
    let targetDay: PlanTargetDay
    let completedStepIDs: Set<String>
    let activeTimers: [ActiveLabTimer]
    let projects: [Project]
    let onTapRun: (LabRun) -> Void
    let onStart: (LabRun) -> Void
    let onCard: (LabRun) -> Void
    let onBench: (LabRun) -> Void
    let onRemove: (LabRun) -> Void
    let onPauseTimer: (ActiveLabTimer) -> Void
    let onResumeTimer: (ActiveLabTimer) -> Void
    let onStopTimer: (ActiveLabTimer) -> Void

    private var isCurrentHour: Bool {
        targetDay == .today && Calendar.current.component(.hour, from: Date()) == hour
    }

    // Dynamic height calculation
    private var blockHeight: CGFloat {
        if runs.isEmpty {
            // Empty hour: minimal height
            return zoom == .overview ? 24 : 32
        } else {
            // Has experiments: calculate based on content
            if zoom == .overview {
                // Overview: fixed height per run + padding
                return CGFloat(runs.count) * 40 + 30
            } else {
                // Focused: estimate expanded card height
                let totalSteps = runs.reduce(0) { $0 + $1.steps.count }
                let baseHeight: CGFloat = CGFloat(runs.count) * 120  // base card height
                let stepsHeight: CGFloat = CGFloat(totalSteps) * 35  // per step
                return baseHeight + stepsHeight + CGFloat(runs.count) * 20  // spacing
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hour label
            HStack(spacing: 0) {
                Text(String(format: "%02d:00", hour))
                    .font(.system(size: 13, weight: isCurrentHour ? .bold : .regular, design: .monospaced))
                    .foregroundStyle(isCurrentHour ? Color.teal : Color.secondary.opacity(0.7))
                    .frame(width: 48, alignment: .trailing)

                Rectangle()
                    .fill(isCurrentHour ? Color.teal.opacity(0.35) : Color.secondary.opacity(0.12))
                    .frame(height: 1)
                    .padding(.leading, 8)
            }

            // Experiment content area
            if runs.isEmpty {
                // Empty space - minimal
                Color.clear
                    .frame(height: blockHeight - 1)
            } else {
                // Has experiments - dynamic layout
                VStack(spacing: zoom == .overview ? 8 : 12) {
                    ForEach(runs.sorted(by: { minuteFrom($0.timeLabel) < minuteFrom($1.timeLabel) })) { run in
                        HStack(spacing: 0) {
                            // Time indicator for this run
                            Text(run.timeLabel)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary.opacity(0.7))
                                .frame(width: 48, alignment: .trailing)

                            // Run card
                            if zoom == .overview {
                                RunChip(
                                    run: run,
                                    completedStepIDs: completedStepIDs,
                                    activeTimer: activeTimers.first { $0.runID == run.id },
                                    projects: projects,
                                    onTap: { onTapRun(run) },
                                    onStart: { onStart(run) },
                                    onCard: { onCard(run) },
                                    onRemove: { onRemove(run) }
                                )
                                .padding(.leading, 8)
                            } else {
                                let timer = activeTimers.first { $0.runID == run.id }
                                ExpandedRunCard(
                                    run: run,
                                    completedStepIDs: completedStepIDs,
                                    activeTimer: timer,
                                    projects: projects,
                                    onTap: { onTapRun(run) },
                                    onStart: { onStart(run) },
                                    onCard: { onCard(run) },
                                    onBench: { onBench(run) },
                                    onRemove: { onRemove(run) },
                                    onPause: { if let t = timer { onPauseTimer(t) } },
                                    onResume: { if let t = timer { onResumeTimer(t) } },
                                    onStop: { if let t = timer { onStopTimer(t) } }
                                )
                                .padding(.leading, 8)
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
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
