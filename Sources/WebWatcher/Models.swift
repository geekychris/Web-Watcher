import Foundation

struct HistoryItem: Codable, Identifiable {
    var id: UUID = UUID()
    let timestamp: Date
    let content: String
}

struct WatcherItem: Codable, Identifiable {
    var id: UUID = UUID()
    var url: String
    var selector: String
    var intervalMinutes: Int
    var lastFetch: Date?
    var lastContent: String?
    var history: [HistoryItem] = []
}

class Store: ObservableObject {
    @Published var items: [WatcherItem] = [] {
        didSet {
            save()
        }
    }
    
    private let fileURL: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("WebWatcher", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        fileURL = dir.appendingPathComponent("watcher_data.json")
        load()
    }
    
    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([WatcherItem].self, from: data) {
            self.items = decoded
        }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(items) {
            try? encoded.write(to: fileURL)
        }
    }
    
    func add(item: WatcherItem) {
        items.append(item)
    }
    
    func delete(id: UUID) {
        items.removeAll { $0.id == id }
    }
    
    func update(item: WatcherItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
    }
}
