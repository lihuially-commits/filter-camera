import Foundation
import AVFoundation
import CoreImage
import UIKit

/// 一次拍照的结果：原始文件数据（含 EXIF，用于原图保存）+ 已校正方向的 CIImage（用于滤镜处理）
struct CapturedPhoto: Identifiable {
    let id = UUID()
    let originalData: Data
    let image: CIImage
}

/// 相机管理：会话配置、实时视频帧（供滤镜预览）、拍照、权限
final class CameraManager: NSObject, ObservableObject {
    /// 实时预览帧（已旋转为竖屏方向），约 30fps 更新
    @Published var previewImage: CIImage?
    /// 拍到的照片，非 nil 时展示拍完预览页
    @Published var captured: CapturedPhoto?
    /// 相机权限被否时置 true，用于界面提示
    @Published var permissionDenied = false
    /// 当前变焦倍数，1 为默认广角
    @Published private(set) var zoomFactor: CGFloat = 1

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoQueue = DispatchQueue(label: "camera.video.queue")
    private var photoOutput: AVCapturePhotoOutput?
    private var videoDevice: AVCaptureDevice?
    private var maxZoomFactor: CGFloat = 5
    private var isConfigured = false

    // MARK: - 权限与启动

    func checkPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.configureAndStart()
                    } else {
                        self.permissionDenied = true
                    }
                }
            }
        default:
            DispatchQueue.main.async { self.permissionDenied = true }
        }
    }

    private func configureAndStart() {
        sessionQueue.async {
            if !self.isConfigured {
                self.configureSession()
            }
            if self.isConfigured && !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        // 后置广角镜头
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        videoDevice = device
        maxZoomFactor = min(device.maxAvailableVideoZoomFactor, 5)

        // 视频帧输出：驱动实时滤镜预览
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(videoOutput)
        // 注意：画面方向只在这里转一次，取帧时不要再手动旋转，否会变成横向
        Self.applyPortraitRotation(to: videoOutput.connection(with: .video))

        // 照片输出
        let photoOutput = AVCapturePhotoOutput()
        guard session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(photoOutput)
        self.photoOutput = photoOutput

        session.commitConfiguration()
        isConfigured = true
    }

    // MARK: - 变焦

    /// 设置变焦倍数（1 为原始广角），animated 时平滑过渡
    func setZoom(_ factor: CGFloat, animated: Bool = false) {
        sessionQueue.async {
            guard let device = self.videoDevice else { return }
            let clamped = min(max(factor, 1), self.maxZoomFactor)
            do {
                try device.lockForConfiguration()
                if animated {
                    device.ramp(toVideoZoomFactor: clamped, withRate: 12)
                } else {
                    device.videoZoomFactor = clamped
                }
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.zoomFactor = clamped
                }
            } catch {
                // 配置失败保持当前倍数
            }
        }
    }

    /// 把连接旋转到竖屏：iOS 17 起用 videoRotationAngle，旧系统退回 videoOrientation
    private static func applyPortraitRotation(to connection: AVCaptureConnection?) {
        guard let connection else { return }
        if #available(iOS 17.0, *), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        } else {
            connection.videoOrientation = .portrait
        }
    }

    // MARK: - 拍照

    func capturePhoto() {
        guard let photoOutput else { return }
        Self.applyPortraitRotation(to: photoOutput.connection(with: .video))
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    /// 重拍：清除已拍照片，回到取景界面
    func retake() {
        captured = nil
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var image = CIImage(cvPixelBuffer: buffer)
        // 兜底：若系统未按连接设置旋转（缓冲区仍是横向），手动补 90°
        if image.extent.width > image.extent.height {
            image = image.oriented(.right)
        }
        DispatchQueue.main.async {
            self.previewImage = image
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let uiImage = UIImage(data: data),
              // applyOrientationProperty 把 EXIF 方向烘进像素，得到竖直的 CIImage
              let ciImage = CIImage(image: uiImage, options: [.applyOrientationProperty: true]) else {
            return
        }
        DispatchQueue.main.async {
            self.captured = CapturedPhoto(originalData: data, image: ciImage)
        }
    }
}
