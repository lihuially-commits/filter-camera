import Foundation

/// 用户滤镜的增删改查与 JSON 持久化（存于 App Documents 目录）
final class FilterStore: ObservableObject {
    @Published private(set) var filters: [CameraFilter] = []

    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("filters.json")
        load()
    }

    // MARK: - 增删改

    func add(_ filter: CameraFilter) {
        filters.append(filter)
        save()
    }

    func update(_ filter: CameraFilter) {
        guard let index = filters.firstIndex(where: { $0.id == filter.id }) else { return }
        filters[index] = filter
        save()
    }

    func delete(id: UUID) {
        // 「原图」不可删除
        guard id != CameraFilter.originalID else { return }
        filters.removeAll { $0.id == id }
        save()
    }

    // MARK: - 持久化

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([CameraFilter].self, from: data) else {
            // 首次启动：内置「原图」+ 示例滤镜
            filters = [.original] + CameraFilter.samples
            save()
            return
        }
        // 确保「原图」永远在第一个
        var list = decoded.filter { $0.id != CameraFilter.originalID }
        list.insert(.original, at: 0)
        filters = list
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(filters) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
