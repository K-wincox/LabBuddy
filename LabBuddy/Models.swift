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

struct ExperimentDayRecord: Identifiable, Hashable, Codable {
    let id: String
    let dateLabel: String
    let weekday: String
    let summary: String
    let runs: [LabRun]
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
    var lotNumber: String
    var openedDate: Date?
    var expirationDate: Date?
    var supplier: String
    var notes: String
    var isFavorite: Bool

    init(
        id: String,
        name: String,
        category: String,
        quantity: Double,
        unit: String,
        threshold: Double,
        storage: String,
        lotNumber: String = "",
        openedDate: Date? = nil,
        expirationDate: Date? = nil,
        supplier: String = "",
        notes: String = "",
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.threshold = threshold
        self.storage = storage
        self.lotNumber = lotNumber
        self.openedDate = openedDate
        self.expirationDate = expirationDate
        self.supplier = supplier
        self.notes = notes
        self.isFavorite = isFavorite
    }

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

// Phase 3: Calculator history record
struct CalculationRecord: Identifiable, Codable, Hashable {
    let id: String
    let mode: String
    let label: String
    let result: String
    let date: Date
    var inputs: [String: Double]
}

// Phase 3: Buffer/medium template
struct BufferTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let area: WorkflowArea
    let baseVolume: Double
    let volumeUnit: String
    let ingredients: [ProtocolIngredient]
}

// Phase 7: Inventory transaction
struct InventoryTransaction: Identifiable, Codable, Hashable {
    let id: String
    let itemID: String
    let itemName: String
    let delta: Double
    let unit: String
    let note: String
    let date: Date
    var isCorrected: Bool = false
}

// Phase 8: Data card image annotation
struct CardAnnotation: Identifiable, Codable, Hashable {
    let id: String
    var text: String
    var xNorm: Double
    var yNorm: Double
}

// Phase 8: Data card (wrapping a run for sharing)
struct DataCard: Identifiable, Codable, Hashable {
    let id: String
    let runID: String
    var title: String
    var experimentType: String
    var protocolName: String
    var scaledVolumeLabel: String
    var dateLabel: String
    var notes: String
    var visibleFields: [String]
    var imageData: Data?
    var annotations: [CardAnnotation]
    let createdAt: Date
}
