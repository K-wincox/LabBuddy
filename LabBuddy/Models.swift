import Foundation
import JavaScriptCore

enum WorkflowArea: RawRepresentable, Identifiable, Hashable, Codable {
    case cell
    case cloning
    case blot
    case custom(String)

    var rawValue: String {
        switch self {
        case .cell: return "细胞实验"
        case .cloning: return "分子克隆"
        case .blot: return "WB/跑胶"
        case .custom(let s): return s
        }
    }

    init(rawValue: String) {
        switch rawValue {
        case "细胞实验": self = .cell
        case "分子克隆": self = .cloning
        case "WB/跑胶": self = .blot
        default: self = .custom(rawValue)
        }
    }

    var id: String { rawValue }

    static let builtIn: [WorkflowArea] = [.cell, .cloning, .blot]
}

struct Project: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var colorHex: String
    var description: String
    let createdAt: Date

    init(id: String = UUID().uuidString, name: String, colorHex: String, description: String = "", createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.description = description
        self.createdAt = createdAt
    }

    static let palette: [(name: String, hex: String)] = [
        ("薄荷绿", "#4ECDC4"), ("海蓝", "#4A90D9"), ("紫罗兰", "#9B59B6"),
        ("珊瑚橙", "#E67E22"), ("翡翠绿", "#27AE60"), ("玫瑰红", "#E74C3C"),
        ("靛蓝", "#2C3E80"), ("藤黄", "#F39C12"), ("灰蓝", "#607D8B"), ("粉色", "#E91E63"),
    ]
}

struct LabStep: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var detail: String
    var durationMinutes: Int?
    var isCarryOver: Bool
    var variableRefs: [String]
    var reagents: [StepReagent]  // 步骤中使用的试剂

    init(
        id: String,
        title: String,
        detail: String,
        durationMinutes: Int?,
        isCarryOver: Bool,
        variableRefs: [String] = [],
        reagents: [StepReagent] = []
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.durationMinutes = durationMinutes
        self.isCarryOver = isCarryOver
        self.variableRefs = variableRefs
        self.reagents = reagents
    }
}

// 步骤中的试剂（支持表达式）
struct StepReagent: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var amountExpression: String  // 固定值（"125"）或中文公式（"总体积 * 0.9"）
    var unit: String
    var isFormula: Bool           // true = 公式模式，false = 固定值模式

    init(id: String = UUID().uuidString, name: String, amountExpression: String, unit: String, isFormula: Bool = false) {
        self.id = id
        self.name = name
        self.amountExpression = amountExpression
        self.unit = unit
        self.isFormula = amountExpression.contains(where: { $0.isLetter }) && Double(amountExpression) == nil
    }

    func calculateAmount(variables: [String: Double]) -> Double? {
        ExpressionEvaluator.evaluate(amountExpression, variables: variables)
    }
}

struct LabRun: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    let area: WorkflowArea
    let timeLabel: String
    let status: String
    let protocolName: String
    let scaledVolumeLabel: String
    var projectID: String?
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
    var endsAt: Date
    var pausedRemaining: Int?  // non-nil = paused, value is frozen remaining seconds

    var remainingSeconds: Int {
        if let paused = pausedRemaining { return paused }
        return max(0, Int(endsAt.timeIntervalSinceNow.rounded()))
    }

    var isPaused: Bool { pausedRemaining != nil }

    var isFinished: Bool {
        !isPaused && remainingSeconds == 0
    }
}

struct InventoryItem: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var category: String
    var quantity: Double
    var unit: String
    var threshold: Double
    var storage: String
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
    var isFormula: Bool  // true = 公式模式（可缩放），false = 固定值模式（不缩放）

    init(id: String = UUID().uuidString, name: String, standardAmount: Double, unit: String, isFormula: Bool = true) {
        self.id = id
        self.name = name
        self.standardAmount = standardAmount
        self.unit = unit
        self.isFormula = isFormula
    }

    func scaled(by factor: Double) -> String {
        let amount = isFormula ? (standardAmount * factor) : standardAmount
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
    var symbol: String        // 符号，如 "V_total"
    var name: String          // 变量名，如 "总体积"
    var baseValue: Double     // 基准值
    var currentValue: Double  // 当前值（用户调整后）
    var unit: String          // 单位
    var isScalable: Bool      // 是否参与同比缩放
    var minValue: Double      // 最小值
    var maxValue: Double      // 最大值

    init(
        id: String = UUID().uuidString,
        symbol: String,
        name: String,
        baseValue: Double,
        currentValue: Double? = nil,
        unit: String,
        isScalable: Bool = true,
        minValue: Double = 0,
        maxValue: Double = 1000
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.baseValue = baseValue
        self.currentValue = currentValue ?? baseValue
        self.unit = unit
        self.isScalable = isScalable
        self.minValue = minValue
        self.maxValue = maxValue
    }

    // 计算缩放因子
    var scaleFactor: Double {
        guard baseValue > 0 else { return 1.0 }
        return currentValue / baseValue
    }

    // 用于公式计算的实际值：% 单位自动转为小数
    var computedValue: Double {
        unit.trimmingCharacters(in: .whitespaces) == "%" ? currentValue / 100.0 : currentValue
    }

    var computedBaseValue: Double {
        unit.trimmingCharacters(in: .whitespaces) == "%" ? baseValue / 100.0 : baseValue
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
struct BufferTemplate: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var area: WorkflowArea
    var baseVolume: Double
    var volumeUnit: String
    var ingredients: [ProtocolIngredient]
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

// MARK: - Expression Evaluator

/// 简单的表达式计算引擎，支持基本四则运算和变量替换
enum ExpressionEvaluator {
    private static let jsContext = JSContext()

    /// 计算表达式的值，支持符号（V_total）和中文名称（总体积）两种变量写法
    static func evaluate(_ expression: String, variables: [String: Double]) -> Double? {
        var expr = expression.trimmingCharacters(in: .whitespaces)
        guard !expr.isEmpty else { return nil }

        // 纯数字直接返回
        if let direct = Double(expr) { return direct }

        // 先替换较长的 key，避免短 key 误替换长 key 的子串
        let sorted = variables.sorted { $0.key.count > $1.key.count }
        for (key, value) in sorted {
            let formatted = value == floor(value) ? String(format: "%.0f", value) : "\(value)"
            expr = expr.replacingOccurrences(of: key, with: formatted)
        }

        // 用 JavaScriptCore 计算，比 NSExpression 更可靠
        guard let ctx = jsContext else { return nil }
        let result = ctx.evaluateScript(expr)
        if let num = result?.toNumber(), !num.doubleValue.isNaN {
            return num.doubleValue
        }
        return nil
    }

    /// 格式化数值显示
    static func format(_ value: Double, decimals: Int = 2) -> String {
        if value >= 10 || value == floor(value) {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.\(decimals)f", value)
        }
    }
}

