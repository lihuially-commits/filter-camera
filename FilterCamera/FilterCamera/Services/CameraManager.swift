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

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoQueue = DispatchQueue(label: "camera.video.queue")
    private var photoOutput: AVCapturePhotoOutput?
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
        videoOutput.connection(with: .video)?.videoOrientation = .portrait

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

    // MARK: - 拍照

    func capturePhoto() {
        guard let photoOutput else { return }
        if let connection = photoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
        }
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
        // 后置摄像头竖屏显示需顺时针旋转 90°
        let image = CIImage(cvPixelBuffer: buffer).oriented(.right)
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
