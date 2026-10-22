import SwiftUI
import MetalKit
import CoreImage

/// 实时滤镜预览：把相机帧经滤镜链渲染到 MTKView（GPU，满帧率）
struct FilteredPreviewView: UIViewRepresentable {
    var image: CIImage?
    var filter: CameraFilter

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: FilterRenderer.shared.device)
        view.delegate = context.coordinator
        view.backgroundColor = .black
        // 手动驱动刷新：有新帧时才 draw
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.framebufferOnly = false
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.image = image
        context.coordinator.filter = filter
        uiView.setNeedsDisplay()
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        var image: CIImage?
        var filter: CameraFilter = .original

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let image,
                  let drawable = view.currentDrawable,
                  let commandBuffer = FilterRenderer.shared.commandQueue?.makeCommandBuffer() else { return }

            let filtered = filter.apply(to: image)
            let extent = filtered.extent
            guard extent.width > 0, extent.height > 0 else { return }

            // 等比放大到铺满（aspect fill），居中裁剪
            let drawSize = view.drawableSize
            let scale = max(drawSize.width / extent.width, drawSize.height / extent.height)
            var transform = CGAffineTransform(translationX: -extent.origin.x, y: -extent.origin.y)
            transform = transform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
            let scaled = filtered.transformed(by: transform)

            let xOffset = (extent.width * scale - drawSize.width) / 2
            let yOffset = (extent.height * scale - drawSize.height) / 2
            let fromRect = CGRect(x: xOffset, y: yOffset, width: drawSize.width, height: drawSize.height)

            let destination = CIRenderDestination(mtlTexture: drawable.texture, commandBuffer: commandBuffer)
            destination.isFlipped = true
            do {
                _ = try FilterRenderer.shared.context.startTask(toRender: scaled, from: fromRect, to: destination, at: .zero)
                commandBuffer.present(drawable)
                commandBuffer.commit()
            } catch {
                // 单帧渲染失败直接丢弃，等下一帧
            }
        }
    }
}
