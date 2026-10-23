import Foundation
import CoreImage

/// 用户自定义滤镜：名称 + 12 个可调参数，全部参数为默认值时即为「原图」
struct CameraFilter: Identifiable, Codable, Equatable {
    /// 内置「原图」滤镜的固定 ID（不可删除、不可编辑）
    static let originalID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    var id: UUID = UUID()
    var name: String = ""
    /// 亮度，-0.2 ~ 0.2，默认 0
    var brightness: Double = 0
    /// 对比度，0.5 ~ 1.5，默认 1
    var contrast: Double = 1
    /// 高光压制，0 ~ 1，默认 0（越大越压暗画面亮部，找回过曝细节）
    var highlights: Double = 0
    /// 阴影提亮，0 ~ 1，默认 0（越大越提亮画面暗部）
    var shadows: Double = 0
    /// 饱和度，0 ~ 2，默认 1
    var saturation: Double = 1
    /// 自然饱和度（vibrance），-1 ~ 1，默认 0（只加强低饱和区域，肤色不易过艳）
    var vibrance: Double = 0
    /// 曝光，-2 ~ 2，默认 0
    var exposure: Double = 0
    /// 色温，-1（偏冷）~ 1（偏暖），默认 0
    var temperature: Double = 0
    /// 色调，-100（偏绿）~ 100（偏品红），默认 0
    var tint: Double = 0
    /// 色相旋转角度，-180 ~ 180 度，默认 0
    var hue: Double = 0
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
        self.sharpen = sharpen
        self.vignette = vignette
    }

    /// 兼容旧版本存下的 filters.json：缺失的新参数按默认值处理
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        brightness = try c.decodeIfPresent(Double.self, forKey: .brightness) ?? 0
        contrast = try c.decodeIfPresent(Double.self, forKey: .contrast) ?? 1
        highlights = try c.decodeIfPresent(Double.self, forKey: .highlights) ?? 0
        shadows = try c.decodeIfPresent(Double.self, forKey: .shadows) ?? 0
        saturation = try c.decodeIfPresent(Double.self, forKey: .saturation) ?? 1
        vibrance = try c.decodeIfPresent(Double.self, forKey: .vibrance) ?? 0
        exposure = try c.decodeIfPresent(Double.self, forKey: .exposure) ?? 0
        temperature = try c.decodeIfPresent(Double.self, forKey: .temperature) ?? 0
        tint = try c.decodeIfPresent(Double.self, forKey: .tint) ?? 0
        hue = try c.decodeIfPresent(Double.self, forKey: .hue) ?? 0
        sharpen = try c.decodeIfPresent(Double.self, forKey: .sharpen) ?? 0
        vignette = try c.decodeIfPresent(Double.self, forKey: .vignette) ?? 0
    }

    static let original = CameraFilter(id: originalID, name: "原图")

    var isOriginal: Bool { id == CameraFilter.originalID }

    /// 首次启动时的示例滤镜，供用户参考修改
    static let samples: [CameraFilter] = [
        CameraFilter(name: "清新", brightness: 0.05, contrast: 1.05, shadows: 0.2,
                     saturation: 1.1, vibrance: 0.25, exposure: 0.15, temperature: -0.15),
        CameraFilter(name: "复古", brightness: 0, contrast: 0.95, highlights: 0.25,
                     saturation: 0.7, exposure: -0.1, temperature: 0.35, vignette: 0.8),
        CameraFilter(name: "黑白", contrast: 1.2, shadows: 0.1, saturation: 0)
    ]

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

        // 自然饱和度：只提升低饱和部分，避免整体过艳
        if vibrance != 0 {
            let f = CIFilter(name: "CIVibrance")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(vibrance, forKey: "inputAmount")
            image = f.outputImage ?? image
        }

        // 高光压制 + 阴影提亮
        if highlights != 0 || shadows != 0 {
            let f = CIFilter(name: "CIHighlightShadowAdjust")!
            f.setValue(image, forKey: kCIInputImageKey)
            // inputHighlightAmount：1 为不变，越小高光越暗
            f.setValue(1.0 - highlights * 0.8, forKey: "inputHighlightAmount")
            // inputShadowAmount：0 为不变，越大暗部越亮
            f.setValue(shadows, forKey: "inputShadowAmount")
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
