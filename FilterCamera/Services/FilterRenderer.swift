import Foundation
import CoreImage
import MetalKit
import UIKit

/// 全局共享的 Core Image 渲染器，底层走 Metal GPU
final class FilterRenderer {
    static let shared = FilterRenderer()

    let device: MTLDevice?
    let context: CIContext
    let commandQueue: MTLCommandQueue?
    let colorSpace: CGColorSpace

    private init() {
        let device = MTLCreateSystemDefaultDevice()
        self.device = device
        self.commandQueue = device?.makeCommandQueue()
        self.colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        if let device {
            context = CIContext(mtlDevice: device, options: [.workingColorSpace: colorSpace])
        } else {
            context = CIContext(options: [.workingColorSpace: colorSpace])
        }
    }

    /// 应用滤镜并输出 CGImage（按输入图原始范围裁剪）
    func render(_ image: CIImage, filter: CameraFilter) -> CGImage? {
        let output = filter.apply(to: image)
        return context.createCGImage(output, from: image.extent)
    }

    func renderUIImage(_ image: CIImage, filter: CameraFilter) -> UIImage? {
        render(image, filter: filter).map { UIImage(cgImage: $0) }
    }
}
