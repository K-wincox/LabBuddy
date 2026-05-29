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
            ],
            steps: [
                LabStep(id: "medium-warm", title: "预温基础培养基", detail: "37 C 水浴，使用前确认无沉淀", durationMinutes: 8, isCarryOver: false, variableRefs: ["t_warm"]),
                LabStep(id: "medium-mix", title: "加入血清与双抗", detail: "按比例加入后轻柔颠倒混匀", durationMinutes: nil, isCarryOver: false, variableRefs: ["V_total", "f_serum"]),
                LabStep(id: "medium-label", title: "标记批次", detail: "写明日期、配方与操作者", durationMinutes: nil, isCarryOver: false)
            ],
            variables: [
                ProtocolVariable(symbol: "V_total", name: "总体积", value: 200, unit: "ml", formula: "baseVolume"),
                ProtocolVariable(symbol: "f_serum", name: "血清比例", value: 10, unit: "%", formula: "FBS / V_total"),
                ProtocolVariable(symbol: "t_warm", name: "预温时间", value: 8, unit: "min", formula: "step.duration")
            ],
            source: ProtocolSource(type: .sop, title: "细胞培养室常规 SOP", confidence: 0.92)
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
            ],
            steps: [
                LabStep(id: "ligation-thaw", title: "冰上融化组分", detail: "buffer 完全融化后短暂离心", durationMinutes: nil, isCarryOver: false),
                LabStep(id: "ligation-mix", title: "配置连接体系", detail: "酶最后加入，轻柔混匀", durationMinutes: nil, isCarryOver: false, variableRefs: ["V_reaction", "ratio_insert"]),
                LabStep(id: "ligation-incubate", title: "连接孵育", detail: "16 C 或室温按策略孵育", durationMinutes: 25, isCarryOver: false, variableRefs: ["t_ligation"])
            ],
            variables: [
                ProtocolVariable(symbol: "V_reaction", name: "反应总体积", value: 20, unit: "ul", formula: "sum(components)"),
                ProtocolVariable(symbol: "ratio_insert", name: "插入片段比例", value: 3, unit: "x", formula: "Insert / Vector"),
                ProtocolVariable(symbol: "t_ligation", name: "连接时间", value: 25, unit: "min", formula: "step.duration")
            ],
            source: ProtocolSource(type: .kitManual, title: "T4 Ligase kit quick protocol", confidence: 0.88)
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
            ],
            steps: [
                LabStep(id: "gel-clean", title: "清洁玻璃板", detail: "确认无漏液、无残胶", durationMinutes: nil, isCarryOver: false),
                LabStep(id: "gel-pour", title: "灌制分离胶", detail: "APS/TEMED 最后加入后立即灌胶", durationMinutes: nil, isCarryOver: false, variableRefs: ["gel_percent", "V_gel"]),
                LabStep(id: "gel-polymerize", title: "聚合等待", detail: "异丙醇压平胶面", durationMinutes: 30, isCarryOver: false, variableRefs: ["t_poly"])
            ],
            variables: [
                ProtocolVariable(symbol: "gel_percent", name: "凝胶浓度", value: 10, unit: "%", formula: "AcrBis / V_gel"),
                ProtocolVariable(symbol: "V_gel", name: "分离胶体积", value: 10, unit: "ml", formula: "baseVolume"),
                ProtocolVariable(symbol: "t_poly", name: "聚合时间", value: 30, unit: "min", formula: "step.duration")
            ],
            source: ProtocolSource(type: .literature, title: "Standard SDS-PAGE method", confidence: 0.84)
        )
    ]

    static let calculatorExamples: [CalculatorExample] = [
        CalculatorExample(id: "dilution", title: "液体稀释", input: "1M Tris -> 50 mM, 100 ml", result: "取 5 ml 母液 + 95 ml 溶剂"),
        CalculatorExample(id: "mass", title: "质量浓度", input: "MW 121.14, 0.5M, 100 ml", result: "称量 6.06 g"),
        CalculatorExample(id: "percent", title: "百分比浓度", input: "5% milk / TBST, 20 ml", result: "称量 1.00 g milk powder")
    ]

    static let inventory: [InventoryItem] = [
        InventoryItem(id: "dmem", name: "DMEM high glucose", category: "培养基", quantity: 420, unit: "ml", threshold: 100, storage: "4 C fridge"),
        InventoryItem(id: "fbs", name: "FBS", category: "血清", quantity: 38, unit: "ml", threshold: 50, storage: "-20 C box A"),
        InventoryItem(id: "trypsin", name: "0.25% Trypsin", category: "细胞实验", quantity: 72, unit: "ml", threshold: 20, storage: "4 C fridge"),
        InventoryItem(id: "ligase", name: "T4 Ligase", category: "分子克隆", quantity: 6, unit: "ul", threshold: 5, storage: "-20 C enzyme rack"),
        InventoryItem(id: "pvdf", name: "PVDF membrane", category: "WB/跑胶", quantity: 3, unit: "sheets", threshold: 2, storage: "Drawer B")
    ]
}
