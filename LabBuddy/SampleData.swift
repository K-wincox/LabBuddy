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
            id: "cell-passage-protocol",
            name: "细胞传代",
            area: .cell,
            baseVolume: 10,
            volumeUnit: "ml（培养皿）",
            expectedDuration: "15 min",
            ingredients: [
                ProtocolIngredient(name: "DMEM 基础培养基", standardAmount: 180, unit: "ml"),
                ProtocolIngredient(name: "FBS (10%)", standardAmount: 20, unit: "ml"),
                ProtocolIngredient(name: "双抗 (1%)", standardAmount: 0.2, unit: "ml"),
                ProtocolIngredient(name: "10× PBS", standardAmount: 25, unit: "ml"),
                ProtocolIngredient(name: "ddH₂O", standardAmount: 225, unit: "ml"),
                ProtocolIngredient(name: "0.5M EDTA", standardAmount: 0.4, unit: "ml"),
                ProtocolIngredient(name: "胰酶", standardAmount: 2, unit: "ml"),
                ProtocolIngredient(name: "Versene 洗涤液", standardAmount: 2, unit: "ml")
            ],
            steps: [
                LabStep(
                    id: "passage-prep-medium",
                    title: "配制完全培养基",
                    detail: "180 mL DMEM 基础培养基 + 20 mL 10% FBS + 200 μL 1% 双抗，混匀备用（不同细胞系配方可能不同）",
                    durationMinutes: nil,
                    isCarryOver: false,
                    reagents: [
                        StepReagent(name: "DMEM 基础培养基", amountExpression: "180", unit: "ml"),
                        StepReagent(name: "FBS (10%)", amountExpression: "20", unit: "ml"),
                        StepReagent(name: "双抗 (1%)", amountExpression: "0.2", unit: "ml")
                    ]
                ),
                LabStep(
                    id: "passage-prep-versene",
                    title: "配制 Versene 洗涤液",
                    detail: "25 mL 10× PBS + 225 mL 水 + 400 μL 0.5M EDTA，混匀备用",
                    durationMinutes: nil,
                    isCarryOver: false,
                    reagents: [
                        StepReagent(name: "10× PBS", amountExpression: "25", unit: "ml"),
                        StepReagent(name: "ddH₂O", amountExpression: "225", unit: "ml"),
                        StepReagent(name: "0.5M EDTA", amountExpression: "0.4", unit: "ml")
                    ]
                ),
                LabStep(
                    id: "passage-prep-digest",
                    title: "配制消化液",
                    detail: "40 mL Versene 洗涤液 + 胰酶，混匀备用",
                    durationMinutes: nil,
                    isCarryOver: false,
                    reagents: [
                        StepReagent(name: "Versene 洗涤液", amountExpression: "40", unit: "ml"),
                        StepReagent(name: "胰酶", amountExpression: "2", unit: "ml")
                    ]
                ),
                LabStep(
                    id: "passage-observe",
                    title: "镜下观察细胞状态",
                    detail: "取培养细胞，在显微镜下观察细胞密度和生长状态，密度达 90% 左右可传代",
                    durationMinutes: nil,
                    isCarryOver: false,
                    reagents: []
                ),
                LabStep(
                    id: "passage-versene",
                    title: "Versene 洗涤",
                    detail: "倒去旧培养液，沿瓶壁加入 2 mL Versene，前后晃动充分接触细胞后倒入废液缸，用枪吸净残余",
                    durationMinutes: nil,
                    isCarryOver: false,
                    reagents: [
                        StepReagent(name: "Versene 洗涤液", amountExpression: "2", unit: "ml")
                    ]
                ),
                LabStep(
                    id: "passage-trypsin",
                    title: "胰酶消化",
                    detail: "加入 2 mL 消化液覆盖瓶底，放入培养箱消化（293T ≈ 1 min，A549 ≈ 4 min）。镜下观察：细胞变圆、出现间隙、呈沙状悬浮即可",
                    durationMinutes: 3,
                    isCarryOver: false,
                    reagents: [
                        StepReagent(name: "胰酶", amountExpression: "2", unit: "ml")
                    ]
                ),
                LabStep(
                    id: "passage-stop",
                    title: "终止消化 & 收集细胞",
                    detail: "加入等量完全培养基终止消化，反复吹打瓶底使细胞充分悬浮，吸入离心管",
                    durationMinutes: nil,
                    isCarryOver: false,
                    reagents: [
                        StepReagent(name: "DMEM 基础培养基", amountExpression: "2", unit: "ml")
                    ]
                ),
                LabStep(
                    id: "passage-centrifuge",
                    title: "离心",
                    detail: "300 rpm，离心 4 分钟",
                    durationMinutes: 4,
                    isCarryOver: false,
                    reagents: []
                ),
                LabStep(
                    id: "passage-resuspend",
                    title: "弃上清 & 重悬",
                    detail: "倒掉上清，轻弹细胞沉淀使其散开。如需计数：加 1 mL 培养基混匀，取 20 μL 至计数板，细胞浓度（个/mL）= 对角线 3 大方格细胞数 ÷ 3 × 10⁴ × 稀释倍数",
                    durationMinutes: nil,
                    isCarryOver: false,
                    reagents: []
                ),
                LabStep(
                    id: "passage-split",
                    title: "传代接种",
                    detail: "加完全培养基重悬约 20 次，弃去多余，每板留 1 mL 细胞悬液，再补完全培养基至目标体积（T25 ≈ 5 mL（3-5 mL），T75 ≈ 15 mL（13-15 mL）），充分重悬后加入培养皿，用 8 字法混匀",
                    durationMinutes: nil,
                    isCarryOver: false,
                    variableRefs: ["split_ratio", "A_dish"],
                    reagents: [
                        StepReagent(name: "完全培养基", amountExpression: "split_ratio * A_dish / 5", unit: "ml")
                    ]
                ),
                LabStep(
                    id: "passage-label",
                    title: "标记 & 放入培养箱",
                    detail: "镜下确认细胞已摇匀，写上细胞类型、代数、日期，放入培养箱（37°C、5% CO₂、90% 湿度）",
                    durationMinutes: nil,
                    isCarryOver: false,
                    reagents: []
                )
            ],
            variables: [
                ProtocolVariable(symbol: "split_ratio", name: "传代比例", baseValue: 3, unit: "倍", isScalable: false, minValue: 2, maxValue: 10),
                ProtocolVariable(symbol: "A_dish", name: "培养皿面积", baseValue: 78.54, unit: "cm²", isScalable: true, minValue: 9.6, maxValue: 150)
            ],
            source: ProtocolSource(type: .sop, title: "细胞培养室常规 SOP", confidence: 0.98)
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
        )
    ]

    static let sampleProjects: [Project] = []
}
