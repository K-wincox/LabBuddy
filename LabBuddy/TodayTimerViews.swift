import SwiftUI

struct TimerDock: View {
    let activeTimers: [ActiveLabTimer]
    let stopTimer: (ActiveLabTimer) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("运行中的计时器").font(.headline)
            ForEach(activeTimers.sorted(by: { $0.endsAt < $1.endsAt })) { timer in
                TimelineView(.periodic(from: Date(), by: 1)) { _ in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(timer.stepTitle).font(.subheadline.weight(.semibold))
                            Text(timer.runTitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(timer.isFinished ? "完成" : formatDuration(timer.remainingSeconds))
                            .font(.title3.monospacedDigit().weight(.bold))
                            .foregroundStyle(timer.isFinished ? .orange : .teal)
                            .contentTransition(.numericText())
                        Button { stopTimer(timer) } label: {
                            Image(systemName: "xmark.circle.fill").font(.title3)
                        }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(timer.isFinished ? Color.orange.opacity(0.12) : Color.labInset, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Day Timeline View (vertical, Apple Calendar-style)


struct CustomTimerSheet: View {
    @Binding var hours: Int
    @Binding var mins: Int
    @Binding var secs: Int
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("自定义计时时长")
                    .font(.headline)

                HStack(spacing: 0) {
                    Picker("时", selection: $hours) {
                        ForEach(0..<24) { h in
                            Text("\(h)").tag(h)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60)

                    Text("时")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

                    Picker("分", selection: $mins) {
                        ForEach(0..<60) { m in
                            Text("\(m)").tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60)

                    Text("分")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

                    Picker("秒", selection: $secs) {
                        ForEach(0..<60) { s in
                            Text("\(s)").tag(s)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60)

                    Text("秒")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                }
                .frame(height: 160)

                Button {
                    onStart()
                    dismiss()
                } label: {
                    Label("开始计时", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.teal)
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}

// MARK: - Time Picker Sheet


struct CircularTimerView: View {
    let totalSeconds: Int
    let endsAt: Date

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { _ in
            let remaining = max(0, Int(endsAt.timeIntervalSinceNow.rounded()))
            let isFinished = remaining == 0
            let progress = totalSeconds > 0 ? Double(remaining) / Double(totalSeconds) : 0.0

            VStack(spacing: 12) {
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 12)
                        .frame(width: 140, height: 140)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: min(1, progress))
                        .stroke(
                            isFinished ? Color.orange : Color.teal,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))

                    // Time text
                    Text(isFinished ? "完成" : formatDuration(remaining))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(isFinished ? .orange : .teal)
                        .contentTransition(.numericText())
                }
            }
        }
    }
}

// MARK: - Collapsed Empty Segment
