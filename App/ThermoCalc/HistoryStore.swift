import Foundation
import Observation

/// The list of past calculations, newest first, saved as JSON in Application Support.
@MainActor
@Observable
final class HistoryStore {
    private(set) var items: [Calculation] = []

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appending(path: "history.json")
        load()
    }

    func add(_ calculation: Calculation) {
        items.removeAll { $0.query == calculation.query && $0.substance == calculation.substance }
        items.insert(calculation, at: 0)
        save()
    }

    func remove(atOffsets offsets: IndexSet) {
        for index in offsets.sorted(by: >) { items.remove(at: index) }
        save()
    }

    func remove(_ calculation: Calculation) {
        items.removeAll { $0.id == calculation.id }
        save()
    }

    func removeAll() {
        items.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Calculation].self, from: data)
        else { return }
        items = decoded
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(items).write(to: fileURL, options: .atomic)
        } catch {
            print("Could not save history: \(error)")
        }
    }
}
