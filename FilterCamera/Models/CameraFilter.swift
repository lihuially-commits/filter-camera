import Foundation
import CoreImage

/// 用户自定义滤镜：名称 + 9 个可调参数，全部参数为默认值时即为「原图」
struct CameraFilter: Identifiable, Codable, Equatable {
    /// 内置「原图」滤镜的固定 ID（不可删除、不可编辑）
    static let originalID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    var id: UUID = UUID()
    var name: String = ""
    /// 亮度，-0.2 ~ 0.2，默认 0
    var brightness: Double = 0
    /// 对比度，0.5 ~ 1.5，默认 1
    var contrast: Double = 1
    /// 饱和度，0 ~ 2，默认 1
    var saturation: Double = 1
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

    static let original = CameraFilter(id: originalID, name: "原图")

    var isOriginal: Bool { id == CameraFilter.originalID }

    /// 首次启动时的示例滤镜，供用户参考修改
    static let samples: [CameraFilter] = [
        CameraFilter(name: "清新", brightness: 0.05, contrast: 1.05, saturation: 1.15,
                     exposure: 0.15, temperature: -0.15),
        CameraFilter(name: "复古", brightness: 0, contrast: 0.95, saturation: 0.7,
                     exposure: -0.1, temperature: 0.35, vignette: 0.8),
        CameraFilter(name: "黑白", contrast: 1.2, saturation: 0)
    ]

    /// 把当前参数应用到 CIImage 上，返回滤镜链输出
    func apply(to input: CIImage) -> CIImage {
        var image = input

        if brightness != 0 || contrast != 1 || saturation != 1 {
            let f = CIFilter(name: "CIColorControls")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(brightness, forKey: kCIInputBrightnessKey)
            f.setValue(contrast, forKey: kCIInputContrastKey)
            f.setValue(saturation, forKey: kCIInputSaturationKey)
            image = f.outputImage ?? image
        }

        if exposure != 0 {
            let f = CIFilter(name: "CIExposureAdjust")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(exposure, forKey: kCIInputEVKey)
            image = f.outputImage ?? image
        }

        if temperature != 0 || tint != 0 {
            let f = CIFilter(name: "CITemperatureAndTint")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            let targetTemp = 6500 - temperature * 3000
            f.setValue(CIVector(x: CGFloat(targetTemp), y: CGFloat(tint)), forKey: "inputTargetNeutral")
            image = f.outputImage ?? image
        }

        if hue != 0 {
            let f = CIFilter(name: "CIHueAdjust")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(hue * .pi / 180, forKey: kCIInputAngleKey)
            image = f.outputImage ?? image
        }

        if sharpen != 0 {
            let f = CIFilter(name: "CISharpenLuminance")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(sharpen, forKey: kCIInputSharpnessKey)
            image = f.outputImage ?? image
        }

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
