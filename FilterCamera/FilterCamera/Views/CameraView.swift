import SwiftUI
import CoreImage
import UIKit
import PhotosUI

/// 相机主界面：实时滤镜预览 + 滤镜横滑条 + 快门 + 滤镜管理入口
struct CameraView: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var store = FilterStore()
    @State private var selectedFilterID = CameraFilter.originalID
    @State private var showFilterList = false
    /// 捏合变焦的起始倍数，手势结束时回写
    @State private var baseZoom: CGFloat = 1
    /// 从系统相册选择的照片
    @State private var pickedPhoto: PhotosPickerItem?

    private var selectedFilter: CameraFilter {
        store.filters.first { $0.id == selectedFilterID } ?? .original
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            FilteredPreviewView(image: camera.previewImage, filter: selectedFilter)
                .ignoresSafeArea()
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            camera.setZoom(baseZoom * value)
                        }
                        .onEnded { _ in
                            baseZoom = camera.zoomFactor
                        }
                )
                .onTapGesture(count: 2) {
                    // 双击回到 1×
                    baseZoom = 1
                    camera.setZoom(1, animated: true)
                }

            VStack(spacing: 0) {
                // 顶部：滤镜管理入口
                HStack {
                    Spacer()
                    Button {
                        showFilterList = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .padding(.trailing)
                    .padding(.top, 8)
                }

                Spacer()

                // 变焦快捷档位：也可直接双指捏合
                HStack(spacing: 8) {
                    ForEach([CGFloat(1), 2, 3], id: \.self) { level in
                        let active = abs(camera.zoomFactor - level) < 0.15
                        Button {
                            baseZoom = level
                            camera.setZoom(level, animated: true)
                        } label: {
                            Text("\(Int(level))×")
                                .font(.caption)
                                .fontWeight(active ? .bold : .regular)
                                .foregroundColor(active ? .black : .white)
                                .frame(width: 34, height: 34)
                                .background(active ? Color.yellow : Color.black.opacity(0.45))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.bottom, 12)

                // 滤镜横滑条：点选即实时切换
                FilterStripView(filters: store.filters, selectedID: $selectedFilterID)
                    .padding(.bottom, 16)

                // 底部操作栏：相册入口 / 快门
                HStack {
                    PhotosPicker(selection: $pickedPhoto, matching: .images, photoLibrary: .shared()) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Button {
                        camera.capturePhoto()
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 4)
                                .frame(width: 72, height: 72)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 58, height: 58)
                        }
                    }

                    // 与左侧相册按钮等宽，保证快门居中
                    Color.clear.frame(width: 48, height: 48)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            if camera.permissionDenied {
                VStack(spacing: 12) {
                    Text("无法访问相机")
                        .font(.headline)
                    Text("请到 设置 > 滤镜相机 中开启相机权限")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(.white)
                .padding(24)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
            }
        }
        .onAppear { camera.checkPermissionAndStart() }
        .onDisappear { camera.stop() }
        .onChange(of: pickedPhoto) { item in
            loadPickedPhoto(item)
        }
        .sheet(isPresented: $showFilterList) {
            FilterListView(store: store, previewImage: camera.previewImage)
        }
        .fullScreenCover(item: $camera.captured) { captured in
            CapturePreviewView(
                captured: captured,
                initialFilterID: selectedFilterID,
                store: store,
                onClose: { camera.retake() }
            )
        }
    }

    /// 读取相册选中的照片，交给拍完预览页套滤镜
    private func loadPickedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            let uiImage = data.flatMap { UIImage(data: $0) }
            let ciImage = uiImage.flatMap {
                CIImage(image: $0, options: [.applyOrientationProperty: true])
            }
            await MainActor.run {
                if let data, let ciImage {
                    camera.captured = CapturedPhoto(originalData: data, image: ciImage, isFromLibrary: true)
                }
                pickedPhoto = nil
            }
        }
    }
}

/// 滤镜横滑选择条（相机界面与拍完预览页共用）
struct FilterStripView: View {
    let filters: [CameraFilter]
    @Binding var selectedID: UUID

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(filters) { filter in
                        let isSelected = filter.id == selectedID
                        Text(filter.name)
                            .font(.subheadline)
                            .fontWeight(isSelected ? .bold : .regular)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.white : Color.black.opacity(0.45))
                            .foregroundColor(isSelected ? .black : .white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().strokeBorder(Color.white.opacity(isSelected ? 0 : 0.5), lineWidth: 1)
                            )
                            .onTapGesture { selectedID = filter.id }
                            .id(filter.id)
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: selectedID) { id in
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .frame(height: 40)
    }
}
