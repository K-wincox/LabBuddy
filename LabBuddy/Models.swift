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
    var variableRefs: [String]

    init(
        id: String,
        title: String,
        detail: String,
        durationMinutes: Int?,
        isCarryOver: Bool,
        variableRefs: [String] = []
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.durationMinutes = durationMinutes
        self.isCarryOver = isCarryOver
        self.variableRefs = variableRefs
    }
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
    var variables: [ProtocolVariable]
    var source: ProtocolSource?

    init(
        id: String,
        name: String,
        area: WorkflowArea,
        baseVolume: Double,
        volumeUnit: String,
        expectedDuration: String,
        ingredients: [ProtocolIngredient],
        steps: [LabStep],
        variables: [ProtocolVariable] = [],
        source: ProtocolSource? = nil
    ) {
        self.id = id
        self.name = name
        self.area = area
        self.baseVolume = baseVolume
        self.volumeUnit = volumeUnit
        self.expectedDuration = expectedDuration
        self.ingredients = ingredients
        self.steps = steps
        self.variables = variables
        self.source = source
    }
}

struct ProtocolVariable: Identifiable, Hashable, Codable {
    let id: String
    var symbol: String
    var name: String
    var value: Double
    var unit: String
    var formula: String

    init(id: String = UUID().uuidString, symbol: String, name: String, value: Double, unit: String, formula: String) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.value = value
        self.unit = unit
        self.formula = formula
    }
}

struct ProtocolSource: Hashable, Codable {
    var type: ProtocolSourceType
    var title: String
    var confidence: Double
}

enum ProtocolSourceType: String, CaseIterable, Identifiable, Codable {
    case literature = "文献"
    case kitManual = "试剂盒手册"
    case sop = "SOP"

    var id: String { rawValue }
}

struct CalculatorExample: Identifiable, Hashable {
    let id: String
    let title: String
    let input: String
    let result: String
}
