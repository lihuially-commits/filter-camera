import SwiftUI
import CoreImage

/// 相机主界面：实时滤镜预览 + 滤镜横滑条 + 快门 + 滤镜管理入口
struct CameraView: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var store = FilterStore()
    @State private var selectedFilterID = CameraFilter.originalID
    @State private var showFilterList = false

    private var selectedFilter: CameraFilter {
        store.filters.first { $0.id == selectedFilterID } ?? .original
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            FilteredPreviewView(image: camera.previewImage, filter: selectedFilter)
                .ignoresSafeArea()

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

                // 滤镜横滑条：点选即实时切换
                FilterStripView(filters: store.filters, selectedID: $selectedFilterID)
                    .padding(.bottom, 16)

                // 快门
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
