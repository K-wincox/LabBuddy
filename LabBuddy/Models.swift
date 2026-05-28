import Foundation

enum WorkflowArea: String, CaseIterable, Identifiable {
    case cell = "细胞实验"
    case cloning = "分子克隆"
    case blot = "WB/跑胶"

    var id: String { rawValue }
}

struct LabStep: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let durationMinutes: Int?
    let isCarryOver: Bool
}

struct LabRun: Identifiable, Hashable {
    let id: String
    let title: String
    let area: WorkflowArea
    let timeLabel: String
    let status: String
    let protocolName: String
    let scaledVolumeLabel: String
    let steps: [LabStep]
}

struct ProtocolIngredient: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let standardAmount: Double
    let unit: String

    func scaled(by factor: Double) -> String {
        let amount = standardAmount * factor
        let formatted = amount >= 10 ? String(format: "%.0f", amount) : String(format: "%.2f", amount)
        return "\(formatted) \(unit)"
    }
}

struct LabProtocol: Identifiable, Hashable {
    let id: String
    let name: String
    let area: WorkflowArea
    let baseVolume: Double
    let volumeUnit: String
    let expectedDuration: String
    let ingredients: [ProtocolIngredient]
}

struct CalculatorExample: Identifiable, Hashable {
    let id: String
    let title: String
    let input: String
    let result: String
}
