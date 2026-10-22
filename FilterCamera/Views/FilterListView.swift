import SwiftUI
import CoreImage

/// 滤镜管理：列表 / 新建 / 编辑 / 删除
struct FilterListView: View {
    @ObservedObject var store: FilterStore
    /// 相机当前帧，用作编辑器的预览底图（没有则用内置示例图）
    var previewImage: CIImage?

    @Environment(\.dismiss) private var dismiss
    @State private var editingFilter: CameraFilter?
    @State private var creatingNew = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.filters) { filter in
                    HStack {
                        Text(filter.name)
                        Spacer()
                        if filter.isOriginal {
                            Text("内置")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // 「原图」不可编辑，其余点按进入编辑
                        if !filter.isOriginal {
                            editingFilter = filter
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let filter = store.filters[index]
                        if !filter.isOriginal {
                            store.delete(id: filter.id)
                        }
                    }
                }
            }
            .navigationTitle("滤镜管理")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        creatingNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editingFilter) { filter in
                FilterEditorView(store: store, filter: filter, isNew: false, previewImage: previewImage)
            }
            .sheet(isPresented: $creatingNew) {
                FilterEditorView(store: store, filter: CameraFilter(name: ""), isNew: true, previewImage: previewImage)
            }
        }
    }
}
