import Foundation
import CoreImage

/// 用户自定义滤镜。
/// 存储值统一为内部小数刻度（兼容旧数据），界面上按 0~100 的修图习惯显示，
/// 两者之间的换算集中在 FilterEditorView 的绑定里。
struct CameraFilter: Identifiable, Codable, Equatable {
    /// 内置「原图」滤镜的固定 ID（不可删除、不可编辑）
    static let originalID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    var id: UUID = UUID()
    var name: String = ""
    /// 亮度，-0.5 ~ 0.5，默认 0
    var brightness: Double = 0
    /// 对比度，0.5 ~ 1.5，默认 1
    var contrast: Double = 1
    /// 高光，-1（压暗亮部）~ 1（提亮亮部），默认 0
    var highlights: Double = 0
    /// 阴影，-1（压暗暗部）~ 1（提亮暗部），默认 0
    var shadows: Double = 0
    /// 饱和度，0 ~ 2，默认 1
    var saturation: Double = 1
    /// 自然饱和度，-1 ~ 1，默认 0（只加强低饱和区域，肤色不易过艳）
    var vibrance: Double = 0
    /// 曝光，-2 ~ 2，默认 0
    var exposure: Double = 0
    /// 色温，-1（偏冷）~ 1（偏暖），默认 0
    var temperature: Double = 0
    /// 色调，-100（偏绿）~ 100（偏品红），默认 0
    var tint: Double = 0
    /// 色相旋转角度，-180 ~ 180 度，默认 0
    var hue: Double = 0
    /// 清晰度（局部对比），0 ~ 1，默认 0
    var clarity: Double = 0
    /// 去朦胧，0 ~ 1，默认 0
    var dehaze: Double = 0
    /// 颗粒，0 ~ 1，默认 0
    var grain: Double = 0
    /// 褪色（抬黑），0 ~ 1，默认 0
    var fade: Double = 0
    /// 锐化，0 ~ 1，默认 0
    var sharpen: Double = 0
    /// 暗角，0 ~ 2，默认 0
    var vignette: Double = 0

    init(id: UUID = UUID(),
         name: String = "",
         brightness: Double = 0,
         contrast: Double = 1,
         highlights: Double = 0,
         shadows: Double = 0,
         saturation: Double = 1,
         vibrance: Double = 0,
         exposure: Double = 0,
         temperature: Double = 0,
         tint: Double = 0,
         hue: Double = 0,
         clarity: Double = 0,
         dehaze: Double = 0,
         grain: Double = 0,
         fade: Double = 0,
         sharpen: Double = 0,
         vignette: Double = 0) {
        self.id = id
        self.name = name
        self.brightness = brightness
        self.contrast = contrast
        self.highlights = highlights
        self.shadows = shadows
        self.saturation = saturation
        self.vibrance = vibrance
        self.exposure = exposure
        self.temperature = temperature
        self.tint = tint
        self.hue = hue
        self.clarity = clarity
        self.dehaze = dehaze
        self.grain = grain
        self.fade = fade
        self.sharpen = sharpen
        self.vignette = vignette
    }

