import SwiftUI
import CoreImage
import UIKit

/// 滤镜编辑器：名称 + 参数表格（滑杆 + 数字输入），实时预览效果
struct FilterEditorView: View {
    @ObservedObject var store: FilterStore
    let isNew: Bool
    let previewImage: CIImage?

    @Environment(\.dismiss) private var dismiss
    @State private var draft: CameraFilter
    @State private var preview: UIImage?

    init(store: FilterStore, filter: CameraFilter, isNew: Bool, previewImage: CIImage?) {
        self.store = store
        self.isNew = isNew
        self.previewImage = previewImage
        _draft = State(initialValue: filter)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack {
                        if let preview {
                            Image(uiImage: preview)
                                .resizable()
                                .scaledToFit()
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                }

                Section("滤镜名称") {
                    TextField("输入名称，如：胶片、日系", text: $draft.name)
                }

                Section("光影") {
                    ParamRow(title: "曝光", value: $draft.exposure.uiScaled(50), range: -100...100, step: 1)
                    ParamRow(title: "亮度", value: $draft.brightness.uiScaled(200), range: -100...100, step: 1)
                    ParamRow(title: "对比度",
                            value: $draft.contrast.ui({ ($0 - 1) * 200 }, { 1 + $0 / 200 }),
                            range: -100...100, step: 1)
                    ParamRow(title: "高光压制", value: $draft.highlights.uiScaled(100), range: 0...100, step: 1)
                    ParamRow(title: "阴影提亮", value: $draft.shadows.uiScaled(100), range: 0...100, step: 1)
                }

                Section("色彩") {
                    ParamRow(title: "饱和度",
                            value: $draft.saturation.ui({ ($0 - 1) * 100 }, { 1 + $0 / 100 }),
                            range: -100...100, step: 1)
                    ParamRow(title: "自然饱和度", value: $draft.vibrance.uiScaled(100), range: -100...100, step: 1)
                    ParamRow(title: "色温", value: $draft.temperature.uiScaled(100), range: -100...100, step: 1)
                    ParamRow(title: "色调", value: $draft.tint, range: -100...100, step: 1)
                    ParamRow(title: "色相", value: $draft.hue.ui({ $0 / 1.8 }, { $0 * 1.8 }),
                            range: -100...100, step: 1)
                }

                Section("细节") {
                    ParamRow(title: "清晰度", value: $draft.clarity.uiScaled(100), range: 0...100, step: 1)
                    ParamRow(title: "去朦胧", value: $draft.dehaze.uiScaled(100), range: 0...100, step: 1)
                    ParamRow(title: "锐化", value: $draft.sharpen.uiScaled(100), range: 0...100, step: 1)
                }

                Section("质感") {
                    ParamRow(title: "颗粒", value: $draft.grain.uiScaled(100), range: 0...100, step: 1)
                    ParamRow(title: "褪色", value: $draft.fade.uiScaled(100), range: 0...100, step: 1)
                    ParamRow(title: "暗角", value: $draft.vignette.uiScaled(50), range: 0...100, step: 1)
                }
            }
            .navigationTitle(isNew ? "新建滤镜" : "编辑滤镜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveAndClose() }
                }
            }
            .onAppear { renderPreview() }
            .onChange(of: draft) { _ in renderPreview() }
        }
    }

    private func saveAndClose() {
        var filter = draft
        let trimmed = filter.name.trimmingCharacters(in: .whitespaces)
        filter.name = trimmed.isEmpty ? "未命名滤镜" : trimmed
        if isNew {
            store.add(filter)
        } else {
            store.update(filter)
        }
        dismiss()
    }

    private func renderPreview() {
        // 底图：优先用相机当前帧，否则生成示例图；统一缩到 800px 内保证流畅
        let base = previewImage ?? SampleImage.make()
        let scale = min(1, 800 / max(base.extent.width, base.extent.height))
        let small = scale < 1 ? base.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) : base
        let filter = draft
        Task.detached(priority: .userInitiated) {
            let ui = FilterRenderer.shared.renderUIImage(small, filter: filter)
            await MainActor.run {
                self.preview = ui
            }
        }
    }
}

/// 内部存小数刻度，界面统一按 -100~100 / 0~100 显示
private extension Binding where Value == Double {
    /// 线性换算：内部值 × factor = 界面值
    func uiScaled(_ factor: Double) -> Binding<Double> {
        Binding(get: { wrappedValue * factor }, set: { wrappedValue = $0 / factor })
    }

    /// 自定义双向映射（用于对比度、饱和度这类以 1 为中点的参数）
    func ui(_ toUI: @escaping (Double) -> Double,
            _ fromUI: @escaping (Double) -> Double) -> Binding<Double> {
        Binding(get: { toUI(wrappedValue) }, set: { wrappedValue = fromUI($0) })
    }
}

/// 参数行：名称 + 数字输入框 + 滑杆，二者联动
private struct ParamRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                TextField("", value: $value, format: .number)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 72)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { clamp() }
            }
            Slider(value: $value, in: range, step: step)
        }
        .padding(.vertical, 2)
    }

    private func clamp() {
        value = min(max(value, range.lowerBound), range.upperBound)
    }
}

/// 编辑器无相机帧时使用的示例底图（彩色渐变 + 灰阶，便于观察滤镜效果）
enum SampleImage {
    private static var cached: CIImage?

    static func make() -> CIImage {
        if let cached { return cached }
        let size = CGSize(width: 720, height: 480)
        let renderer = UIGraphicsImageRenderer(size: size)
        let uiImage = renderer.image { ctx in
            // 彩色渐变区（上 2/3）
            let colors: [UIColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .systemPurple]
            let stripeW = size.width / CGFloat(colors.count)
            for (i, color) in colors.enumerated() {
                color.setFill()
                ctx.fill(CGRect(x: CGFloat(i) * stripeW, y: 0, width: stripeW, height: size.height * 2 / 3))
            }
            // 灰阶区（下 1/3）
            let steps = 10
            let grayW = size.width / CGFloat(steps)
            for i in 0..<steps {
                let v = CGFloat(i) / CGFloat(steps - 1)
                UIColor(white: v, alpha: 1).setFill()
                ctx.fill(CGRect(x: CGFloat(i) * grayW, y: size.height * 2 / 3, width: grayW, height: size.height / 3))
            }
        }
        let image = CIImage(image: uiImage) ?? CIImage(color: .gray).cropped(to: CGRect(origin: .zero, size: size))
        cached = image
        return image
    }
}
