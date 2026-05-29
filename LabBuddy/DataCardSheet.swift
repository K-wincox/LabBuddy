import SwiftUI
import PhotosUI

// MARK: - Data Card Sheet

struct DataCardSheet: View {
    let run: LabRun
    let completedStepIDs: Set<String>
    @AppStorage("profileDataCardWatermark") private var showWatermark = true
    @Environment(\.dismiss) private var dismiss

    @State private var notes = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var cardImage: Image?
    @State private var cardImageData: Data?
    @State private var hiddenFields: Set<String> = []
    @State private var showShareSheet = false
    @State private var renderedImage: UIImage?
    @State private var copied = false
    @State private var saveSuccess = false

    private var doneCount: Int {
        run.steps.filter { completedStepIDs.contains($0.id) }.count
    }

    private var conditionText: String {
        var lines: [String] = []
        if !hiddenFields.contains("protocol") { lines.append("Protocol: \(run.protocolName)") }
        if !hiddenFields.contains("scale") { lines.append("用量/规模: \(run.scaledVolumeLabel)") }
        if !hiddenFields.contains("type") { lines.append("实验类型: \(run.area.rawValue)") }
        if !hiddenFields.contains("steps") { lines.append("步骤完成: \(doneCount)/\(run.steps.count)") }
        if !hiddenFields.contains("time") { lines.append("记录时间: \(Date.now.formatted(date: .abbreviated, time: .shortened))") }
        if !notes.isEmpty { lines.append("备注: \(notes)") }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Card preview
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(run.title)
                                    .font(.title2.bold())
                                Text(run.area.rawValue)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(run.timeLabel)
                                .font(.headline.monospacedDigit())
                        }

