import SwiftUI

func formatDuration(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

func highlightedLabParameters(_ text: String) -> AttributedString {
    var attributed = AttributedString(text)
    attributed.foregroundColor = .secondary

    let pattern = #"(\d+(?:\.\d+)?)\s*([A-Za-z°µμ%次×xX℃]+)?"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return attributed
    }

    let nsText = text as NSString
    let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
    for match in matches.reversed() {
        guard let textRange = Range(match.range, in: text),
              let attrRange = Range(textRange, in: attributed) else { continue }
        attributed[attrRange].foregroundColor = .teal
        attributed[attrRange].font = .subheadline.weight(.semibold).monospacedDigit()
    }

    return attributed
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
