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
            projectID: nil,
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
            projectID: nil,
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
            projectID: nil,
            steps: [
                LabStep(id: "transfer-check", title: "检查转膜", detail: "确认 Marker 与膜方向", durationMinutes: nil, isCarryOver: true),
                LabStep(id: "block", title: "封闭", detail: "5% milk / TBST", durationMinutes: 60, isCarryOver: true)
            ]
        )
    ]

    static let pastDays: [ExperimentDayRecord] = {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        let fmt = DateFormatter()
        fmt.calendar = cal
        fmt.locale = Locale(identifier: "zh_CN")
        func key(_ offset: Int) -> String {
            fmt.dateFormat = "yyyy-MM-dd"
            return fmt.string(from: cal.date(byAdding: .day, value: offset, to: today)!)
        }
        func label(_ offset: Int) -> String {
            fmt.dateFormat = "M月d日"
            return fmt.string(from: cal.date(byAdding: .day, value: offset, to: today)!)
        }
        func weekday(_ offset: Int) -> String {
            fmt.dateFormat = "EEE"
            return fmt.string(from: cal.date(byAdding: .day, value: offset, to: today)!)
        }
        return [
            ExperimentDayRecord(
                id: "past-\(key(-1))",
                dateLabel: label(-1),
                weekday: weekday(-1),
                summary: "3 个实验 · 细胞换液、双酶切验证、WB 一抗孵育",
                runs: [runs[0], runs[1], runs[2]]
            ),
            ExperimentDayRecord(
                id: "past-\(key(-2))",
                dateLabel: label(-2),
                weekday: weekday(-2),
                summary: "2 个实验 · 铺板、SDS-PAGE 胶制备",
                runs: [runs[0], runs[2]]
            ),
            ExperimentDayRecord(
                id: "past-\(key(-4))",
                dateLabel: label(-4),
                weekday: weekday(-4),
                summary: "1 个实验 · 质粒小提复核",
                runs: [runs[1]]
            ),
            ExperimentDayRecord(
                id: "past-\(key(-7))",
                dateLabel: label(-7),
                weekday: weekday(-7),
                summary: "2 个实验 · 细胞传代、Western blot 准备",
                runs: [runs[0], runs[2]]
            ),
            ExperimentDayRecord(
                id: "past-\(key(-9))",
                dateLabel: label(-9),
                weekday: weekday(-9),
                summary: "1 个实验 · T4 连接反应",
                runs: [runs[1]]
            ),
        ]
    }()

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
                LabStep(
                    id: "medium-warm",
                    title: "预温基础培养基",
                    detail: "37°C 水浴，使用前确认无沉淀",
                    durationMinutes: 8,
                    isCarryOver: false,
                    variableRefs: ["t_warm"],
                    reagents: [
                        StepReagent(name: "DMEM high glucose", amountExpression: "V_total * 0.9", unit: "ml")
                    ]
                ),
                LabStep(
                    id: "medium-mix",
                    title: "加入血清与双抗",
                    detail: "按比例加入后轻柔颠倒混匀",
                    durationMinutes: nil,
                    isCarryOver: false,
                    variableRefs: ["V_total", "f_serum"],
                    reagents: [
                        StepReagent(name: "FBS", amountExpression: "总体积 * 血清比例", unit: "ml"),
                        StepReagent(name: "Pen/Strep", amountExpression: "V_total * 0.01", unit: "ml")
                    ]
                ),
                LabStep(
                    id: "medium-label",
                    title: "标记批次",
                    detail: "写明日期、配方与操作者",
                    durationMinutes: nil,
                    isCarryOver: false,
                    reagents: []
                )
            ],
            variables: [
                ProtocolVariable(symbol: "V_total", name: "总体积", baseValue: 200, unit: "ml", isScalable: true, minValue: 50, maxValue: 500),
                ProtocolVariable(symbol: "f_serum", name: "血清比例", baseValue: 10, unit: "%", isScalable: false, minValue: 5, maxValue: 20),
                ProtocolVariable(symbol: "t_warm", name: "预温时间", baseValue: 8, unit: "min", isScalable: false, minValue: 5, maxValue: 15)
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
                LabStep(id: "ligation-thaw", title: "冰上融化组分", detail: "buffer 完全融化后短暂离心", durationMinutes: nil, isCarryOver: false, reagents: []),
                LabStep(
                    id: "ligation-mix",
                    title: "配置连接体系",
                    detail: "酶最后加入，轻柔混匀",
                    durationMinutes: nil,
                    isCarryOver: false,
                    variableRefs: ["V_reaction"],
                    reagents: [
                        StepReagent(name: "Vector", amountExpression: "2", unit: "ul"),
                        StepReagent(name: "Insert", amountExpression: "6", unit: "ul"),
                        StepReagent(name: "10x Ligase buffer", amountExpression: "V_reaction * 0.1", unit: "ul"),
                        StepReagent(name: "T4 Ligase", amountExpression: "1", unit: "ul"),
                        StepReagent(name: "ddH2O", amountExpression: "V_reaction - 11", unit: "ul")
                    ]
                ),
                LabStep(id: "ligation-incubate", title: "连接孵育", detail: "16°C 或室温按策略孵育", durationMinutes: 25, isCarryOver: false, variableRefs: ["t_ligation"], reagents: [])
            ],
            variables: [
                ProtocolVariable(symbol: "V_reaction", name: "反应总体积", baseValue: 20, unit: "ul", isScalable: true, minValue: 10, maxValue: 50),
                ProtocolVariable(symbol: "t_ligation", name: "连接时间", baseValue: 25, unit: "min", isScalable: false, minValue: 10, maxValue: 60)
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
                LabStep(id: "gel-clean", title: "清洁玻璃板", detail: "确认无漏液、无残胶", durationMinutes: nil, isCarryOver: false, reagents: []),
                LabStep(
                    id: "gel-pour",
                    title: "灌制分离胶",
                    detail: "APS/TEMED 最后加入后立即灌胶",
                    durationMinutes: nil,
                    isCarryOver: false,
                    variableRefs: ["gel_percent", "V_gel"],
                    reagents: [
                        StepReagent(name: "30% Acr/Bis", amountExpression: "V_gel * gel_percent / 30", unit: "ml"),
                        StepReagent(name: "1.5M Tris pH 8.8", amountExpression: "V_gel * 0.25", unit: "ml"),
                        StepReagent(name: "10% SDS", amountExpression: "V_gel * 0.01", unit: "ml"),
                        StepReagent(name: "ddH2O", amountExpression: "V_gel * 0.4", unit: "ml"),
                        StepReagent(name: "APS/TEMED", amountExpression: "V_gel * 0.01", unit: "ml")
                    ]
                ),
                LabStep(id: "gel-polymerize", title: "聚合等待", detail: "异丙醇压平胶面", durationMinutes: 30, isCarryOver: false, variableRefs: ["t_poly"], reagents: [])
            ],
            variables: [
                ProtocolVariable(symbol: "gel_percent", name: "凝胶浓度", baseValue: 10, unit: "%", isScalable: false, minValue: 8, maxValue: 15),
                ProtocolVariable(symbol: "V_gel", name: "分离胶体积", baseValue: 10, unit: "ml", isScalable: true, minValue: 5, maxValue: 20),
                ProtocolVariable(symbol: "t_poly", name: "聚合时间", baseValue: 30, unit: "min", isScalable: false, minValue: 20, maxValue: 45)
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
        InventoryItem(id: "dmem", name: "DMEM high glucose", category: "培养基", quantity: 420, unit: "ml", threshold: 100, storage: "4 C fridge", supplier: "Gibco"),
        InventoryItem(id: "fbs", name: "FBS", category: "血清", quantity: 38, unit: "ml", threshold: 50, storage: "-20 C box A", lotNumber: "FBS2024-01", supplier: "Gibco"),
        InventoryItem(id: "trypsin", name: "0.25% Trypsin", category: "细胞实验", quantity: 72, unit: "ml", threshold: 20, storage: "4 C fridge"),
        InventoryItem(id: "ligase", name: "T4 Ligase", category: "分子克隆", quantity: 6, unit: "ul", threshold: 5, storage: "-20 C enzyme rack", supplier: "NEB"),
        InventoryItem(id: "pvdf", name: "PVDF membrane", category: "WB/跑胶", quantity: 3, unit: "sheets", threshold: 2, storage: "Drawer B")
    ]

    static let bufferTemplates: [BufferTemplate] = [
        BufferTemplate(
            id: "pbs",
            name: "1× PBS",
            area: .cell,
            baseVolume: 1000,
            volumeUnit: "ml",
            ingredients: [
                ProtocolIngredient(name: "NaCl", standardAmount: 8.0, unit: "g"),
                ProtocolIngredient(name: "KCl", standardAmount: 0.2, unit: "g"),
                ProtocolIngredient(name: "Na₂HPO₄", standardAmount: 1.44, unit: "g"),
                ProtocolIngredient(name: "KH₂PO₄", standardAmount: 0.24, unit: "g"),
                ProtocolIngredient(name: "ddH₂O", standardAmount: 1000, unit: "ml")
            ]
        ),
        BufferTemplate(
            id: "tbst",
            name: "TBST (Western Blot 洗涤缓冲液)",
            area: .blot,
            baseVolume: 1000,
            volumeUnit: "ml",
            ingredients: [
                ProtocolIngredient(name: "Tris-HCl (pH 7.6)", standardAmount: 20, unit: "mM"),
                ProtocolIngredient(name: "NaCl", standardAmount: 150, unit: "mM"),
                ProtocolIngredient(name: "Tween-20", standardAmount: 0.1, unit: "%")
            ]
        ),
        BufferTemplate(
            id: "dmem-complete",
            name: "DMEM 完全培养基",
            area: .cell,
            baseVolume: 200,
            volumeUnit: "ml",
            ingredients: [
                ProtocolIngredient(name: "DMEM high glucose", standardAmount: 180, unit: "ml"),
                ProtocolIngredient(name: "FBS", standardAmount: 20, unit: "ml"),
                ProtocolIngredient(name: "Pen/Strep", standardAmount: 2, unit: "ml")
            ]
        ),
        BufferTemplate(
            id: "loading-buffer",
            name: "5× SDS Loading Buffer",
            area: .blot,
            baseVolume: 10,
            volumeUnit: "ml",
            ingredients: [
                ProtocolIngredient(name: "1M Tris-HCl (pH 6.8)", standardAmount: 1.0, unit: "ml"),
                ProtocolIngredient(name: "SDS", standardAmount: 2.0, unit: "g"),
                ProtocolIngredient(name: "Glycerol", standardAmount: 5.0, unit: "ml"),
                ProtocolIngredient(name: "β-Mercaptoethanol", standardAmount: 0.5, unit: "ml"),
                ProtocolIngredient(name: "Bromophenol blue", standardAmount: 0.01, unit: "g")
            ]
        )
    ]

    static let sampleProjects: [Project] = [
        Project(name: "CRISPR 敲除验证", colorHex: "#4A90D9", description: "HCT116 细胞系 KO 表型验证"),
        Project(name: "抗体筛选", colorHex: "#9B59B6", description: "Western blot 一抗效价对比"),
        Project(name: "质粒库构建", colorHex: "#27AE60", description: "慢病毒载体克隆与保种"),
    ]
}
