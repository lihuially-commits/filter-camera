import SwiftUI
import Photos
import CoreImage
import UIKit
import UniformTypeIdentifiers

/// 拍完预览页：查看照片、点选滤镜实时切换、保存（原图 + 滤镜图）、重拍
struct CapturePreviewView: View {
    let captured: CapturedPhoto
    let initialFilterID: UUID
    @ObservedObject var store: FilterStore
    var onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilterID: UUID
    @State private var rendered: UIImage?
    @State private var saving = false
    @State private var showSavedToast = false
    @State private var saveError: String?

    init(captured: CapturedPhoto, initialFilterID: UUID, store: FilterStore, onClose: @escaping () -> Void) {
        self.captured = captured
        self.initialFilterID = initialFilterID
        self.store = store
        self.onClose = onClose
        _selectedFilterID = State(initialValue: initialFilterID)
    }

    private var selectedFilter: CameraFilter {
        store.filters.first { $0.id == selectedFilterID } ?? .original
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let rendered {
                Image(uiImage: rendered)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
            }

            VStack(spacing: 0) {
                // 顶部：重拍 / 保存
                HStack {
                    Button {
                        close()
                    } label: {
                        Label(captured.isFromLibrary ? "返回" : "重拍",
                              systemImage: captured.isFromLibrary ? "chevron.left" : "arrow.counterclockwise")
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Button {
                        save()
                    } label: {
                        Label(saving ? "保存中…" : "保存", systemImage: "square.and.arrow.down")
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .disabled(saving || rendered == nil)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                FilterStripView(filters: store.filters, selectedID: $selectedFilterID)
                    .padding(.bottom, 24)
            }

            if showSavedToast {
                Text(captured.isFromLibrary ? "已保存滤镜照片" : "已保存原图和滤镜照片")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
            }
        }
        .onAppear { render() }
        .onChange(of: selectedFilterID) { _ in render() }
        .alert("保存失败", isPresented: .constant(saveError != nil)) {
            Button("好的") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private func close() {
        dismiss()
        onClose()
    }

    private func render() {
        let image = captured.image
        let filter = selectedFilter
        Task.detached(priority: .userInitiated) {
            let ui = FilterRenderer.shared.renderUIImage(image, filter: filter)
            await MainActor.run {
                self.rendered = ui
            }
        }
    }

    private func save() {
        guard let rendered else { return }
        saving = true
        Task {
            do {
                try await PhotoSaver.save(originalData: captured.isFromLibrary ? nil : captured.originalData,
                                          filtered: rendered)
                await MainActor.run {
                    saving = false
                    showSavedToast = true
                }
                try await Task.sleep(nanoseconds: 800_000_000)
                await MainActor.run { close() }
            } catch {
                await MainActor.run {
                    saving = false
                    saveError = error.localizedDescription
                }
            }
        }
    }
}

/// 保存照片到系统相册：原图（含 EXIF 的原始数据）+ 滤镜图
enum PhotoSaver {
    enum SaveError: LocalizedError {
        case noPermission

        var errorDescription: String? {
            switch self {
            case .noPermission:
                return "没有相册写入权限，请到 设置 > 滤镜相机 中允许访问相册"
            }
        }
    }

    /// originalData 为 nil 时只写入滤镜图（相册导入的照片不重复保存原图）
    static func save(originalData: Data?, filtered: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw SaveError.noPermission
        }

        let filteredData = filtered.jpegData(compressionQuality: 0.92)
        try await PHPhotoLibrary.shared().performChanges {
            // 原图：保留原始 EXIF
            if let originalData {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: originalData, options: nil)
            }
            // 滤镜图
            if let filteredData {
                let options = PHAssetResourceCreationOptions()
                options.uniformTypeIdentifier = UTType.jpeg.identifier
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: filteredData, options: options)
            }
        }
    }
}
