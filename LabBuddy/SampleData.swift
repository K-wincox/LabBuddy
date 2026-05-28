import Foundation

enum SampleData {
    static let runs: [LabRun] = [
        LabRun(
            id: "cell-passage",
            title: "293T 细胞传代",
            area: .cell,
            timeLabel: "09:30",
            status: "进行中",
            protocolName: "293T routine passage",
            scaledVolumeLabel: "T25 flask / 1:4",
            steps: [
                LabStep(id: "pbs", title: "PBS 清洗", detail: "轻柔冲洗 1 次", durationMinutes: nil, isCarryOver: false),
                LabStep(id: "trypsin", title: "胰酶消化", detail: "37 C 观察细胞变圆", durationMinutes: 3, isCarryOver: false),
                LabStep(id: "medium", title: "完全培养基终止", detail: "补足至 4 ml 后重悬", durationMinutes: nil, isCarryOver: false)
            ]
        ),
        LabRun(
            id: "mini-prep",
            title: "质粒小提",
            area: .cloning,
            timeLabel: "13:20",
            status: "待开始",
            protocolName: "Plasmid miniprep",
            scaledVolumeLabel: "6 tubes",
            steps: [
                LabStep(id: "spin1", title: "菌液离心", detail: "12000 rpm 收集菌体", durationMinutes: 1, isCarryOver: false),
                LabStep(id: "lysis", title: "裂解反应", detail: "加入 P2 后轻柔颠倒混匀", durationMinutes: 5, isCarryOver: false),
                LabStep(id: "elute", title: "洗脱 DNA", detail: "EB 预热后静置", durationMinutes: 2, isCarryOver: false)
            ]
        ),
        LabRun(
            id: "western-transfer",
            title: "Western blot 转膜复查",
            area: .blot,
            timeLabel: "16:40",
            status: "顺延占位",
            protocolName: "WB transfer + block",
            scaledVolumeLabel: "1 mini gel",
            steps: [
                LabStep(id: "transfer-check", title: "检查转膜", detail: "确认 Marker 与膜方向", durationMinutes: nil, isCarryOver: true),
                LabStep(id: "block", title: "封闭", detail: "5% milk / TBST", durationMinutes: 60, isCarryOver: true)
            ]
        )
    ]

    static let protocols: [LabProtocol] = [
        LabProtocol(
            id: "complete-medium",
            name: "DMEM 完全培养基",
            area: .cell,
            baseVolume: 200,
            volumeUnit: "ml",
            expectedDuration: "8 min",
            ingredients: [
                ProtocolIngredient(name: "DMEM high glucose", standardAmount: 180, unit: "ml"),
                ProtocolIngredient(name: "FBS", standardAmount: 20, unit: "ml"),
                ProtocolIngredient(name: "Pen/Strep", standardAmount: 2, unit: "ml")
            ]
        ),
        LabProtocol(
            id: "ligation",
            name: "T4 连接反应",
            area: .cloning,
            baseVolume: 20,
            volumeUnit: "ul",
            expectedDuration: "25 min",
            ingredients: [
                ProtocolIngredient(name: "Vector", standardAmount: 2, unit: "ul"),
                ProtocolIngredient(name: "Insert", standardAmount: 6, unit: "ul"),
                ProtocolIngredient(name: "10x Ligase buffer", standardAmount: 2, unit: "ul"),
                ProtocolIngredient(name: "T4 Ligase", standardAmount: 1, unit: "ul"),
                ProtocolIngredient(name: "ddH2O", standardAmount: 9, unit: "ul")
            ]
        ),
        LabProtocol(
            id: "sds-gel",
            name: "10% SDS-PAGE 分离胶",
            area: .blot,
            baseVolume: 10,
            volumeUnit: "ml",
            expectedDuration: "12 min",
            ingredients: [
                ProtocolIngredient(name: "30% Acr/Bis", standardAmount: 3.3, unit: "ml"),
                ProtocolIngredient(name: "1.5M Tris pH 8.8", standardAmount: 2.5, unit: "ml"),
                ProtocolIngredient(name: "10% SDS", standardAmount: 0.1, unit: "ml"),
                ProtocolIngredient(name: "ddH2O", standardAmount: 4.0, unit: "ml"),
                ProtocolIngredient(name: "APS/TEMED", standardAmount: 0.1, unit: "ml")
            ]
        )
    ]

    static let calculatorExamples: [CalculatorExample] = [
        CalculatorExample(id: "dilution", title: "液体稀释", input: "1M Tris -> 50 mM, 100 ml", result: "取 5 ml 母液 + 95 ml 溶剂"),
        CalculatorExample(id: "mass", title: "质量浓度", input: "MW 121.14, 0.5M, 100 ml", result: "称量 6.06 g"),
        CalculatorExample(id: "percent", title: "百分比浓度", input: "5% milk / TBST, 20 ml", result: "称量 1.00 g milk powder")
    ]
}
