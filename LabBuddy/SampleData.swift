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
            steps: cellPassageProtocol.steps
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
        cellPassageProtocol
    ]

    static let cellPassageProtocol = LabProtocol(
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
                    title: "准备完全培养基",
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
                    title: "准备 Versene 洗涤液",
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
                    title: "准备消化液",
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
                    id: "passage-trypsin-add",
                    title: "加入消化液",
                    detail: "沿瓶壁加入 2 mL 胰酶/Versene 消化液，轻轻晃动使消化液均匀覆盖瓶底细胞层",
                    durationMinutes: nil,
                    isCarryOver: false,
                    reagents: [
                        StepReagent(name: "胰酶/Versene 消化液", amountExpression: "2", unit: "ml")
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
                    id: "passage-detach",
                    title: "轻拍瓶壁脱落细胞",
                    detail: "细胞变圆后轻拍培养瓶侧壁，帮助细胞从瓶底脱落；避免过度拍打造成细胞损伤",
                    durationMinutes: nil,
                    isCarryOver: false,
                    reagents: []
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
                    id: "passage-pipette",
                    title: "充分吹打混匀",
                    detail: "用移液枪沿瓶底反复吹打 10-20 次，确保细胞充分悬浮且无明显团块",
                    durationMinutes: nil,
                    isCarryOver: false,
                    reagents: []
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
                    id: "passage-count-optional",
                    title: "可选计数",
                    detail: "如需精确接种，取 20 μL 细胞悬液计数；根据目标传代比例或接种密度计算需保留的细胞悬液体积",
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
                    id: "passage-final-check",
                    title: "镜下复查分布",
                    detail: "放入培养箱前快速镜下确认细胞分布均匀、无明显气泡或大团块；必要时再次轻轻 8 字混匀",
                    durationMinutes: nil,
                    isCarryOver: false,
                    reagents: []
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

extension SampleData {
    static let demoUserEmail = "2388504180@qq.com"

    static let demoProjects: [Project] = [
        Project(id: "demo-project-cell", name: "2026博士课题", colorHex: "#00C7BE", description: "博士课题：细胞实验、转染验证和机制研究"),
        Project(id: "demo-project-cloning", name: "2026师兄的课题", colorHex: "#5856D6", description: "师兄课题：质粒构建、样品准备和协助验证"),
        Project(id: "demo-project-protein", name: "2026合作课题", colorHex: "#FF9500", description: "合作课题：蛋白表达、WB、ELISA 和 BLI 检测")
    ]

    static let demoInventory: [InventoryItem] = [
        InventoryItem(id: "demo-dmem", name: "DMEM high glucose", category: "培养基", quantity: 680, unit: "ml", threshold: 100, storage: "4 C 冰箱 A2", lotNumber: "DMEM-2604", supplier: "Gibco", isFavorite: true),
        InventoryItem(id: "demo-fbs", name: "FBS", category: "血清", quantity: 42, unit: "ml", threshold: 50, storage: "-20 C 血清盒", lotNumber: "FBS-2601", supplier: "Gibco", notes: "库存偏低，下一轮订购"),
        InventoryItem(id: "demo-ps", name: "Pen/Strep 双抗", category: "细胞实验", quantity: 23, unit: "ml", threshold: 10, storage: "4 C 冰箱 A2"),
        InventoryItem(id: "demo-trypsin", name: "0.25% Trypsin-EDTA", category: "细胞实验", quantity: 76, unit: "ml", threshold: 20, storage: "4 C 冰箱 A2"),
        InventoryItem(id: "demo-opti", name: "Opti-MEM", category: "细胞实验", quantity: 160, unit: "ml", threshold: 30, storage: "4 C 冰箱 A1", supplier: "Gibco"),
        InventoryItem(id: "demo-lipo3000", name: "Lipofectamine 3000", category: "转染", quantity: 320, unit: "ul", threshold: 80, storage: "4 C 转染试剂盒", supplier: "Thermo"),
        InventoryItem(id: "demo-lipo2000", name: "Lipofectamine 2000", category: "转染", quantity: 190, unit: "ul", threshold: 60, storage: "4 C 转染试剂盒", supplier: "Thermo"),
        InventoryItem(id: "demo-p3000", name: "P3000 Reagent", category: "转染", quantity: 260, unit: "ul", threshold: 60, storage: "4 C 转染试剂盒"),
        InventoryItem(id: "demo-competent", name: "DH5α 感受态细胞", category: "分子克隆", quantity: 18, unit: "tubes", threshold: 5, storage: "-80 C 细菌盒"),
        InventoryItem(id: "demo-lb-agar", name: "LB Amp 平板", category: "分子克隆", quantity: 12, unit: "plates", threshold: 6, storage: "4 C 平板盒"),
        InventoryItem(id: "demo-dna-kit", name: "TIANGEN DP304 DNA 提取试剂盒", category: "核酸实验", quantity: 36, unit: "preps", threshold: 10, storage: "室温核酸试剂柜"),
        InventoryItem(id: "demo-rna-kit", name: "RNA 提取试剂盒", category: "核酸实验", quantity: 24, unit: "preps", threshold: 8, storage: "室温核酸试剂柜"),
        InventoryItem(id: "demo-pvdf", name: "PVDF 膜", category: "WB/跑胶", quantity: 6, unit: "sheets", threshold: 2, storage: "WB 抽屉"),
        InventoryItem(id: "demo-ecl", name: "ECL 发光液", category: "WB/跑胶", quantity: 42, unit: "ml", threshold: 10, storage: "4 C WB 试剂盒"),
        InventoryItem(id: "demo-ninta", name: "Ni-NTA Resin", category: "蛋白实验", quantity: 12, unit: "ml", threshold: 3, storage: "4 C 蛋白纯化架"),
        InventoryItem(id: "demo-bli-sensors", name: "Ni-NTA BLI Sensors", category: "蛋白实验", quantity: 24, unit: "tips", threshold: 8, storage: "BLI 耗材盒"),
        InventoryItem(id: "demo-elisa-plate", name: "ELISA 96 孔板", category: "蛋白实验", quantity: 9, unit: "plates", threshold: 3, storage: "耗材柜")
    ]

    static let demoBufferTemplates: [BufferTemplate] = [
        BufferTemplate(id: "demo-pbs-1x", name: "1× PBS", area: .cell, baseVolume: 1000, volumeUnit: "ml", ingredients: [
            ProtocolIngredient(name: "10× PBS", standardAmount: 100, unit: "ml"),
            ProtocolIngredient(name: "ddH2O", standardAmount: 900, unit: "ml")
        ]),
        BufferTemplate(id: "demo-tbst", name: "1× TBST", area: .protein, baseVolume: 1000, volumeUnit: "ml", ingredients: [
            ProtocolIngredient(name: "10× TBS", standardAmount: 100, unit: "ml"),
            ProtocolIngredient(name: "Tween-20", standardAmount: 1, unit: "ml"),
            ProtocolIngredient(name: "ddH2O", standardAmount: 899, unit: "ml")
        ]),
        BufferTemplate(id: "demo-blocking", name: "5% 脱脂奶粉 TBST", area: .protein, baseVolume: 20, volumeUnit: "ml", ingredients: [
            ProtocolIngredient(name: "脱脂奶粉", standardAmount: 1, unit: "g"),
            ProtocolIngredient(name: "1× TBST", standardAmount: 20, unit: "ml")
        ]),
        BufferTemplate(id: "demo-lysis-ripa", name: "RIPA 裂解液工作液", area: .protein, baseVolume: 10, volumeUnit: "ml", ingredients: [
            ProtocolIngredient(name: "RIPA buffer", standardAmount: 9.9, unit: "ml"),
            ProtocolIngredient(name: "PMSF", standardAmount: 100, unit: "ul")
        ]),
        BufferTemplate(id: "demo-transfer-buffer", name: "WB 转膜液", area: .protein, baseVolume: 1000, volumeUnit: "ml", ingredients: [
            ProtocolIngredient(name: "10× Transfer Buffer", standardAmount: 100, unit: "ml"),
            ProtocolIngredient(name: "甲醇", standardAmount: 200, unit: "ml"),
            ProtocolIngredient(name: "ddH2O", standardAmount: 700, unit: "ml")
        ]),
        BufferTemplate(id: "demo-bli-buffer", name: "BLI Kinetics Buffer", area: .protein, baseVolume: 100, volumeUnit: "ml", ingredients: [
            ProtocolIngredient(name: "1× PBS", standardAmount: 99.9, unit: "ml"),
            ProtocolIngredient(name: "Tween-20", standardAmount: 50, unit: "ul"),
            ProtocolIngredient(name: "BSA", standardAmount: 100, unit: "mg")
        ])
    ]

    static let demoProtocols: [LabProtocol] = [
        lipo3000Protocol,
        lipo2000Protocol,
        transformationProtocol,
        tiangenDNAExtractionProtocol
    ]

    static let lipo3000Protocol = LabProtocol(
        id: "demo-protocol-lipo3000",
        name: "转染（Lipo3000）",
        area: .cell,
        baseVolume: 1,
        volumeUnit: "孔（6孔板）",
        expectedDuration: "24 h",
        ingredients: [
            ProtocolIngredient(name: "细胞", standardAmount: 5e5, unit: "cells"),
            ProtocolIngredient(name: "无双抗培养基", standardAmount: 1.75, unit: "ml"),
            ProtocolIngredient(name: "Opti-MEM", standardAmount: 250, unit: "ul"),
            ProtocolIngredient(name: "Lipofectamine 3000", standardAmount: 5, unit: "ul"),
            ProtocolIngredient(name: "质粒 DNA", standardAmount: 2.5, unit: "ug"),
            ProtocolIngredient(name: "P3000 Reagent", standardAmount: 5, unit: "ul")
        ],
        steps: [
            step("lipo3000-1", "细胞准备", "六孔板每孔接种 5×10^5 个细胞，次日转染；确认细胞无污染，汇合度 70-90%。", nil),
            step("lipo3000-2", "配制无双抗培养基", "准备不含抗生素的培养基，用于换液和转染。", nil),
            step("lipo3000-3", "换液与 PBS 清洗", "吸除含双抗培养基，PBS 冲洗 2 次，去除残留双抗。", nil),
            step("lipo3000-4", "加入无双抗培养基", "每孔加入 1.75 ml 无双抗培养基，放回培养箱适应。", nil),
            step("lipo3000-5", "制备 A 组", "125 ul Opti-MEM 稀释 5 ul Lipofectamine 3000，充分混匀。", nil),
            step("lipo3000-6", "制备 B 组", "125 ul Opti-MEM 稀释 2.5 ug 质粒 DNA 和 5 ul P3000，充分混匀。", nil),
            step("lipo3000-7", "阴性对照", "NC 组使用 2.5 ug 对照质粒或空载体。", nil),
            step("lipo3000-8", "混合孵育", "A 组与 B 组混合，室温孵育 10-15 min。", 15),
            step("lipo3000-9", "加入细胞", "将 DNA-脂质体复合物加入孔中，轻晃六孔板使其均匀分布。", nil),
            step("lipo3000-10", "培养与分析", "放回培养箱继续培养；24 h 后进行荧光观察、流式或表达分析。", nil, true)
        ],
        variables: [
            ProtocolVariable(symbol: "N_cell", name: "每孔细胞数", baseValue: 5e5, unit: "cells", isScalable: true, minValue: 1e5, maxValue: 2e6),
            ProtocolVariable(symbol: "DNA", name: "质粒 DNA", baseValue: 2.5, unit: "ug", isScalable: true, minValue: 0.1, maxValue: 10)
        ],
        source: ProtocolSource(type: .sop, title: "用户提供 Protocol", confidence: 1.0)
    )

    static let lipo2000Protocol = LabProtocol(
        id: "demo-protocol-lipo2000",
        name: "转染（Lipo2000）",
        area: .cell,
        baseVolume: 1,
        volumeUnit: "孔（12孔板）",
        expectedDuration: "24 h",
        ingredients: [
            ProtocolIngredient(name: "细胞", standardAmount: 1e6, unit: "cells"),
            ProtocolIngredient(name: "无双抗培养基", standardAmount: 1.75, unit: "ml"),
            ProtocolIngredient(name: "Opti-MEM", standardAmount: 600, unit: "ul"),
            ProtocolIngredient(name: "Lipofectamine 2000", standardAmount: 2, unit: "ul"),
            ProtocolIngredient(name: "质粒 DNA", standardAmount: 1, unit: "ug")
        ],
        steps: [
            step("lipo2000-1", "细胞准备", "12 孔板每孔接种 1×10^6 个细胞，次日转染；汇合度 70-90%。", nil),
            step("lipo2000-2", "配制无双抗培养基", "准备不含抗生素的培养基。", nil),
            step("lipo2000-3", "换液与 PBS 清洗", "吸除含双抗培养基，PBS 冲洗 2 次。", nil),
            step("lipo2000-4", "加入无双抗培养基", "每孔加入 1.75 ml 无双抗培养基，放回培养箱适应。", nil),
            step("lipo2000-5", "制备 A 组", "300 ul Opti-MEM 稀释 2 ul Lipofectamine 2000，充分混匀。", nil),
            step("lipo2000-6", "制备 B 组", "300 ul Opti-MEM 稀释 1 ug 质粒 DNA，充分混匀。", nil),
            step("lipo2000-7", "阴性对照", "NC 组使用 1 ug 对照质粒或空载体。", nil),
            step("lipo2000-8", "混合孵育", "A 组与 B 组混合，室温孵育 10-15 min。", 15),
            step("lipo2000-9", "加入细胞", "将复合物加入含 1.75 ml 无双抗培养基的孔中，轻晃混匀。", nil),
            step("lipo2000-10", "培养与分析", "放回培养箱继续培养；24 h 后进行下游检测。", nil, true)
        ],
        variables: [
            ProtocolVariable(symbol: "N_cell", name: "每孔细胞数", baseValue: 1e6, unit: "cells", isScalable: true, minValue: 1e5, maxValue: 3e6),
            ProtocolVariable(symbol: "DNA", name: "质粒 DNA", baseValue: 1, unit: "ug", isScalable: true, minValue: 0.1, maxValue: 5)
        ],
        source: ProtocolSource(type: .sop, title: "用户提供 Protocol", confidence: 1.0)
    )

    static let transformationProtocol = LabProtocol(
        id: "demo-protocol-transformation",
        name: "质粒转化",
        area: .nucleic,
        baseVolume: 1,
        volumeUnit: "管",
        expectedDuration: "Day1 2 h + 过夜",
        ingredients: [
            ProtocolIngredient(name: "感受态细胞", standardAmount: 50, unit: "ul"),
            ProtocolIngredient(name: "目的质粒", standardAmount: 1, unit: "ul"),
            ProtocolIngredient(name: "无抗 LB", standardAmount: 900, unit: "ul"),
            ProtocolIngredient(name: "抗性 LB 平板", standardAmount: 1, unit: "plate")
        ],
        steps: [
            step("trans-1", "冰上融化与加质粒", "30-100 ul 感受态细胞置冰上融化至半透明状，加入 1 ul 目的质粒，轻弹混匀，冰上静置 30 min。", 30),
            step("trans-2", "热激", "42 C 热激 90 s，迅速置冰上 2 min。", 2),
            step("trans-3", "复苏", "加入 900 ul 无抗 LB，37 C、220 rpm 复苏 1 h；氨苄不复苏时可只加 20 ul LB。", 60),
            step("trans-4", "涂板", "取 10 ul 复苏菌液，均匀涂布于对应抗生素 LB 固体培养基。", nil),
            step("trans-5", "过夜培养", "晾干后倒置，37 C 恒温细菌培养箱中过夜培养。", nil, true),
            step("trans-6", "菌株暂存", "质粒 -20 C 冻存，感受态 4 C 暂存。", nil),
            step("trans-7", "Day2 挑克隆", "挑单克隆至氨苄抗性 LB 中，送测序并比对结果。", nil, true)
        ],
        source: ProtocolSource(type: .sop, title: "用户提供 Protocol", confidence: 1.0)
    )

    static let tiangenDNAExtractionProtocol = LabProtocol(
        id: "demo-protocol-tian-gen-dna",
        name: "血液/细胞/组织基因组 DNA 提取（TIANGEN DP304）",
        area: .nucleic,
        baseVolume: 1,
        volumeUnit: "prep",
        expectedDuration: "45-90 min",
        ingredients: [
            ProtocolIngredient(name: "Buffer GA", standardAmount: 200, unit: "ul"),
            ProtocolIngredient(name: "Proteinase K", standardAmount: 20, unit: "ul"),
            ProtocolIngredient(name: "Buffer GB", standardAmount: 200, unit: "ul"),
            ProtocolIngredient(name: "无水乙醇", standardAmount: 200, unit: "ul"),
            ProtocolIngredient(name: "Buffer GD", standardAmount: 500, unit: "ul"),
            ProtocolIngredient(name: "Buffer PW", standardAmount: 1200, unit: "ul"),
            ProtocolIngredient(name: "Buffer TE", standardAmount: 100, unit: "ul")
        ],
        steps: [
            step("dp304-1", "样品处理", "血液 200 ul 可直接使用；细胞样品离心收集后用 TE/PBS 重悬，再加 180 ul Buffer GA；组织样品打碎后加 200 ul Buffer GA。", nil),
            step("dp304-2", "可选 RNA 去除", "如需去除 RNA，加入 4 ul RNAse A，振荡 15 s，室温 5 min。", 5),
            step("dp304-3", "加入 Proteinase K", "加入 20 ul Proteinase K，混匀。组织样品需 56 C 消化至组织溶解。", nil),
            step("dp304-4", "裂解", "加入 200 ul Buffer GB，充分颠倒混匀，70 C 放置 10 min，溶液应变清亮。", 10),
            step("dp304-5", "加乙醇", "加入 200 ul 无水乙醇，充分振荡混匀 15 s，简短离心。", nil),
            step("dp304-6", "上柱", "将溶液和絮状沉淀加入吸附柱 CB3，12000 rpm 离心 30 s，倒废液。", 1),
            step("dp304-7", "Buffer GD 洗涤", "加入 500 ul Buffer GD，12000 rpm 离心 30 s，倒废液。", 1),
            step("dp304-8", "Buffer PW 洗涤两次", "加入 600 ul Buffer PW，12000 rpm 离心 30 s；重复一次。", 2),
            step("dp304-9", "干柱", "12000 rpm 离心 2 min，室温放置 2-5 min 去除残余乙醇。", 5),
            step("dp304-10", "洗脱", "吸附柱转入新离心管，悬空滴加 50-200 ul Buffer TE，室温 2-5 min，12000 rpm 离心 2 min。", 5)
        ],
        variables: [
            ProtocolVariable(symbol: "V_elute", name: "洗脱体积", baseValue: 100, unit: "ul", isScalable: false, minValue: 50, maxValue: 200)
        ],
        source: ProtocolSource(type: .kitManual, title: "TIANGEN DP304 用户提供手册", confidence: 1.0)
    )

    static let demoPastDays: [ExperimentDayRecord] = [
        demoDay("2026-05-27", "5月27日", "周三", [
            demoRun("demo-0527-wb", "Western blot 一抗孵育", .protein, "09:10", "WB transfer + block", "1 mini gel", "demo-project-protein", [
                step("wb-0527-1", "转膜检查", "确认 PVDF 膜方向、Marker 和目的条带区域。", nil),
                step("wb-0527-2", "封闭", "5% 脱脂奶粉 TBST，室温摇床封闭。", 60),
                step("wb-0527-3", "一抗孵育", "按抗体说明书稀释一抗，4 C 过夜。", nil, true)
            ]),
            demoRun("demo-0527-passage", "293T 细胞传代", .cell, "14:30", "细胞传代", "T75 / 1:4", "demo-project-cell", cellPassageProtocol.steps)
        ]),
        demoDay("2026-05-28", "5月28日", "周四", [
            demoRun("demo-0528-transfection", "Lipo3000 转染 pLVX-GFP", .cell, "10:00", "转染（Lipo3000）", "6孔板 × 3 孔", "demo-project-cell", lipo3000Protocol.steps),
            demoRun("demo-0528-elisa", "ELISA 标准曲线预实验", .protein, "15:20", "ELISA", "96 孔板半板", "demo-project-protein", [
                step("elisa-0528-1", "包被抗原", "按 100 ul/孔加入包被液。", nil),
                step("elisa-0528-2", "封闭", "封闭液室温孵育。", 60),
                step("elisa-0528-3", "读板", "450 nm 读数并保存结果。", nil)
            ])
        ]),
        demoDay("2026-05-29", "5月29日", "周五", [
            demoRun("demo-0529-transformation", "DH5α 转化 pLVX 构建", .nucleic, "09:30", "质粒转化", "Amp 平板 × 2", "demo-project-cloning", transformationProtocol.steps),
            demoRun("demo-0529-rna", "细胞 RNA 提取", .nucleic, "16:10", "RNA extraction", "6 wells", "demo-project-cell", [
                step("rna-0529-1", "裂解", "每孔加入裂解液，充分吹打。", nil),
                step("rna-0529-2", "上柱洗涤", "按试剂盒流程洗涤。", nil),
                step("rna-0529-3", "洗脱 RNA", "RNase-free water 洗脱。", 2)
            ])
        ]),
        demoDay("2026-05-30", "5月30日", "周六", [
            demoRun("demo-0530-dna", "TIANGEN 基因组 DNA 提取", .nucleic, "11:00", "血液/细胞/组织基因组 DNA 提取（TIANGEN DP304）", "4 preps", "demo-project-cloning", tiangenDNAExtractionProtocol.steps),
            demoRun("demo-0530-bli", "BLI 传感器预湿与基线", .protein, "15:00", "BLI kinetics", "Ni-NTA sensors × 8", "demo-project-protein", [
                step("bli-0530-1", "传感器预湿", "Kinetics Buffer 中预湿 10 min。", 10),
                step("bli-0530-2", "基线平衡", "PBS-T/BSA buffer 建立基线。", 5),
                step("bli-0530-3", "上样测试", "His-tag 蛋白加载，观察响应值。", 8)
            ])
        ]),
        demoDay("2026-05-31", "5月31日", "周日", [
            demoRun("demo-0531-protein", "His-tag 蛋白 Ni-NTA 提纯", .protein, "13:30", "Protein purification", "50 ml lysate", "demo-project-protein", [
                step("protein-0531-1", "裂解液澄清", "12000 g 离心去除沉淀。", 20),
                step("protein-0531-2", "结合树脂", "Ni-NTA 树脂 4 C 旋转孵育。", 60),
                step("protein-0531-3", "洗涤", "低咪唑洗涤 3 次。", nil),
                step("protein-0531-4", "洗脱", "250 mM imidazole 洗脱并收集分段。", nil)
            ])
        ]),
        demoDay("2026-06-01", "6月1日", "周一", [
            demoRun("demo-0601-lipo2000", "Lipo2000 转染对照", .cell, "09:00", "转染（Lipo2000）", "12孔板 × 4 孔", "demo-project-cell", lipo2000Protocol.steps),
            demoRun("demo-0601-wb-gel", "SDS-PAGE 跑胶", .protein, "17:00", "WB", "10% gel", "demo-project-protein", [
                step("gel-0601-1", "制胶", "配置 10% 分离胶与浓缩胶。", nil),
                step("gel-0601-2", "上样", "样品煮沸后上样。", 5),
                step("gel-0601-3", "跑胶", "恒压跑至溴酚蓝前沿接近胶底。", 75)
            ])
        ]),
        demoDay("2026-06-02", "6月2日", "周二", [
            demoRun("demo-0602-miniprep", "质粒小提与酶切验证", .nucleic, "10:20", "Plasmid miniprep", "8 tubes", "demo-project-cloning", [
                step("mini-0602-1", "菌液离心", "12000 rpm 收集菌体。", 1),
                step("mini-0602-2", "碱裂解", "P1/P2/N3 按顺序处理。", 5),
                step("mini-0602-3", "洗脱 DNA", "EB 洗脱后测浓度。", 2),
                step("mini-0602-4", "酶切验证", "设置双酶切体系并跑胶。", 60)
            ])
        ]),
        demoDay("2026-06-03", "6月3日", "周三", [
            demoRun("demo-0603-elisa", "ELISA 样品检测", .protein, "09:40", "ELISA", "96 孔板", "demo-project-protein", [
                step("elisa-0603-1", "加样", "标准品与样品按设计加入。", nil),
                step("elisa-0603-2", "孵育", "37 C 孵育。", 60),
                step("elisa-0603-3", "洗板", "洗板 5 次，拍干。", nil),
                step("elisa-0603-4", "显色读数", "TMB 显色后终止，450 nm 读数。", 15)
            ]),
            demoRun("demo-0603-passage", "细胞换液与状态记录", .cell, "16:30", "细胞传代", "2 dishes", "demo-project-cell", cellPassageProtocol.steps)
        ]),
        demoDay("2026-06-04", "6月4日", "周四", [
            demoRun("demo-0604-bli", "BLI 动力学正式检测", .protein, "10:00", "BLI kinetics", "8-point dilution", "demo-project-protein", [
                step("bli-0604-1", "传感器预湿", "Kinetics Buffer 预湿。", 10),
                step("bli-0604-2", "加载配体", "加载 His-tag 蛋白至目标响应。", 8),
                step("bli-0604-3", "结合/解离", "按浓度梯度采集结合和解离曲线。", 40),
                step("bli-0604-4", "再生与导出", "导出原始曲线并记录 KD。", nil)
            ]),
            demoRun("demo-0604-wb", "WB 二抗与显影", .protein, "15:30", "WB", "1 membrane", "demo-project-protein", [
                step("wb-0604-1", "TBST 洗膜", "洗膜 3 次，每次 10 min。", 30),
                step("wb-0604-2", "二抗孵育", "室温二抗孵育。", 60),
                step("wb-0604-3", "ECL 显影", "ECL 反应并采图。", nil)
            ])
        ])
    ]

    static let demoTodayRuns: [LabRun] = [
        demoRun("demo-today-passage", "293T 细胞传代", .cell, "09:00", "细胞传代", "T75 / 1:4", "demo-project-cell", cellPassageProtocol.steps),
        demoRun("demo-today-lipo3000", "Lipo3000 转染 pLVX-GFP", .cell, "11:00", "转染（Lipo3000）", "6孔板 × 3 孔", "demo-project-cell", [
            step("today-lipo-1", "换无双抗培养基", "PBS 清洗 2 次，每孔加入 1.75 ml 无双抗培养基。", nil),
            step("today-lipo-2", "制备 A 组", "125 ul Opti-MEM 稀释 5 ul Lipofectamine 3000。", nil),
            step("today-lipo-3", "制备 B 组", "125 ul Opti-MEM 稀释 2.5 ug DNA 和 5 ul P3000。", nil),
            step("today-lipo-4", "复合物孵育", "A/B 组混合后室温孵育。", 15),
            step("today-lipo-5", "加入细胞", "将复合物滴加至细胞孔中，轻晃混匀。", nil),
            step("today-lipo-6", "24 h 后观察", "明日进行荧光观察或表达检测。", nil, true)
        ]),
        demoRun("demo-today-miniprep", "质粒小提与测序准备", .nucleic, "14:30", "Plasmid miniprep", "6 tubes", "demo-project-cloning", [
            step("today-mini-1", "菌液离心", "12000 rpm 收集菌体。", 1),
            step("today-mini-2", "碱裂解", "P1/P2/N3 顺序处理，避免剧烈振荡。", 5),
            step("today-mini-3", "上柱洗涤", "按小提试剂盒流程洗涤。", nil),
            step("today-mini-4", "洗脱 DNA", "EB 洗脱并测浓度。", 2),
            step("today-mini-5", "送测序", "按样品编号整理测序信息。", nil)
        ]),
        demoRun("demo-today-wb", "WB 二抗孵育与显影", .protein, "17:00", "WB", "1 membrane", "demo-project-protein", [
            step("today-wb-1", "TBST 洗膜", "洗膜 3 次，每次 10 min。", 30),
            step("today-wb-2", "二抗孵育", "室温孵育二抗。", 60),
            step("today-wb-3", "再次洗膜", "TBST 洗膜 3 次。", 30),
            step("today-wb-4", "ECL 显影", "加 ECL 后采集图像。", nil)
        ])
    ]

    private static func step(_ id: String, _ title: String, _ detail: String, _ duration: Int?, _ carryOver: Bool = false) -> LabStep {
        LabStep(id: id, title: title, detail: detail, durationMinutes: duration, isCarryOver: carryOver)
    }

    private static func demoRun(_ id: String, _ title: String, _ area: WorkflowArea, _ time: String, _ protocolName: String, _ volume: String, _ projectID: String, _ steps: [LabStep]) -> LabRun {
        LabRun(id: id, title: title, area: area, timeLabel: time, status: "已完成", protocolName: protocolName, scaledVolumeLabel: volume, projectID: projectID, steps: steps)
    }

    private static func demoDay(_ idDate: String, _ label: String, _ weekday: String, _ runs: [LabRun]) -> ExperimentDayRecord {
        ExperimentDayRecord(id: "past-\(idDate)", dateLabel: label, weekday: weekday, summary: "\(runs.count) 个实验 · \(runs.map(\.title).joined(separator: "、"))", runs: runs)
    }
}
