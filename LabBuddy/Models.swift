import Foundation

enum WorkflowArea: String, CaseIterable, Identifiable, Codable {
    case cell = "细胞实验"
    case cloning = "分子克隆"
    case blot = "WB/跑胶"

    var id: String { rawValue }
}

struct LabStep: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var detail: String
    var durationMinutes: Int?
    var isCarryOver: Bool
}

struct LabRun: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let area: WorkflowArea
    let timeLabel: String
    let status: String
    let protocolName: String
    let scaledVolumeLabel: String
    let steps: [LabStep]
}

struct ActiveLabTimer: Identifiable, Codable, Equatable {
    let id: String
    let runID: String
    let runTitle: String
    let stepTitle: String
    let startedAt: Date
    let endsAt: Date

    var remainingSeconds: Int {
        max(0, Int(endsAt.timeIntervalSinceNow.rounded()))
    }

    var isFinished: Bool {
        remainingSeconds == 0
    }
}

struct InventoryItem: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let category: String
    var quantity: Double
    let unit: String
    let threshold: Double
    let storage: String

    var isLowStock: Bool {
        quantity <= threshold
    }
}

struct ProtocolIngredient: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var standardAmount: Double
    var unit: String

    init(id: String = UUID().uuidString, name: String, standardAmount: Double, unit: String) {
        self.id = id
        self.name = name
        self.standardAmount = standardAmount
        self.unit = unit
    }

    func scaled(by factor: Double) -> String {
        let amount = standardAmount * factor
        let formatted = amount >= 10 ? String(format: "%.0f", amount) : String(format: "%.2f", amount)
        return "\(formatted) \(unit)"
    }
}

struct LabProtocol: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var area: WorkflowArea
    var baseVolume: Double
    var volumeUnit: String
    var expectedDuration: String
    var ingredients: [ProtocolIngredient]
    var steps: [LabStep]
}

struct CalculatorExample: Identifiable, Hashable {
    let id: String
    let title: String
    let input: String
    let result: String
}
