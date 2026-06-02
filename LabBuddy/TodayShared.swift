import SwiftUI

func formatDuration(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

extension Array where Element == LabRun {
    func sortedByTimeLabel() -> [LabRun] {
        sorted { lhs, rhs in minutes(lhs.timeLabel) < minutes(rhs.timeLabel) }
    }
    private func minutes(_ label: String) -> Int {
        let parts = label.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return Int.max }
        return h * 60 + m
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