                        // Image area — interactive
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Group {
                                if let cardImage {
                                    cardImage
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 220)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(LinearGradient(
                                                colors: [.teal.opacity(0.26), .cyan.opacity(0.14), .indigo.opacity(0.12)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing
                                            ))
                                            .frame(height: 220)
                                        VStack(spacing: 10) {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.largeTitle)
                                                .foregroundStyle(.teal)
                                            Text("点击添加结果图片")
                                                .font(.subheadline.weight(.semibold))
                                            Text("跑胶、WB、细胞图片均可")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .onChange(of: selectedPhoto) {
                            Task {
                                if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                                    cardImageData = data
                                    if let uiImage = UIImage(data: data) {
                                        cardImage = Image(uiImage: uiImage)
                                    }
                                }
                            }
                        }

                        // Editable metadata
                        VStack(alignment: .leading, spacing: 8) {
                            Text("实验条件")
                                .font(.headline)
                            FieldToggleRow(label: "Protocol", value: run.protocolName, fieldKey: "protocol", hiddenFields: $hiddenFields)
                            FieldToggleRow(label: "用量/规模", value: run.scaledVolumeLabel, fieldKey: "scale", hiddenFields: $hiddenFields)
                            FieldToggleRow(label: "实验类型", value: run.area.rawValue, fieldKey: "type", hiddenFields: $hiddenFields)
                            FieldToggleRow(label: "步骤完成", value: "\(doneCount)/\(run.steps.count)", fieldKey: "steps", hiddenFields: $hiddenFields)
                            FieldToggleRow(label: "记录时间", value: Date.now.formatted(date: .abbreviated, time: .shortened), fieldKey: "time", hiddenFields: $hiddenFields)
                        }

                        // Notes
                        VStack(alignment: .leading, spacing: 6) {
                            Text("备注")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("补充实验备注（可选）", text: $notes, axis: .vertical)
                                .lineLimit(2...4)
                                .textFieldStyle(.roundedBorder)
                        }

                        if showWatermark {
                            Text("Powered by LabBuddy")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(18)
                    .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                    // Actions
                    VStack(spacing: 10) {
                        Button {
                            Clipboard.copy(conditionText)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                        } label: {
                            Label(copied ? "已复制" : "复制实验条件", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button {
                            if let rendered = renderCard() {
                                UIImageWriteToSavedPhotosAlbum(rendered, nil, nil, nil)
                                saveSuccess = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saveSuccess = false }
                            }
                        } label: {
                            Label(saveSuccess ? "已保存到相册" : "保存到相册", systemImage: saveSuccess ? "checkmark.circle.fill" : "photo.on.rectangle.angled")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button {
                            if let rendered = renderCard() {
                                renderedImage = rendered
                                showShareSheet = true
                            }
                        } label: {
                            Label("分享", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .padding(18)
            }
            .background(Color.labBackground)
            .navigationTitle("结果卡片")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let img = renderedImage {
                    ShareSheet(items: [img])
                }
            }
        }
    }

    private func renderCard() -> UIImage? {
        let renderer = ImageRenderer(content:
            CardRenderView(
                run: run,
                doneCount: doneCount,
                notes: notes,
                hiddenFields: hiddenFields,
                cardImage: cardImage,
                showWatermark: showWatermark
            )
            .frame(width: 375)
        )
        renderer.scale = 3.0
        return renderer.uiImage
    }
}

// MARK: - Field Toggle Row

struct FieldToggleRow: View {
    let label: String
    let value: String
    let fieldKey: String
    @Binding var hiddenFields: Set<String>

    private var isVisible: Bool { !hiddenFields.contains(fieldKey) }

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isVisible ? .primary : .tertiary)
                .strikethrough(!isVisible)
            Button {
                if hiddenFields.contains(fieldKey) {
                    hiddenFields.remove(fieldKey)
                } else {
                    hiddenFields.insert(fieldKey)
                }
            } label: {
                Image(systemName: isVisible ? "eye" : "eye.slash")
                    .foregroundStyle(isVisible ? .teal : .secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Card Render View (for ImageRenderer)

struct CardRenderView: View {
    let run: LabRun
    let doneCount: Int
    let notes: String
    let hiddenFields: Set<String>
    let cardImage: Image?
    let showWatermark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(run.title).font(.title2.bold())
                    Text(run.area.rawValue).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Text(run.timeLabel).font(.headline.monospacedDigit())
            }

            if let img = cardImage {
                img.resizable().scaledToFill()
                    .frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [.teal.opacity(0.26), .cyan.opacity(0.14)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 200)
                    .overlay(Text("结果图").foregroundStyle(.teal))
            }

            VStack(spacing: 4) {
                if !hiddenFields.contains("protocol") { CardMetaRow(label: "Protocol", value: run.protocolName) }
                if !hiddenFields.contains("scale") { CardMetaRow(label: "用量/规模", value: run.scaledVolumeLabel) }
                if !hiddenFields.contains("type") { CardMetaRow(label: "实验类型", value: run.area.rawValue) }
                if !hiddenFields.contains("steps") { CardMetaRow(label: "步骤完成", value: "\(doneCount)/\(run.steps.count)") }
                if !hiddenFields.contains("time") { CardMetaRow(label: "记录时间", value: Date.now.formatted(date: .abbreviated, time: .shortened)) }
            }

            if !notes.isEmpty {
                Text(notes).font(.subheadline).foregroundStyle(.secondary)
            }

            if showWatermark {
                Text("Powered by LabBuddy")
                    .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(20)
        .background(Color.white)
    }
}

struct CardMetaRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold))
        }
        .font(.subheadline)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Color extension (shared across views)

extension Color {
    static let labBackground = Color(red: 0.95, green: 0.97, blue: 0.97)
    static let labPanel = Color(red: 1.0, green: 1.0, blue: 0.99)
    static let labInset = Color(red: 0.90, green: 0.95, blue: 0.95)
}

// MARK: - Clipboard (shared)

enum Clipboard {
    static func copy(_ text: String) {
        UIPasteboard.general.string = text
    }
}