    /// 兼容旧版本 filters.json：缺失字段按默认值处理，并夹到合法范围，
    /// 避免旧文件里误输入的 0~100 数值把画面拉爆。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        brightness = Self.clamp(try c.decodeIfPresent(Double.self, forKey: .brightness) ?? 0, -0.5, 0.5)
        contrast = Self.clamp(try c.decodeIfPresent(Double.self, forKey: .contrast) ?? 1, 0.5, 1.5)
        highlights = Self.clamp(try c.decodeIfPresent(Double.self, forKey: .highlights) ?? 0, -1, 1)
        shadows = Self.clamp(try c.decodeIfPresent(Double.self, forKey: .shadows) ?? 0, -1, 1)
        saturation = Self.clamp(try c.decodeIfPresent(Double.self, forKey: .saturation) ?? 1, 0, 2)
        vibrance = Self.clamp(try c.decodeIfPresent(Double.self, forKey: .vibrance) ?? 0, -1, 1)
        exposure = Self.clamp(try c.decodeIfPresent(Double.self, forKey: .exposure) ?? 0, -2, 2)
        temperature = Self.clamp(try c.decodeIfPresent(Double.self, forKey: .temperature) ?? 0, -1, 1)
        tint = Self.clamp(try c.decodeIfPresent(Double.self, forKey: .tint) ?? 0, -100, 100)
        hue = Self.clamp(try c.decodeIfPresent(Double.self, forKey: .hue) ?? 0, -180, 180)
        clarity = Self.clamp(try c.decodeIfPresent(Double.self, forKey: .clarity) ?? 0, 0, 1)
        dehaze = Self.clamp(try c.decodeIfPresent(Double.self, forKey: .dehaze) ?? 0, 0, 1)
        grain = Self.clamp(try c.decodeIfPresent(Double.self, forKey: .grain) ?? 0, 0, 1)
        fade = Self.clamp(try c.decodeIfPresent(Double.self, forKey: .fade) ?? 0, 0, 1)
        sharpen = Self.clamp(try c.decodeIfPresent(Double.self, forKey: .sharpen) ?? 0, 0, 1)
        vignette = Self.clamp(try c.decodeIfPresent(Double.self, forKey: .vignette) ?? 0, 0, 2)
    }

    private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }

    static let original = CameraFilter(id: originalID, name: "原图")

    var isOriginal: Bool { id == CameraFilter.originalID }

    /// 首次启动时的示例滤镜，供用户参考修改
    static let samples: [CameraFilter] = [
        CameraFilter(name: "清新", brightness: 0.05, contrast: 1.05, shadows: 0.2,
                     saturation: 1.1, vibrance: 0.25, exposure: 0.15, temperature: -0.15),
        CameraFilter(name: "复古", brightness: 0, contrast: 0.95, highlights: -0.25,
                     saturation: 0.7, exposure: -0.1, temperature: 0.35,
                     fade: 0.3, grain: 0.25, vignette: 0.8),
        CameraFilter(name: "黑白", contrast: 1.2, shadows: 0.1, saturation: 0,
                     clarity: 0.3)
    ]

    /// 静态颗粒纹理：只生成一次，避免实时预览每帧变化产生闪烁
    private static let grainTexture: CIImage? = {
        guard let noise = CIFilter(name: "CIRandomGenerator")?.outputImage else { return nil }
        guard let mono = CIFilter(name: "CIColorMatrix") else { return nil }
        mono.setValue(noise, forKey: kCIInputImageKey)
        let gray = CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0)
        mono.setValue(gray, forKey: "inputRVector")
        mono.setValue(gray, forKey: "inputGVector")
        mono.setValue(gray, forKey: "inputBVector")
        return mono.outputImage?.cropped(to: CGRect(x: 0, y: 0, width: 1600, height: 1600))
    }()

    /// 高光 / 阴影共用一条色调曲线：
    /// 阴影值抬升或压低 25% 灰阶，高光值抬升或压低 75% 灰阶，两端锚定
    private static func toneCurve(highlights: Double, shadows: Double) -> CIFilter? {
        guard let curve = CIFilter(name: "CIToneCurve") else { return nil }
        func point(_ x: Double, _ y: Double) -> CIVector {
            CIVector(x: CGFloat(x), y: CGFloat(min(max(y, 0), 1)))
        }
        let s = shadows * 0.10
        let h = highlights * 0.12
        curve.setValue(point(0, 0), forKey: "inputPoint0")
        curve.setValue(point(0.25, 0.25 + s), forKey: "inputPoint1")
        curve.setValue(point(0.5, 0.5), forKey: "inputPoint2")
        curve.setValue(point(0.75, 0.75 + h), forKey: "inputPoint3")
        curve.setValue(point(1, 1), forKey: "inputPoint4")
        return curve
    }

    /// 把当前参数应用到 CIImage 上，返回滤镜链输出
    func apply(to input: CIImage) -> CIImage {
        var image = input

        // 曝光
        if exposure != 0 {
            let f = CIFilter(name: "CIExposureAdjust")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(exposure, forKey: kCIInputEVKey)
            image = f.outputImage ?? image
        }

        // 亮度 / 对比度 / 饱和度
        if brightness != 0 || contrast != 1 || saturation != 1 {
            let f = CIFilter(name: "CIColorControls")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(brightness, forKey: kCIInputBrightnessKey)
            f.setValue(contrast, forKey: kCIInputContrastKey)
            f.setValue(saturation, forKey: kCIInputSaturationKey)
            image = f.outputImage ?? image
        }

        // 自然饱和度
        if vibrance != 0 {
            let f = CIFilter(name: "CIVibrance")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(vibrance, forKey: "inputAmount")
            image = f.outputImage ?? image
        }

        // 高光 / 阴影：双向调整，用色调曲线同时控制亮部和暗部
        if highlights != 0 || shadows != 0 {
            if let curve = Self.toneCurve(highlights: highlights, shadows: shadows) {
                curve.setValue(image, forKey: kCIInputImageKey)
                image = curve.outputImage ?? image
            }
        }

        // 去朦胧：提对比 + 提饱和度
        if dehaze != 0 {
            let f = CIFilter(name: "CIColorControls")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(1 + dehaze * 0.5, forKey: kCIInputContrastKey)
            f.setValue(1 + dehaze * 0.4, forKey: kCIInputSaturationKey)
            image = f.outputImage ?? image
        }

        // 清晰度：局部对比增强
        if clarity != 0 {
            let f = CIFilter(name: "CIUnsharpMask")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(12.0, forKey: kCIInputRadiusKey)
            f.setValue(clarity * 1.5, forKey: kCIInputIntensityKey)
            image = f.outputImage ?? image
        }

        // 颗粒：静态噪点 + 柔光叠加
        if grain > 0, let texture = Self.grainTexture {
            let noise = texture.cropped(to: image.extent)
            let alpha = CIFilter(name: "CIColorMatrix")!
            alpha.setValue(noise, forKey: kCIInputImageKey)
            let amount = CGFloat(0.35 * grain)
            alpha.setValue(CIVector(x: amount, y: amount, z: amount, w: 0), forKey: "inputAVector")
            if let noisy = alpha.outputImage,
               let blend = CIFilter(name: "CISoftLightBlendMode") {
                blend.setValue(noisy, forKey: kCIInputImageKey)
                blend.setValue(image, forKey: kCIInputBackgroundImageKey)
                image = blend.outputImage ?? image
            }
        }

        // 褪色：整体抬黑，制造胶片发白感
        if fade != 0 {
            let f = CIFilter(name: "CIColorMatrix")!
            f.setValue(image, forKey: kCIInputImageKey)
            let lift = CGFloat(fade * 0.18)
            f.setValue(CIVector(x: lift, y: lift, z: lift, w: 0), forKey: "inputBiasVector")
            image = f.outputImage ?? image
        }

        // 色温 / 色调
        if temperature != 0 || tint != 0 {
            let f = CIFilter(name: "CITemperatureAndTint")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            let targetTemp = 6500 - temperature * 3000
            f.setValue(CIVector(x: CGFloat(targetTemp), y: CGFloat(tint)), forKey: "inputTargetNeutral")
            image = f.outputImage ?? image
        }

        // 色相
        if hue != 0 {
            let f = CIFilter(name: "CIHueAdjust")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(hue * .pi / 180, forKey: kCIInputAngleKey)
            image = f.outputImage ?? image
        }

        // 锐化
        if sharpen != 0 {
            let f = CIFilter(name: "CISharpenLuminance")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(sharpen, forKey: kCIInputSharpnessKey)
            image = f.outputImage ?? image
        }

        // 暗角
        if vignette != 0 {
            let f = CIFilter(name: "CIVignette")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(vignette, forKey: kCIInputIntensityKey)
            f.setValue(1.0, forKey: kCIInputRadiusKey)
            image = f.outputImage ?? image
        }

        return image
    }
}
