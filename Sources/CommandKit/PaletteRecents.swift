import Foundation

/// Entries chosen recently, the most recent first. The app stores `data()` (JSON) under its own key.
public struct PaletteRecents: Sendable, Equatable, Codable {
    public private(set) var ids: [String]

    public static let capacity = 8

    public init(ids: [String] = []) {
        self.ids = Array(ids.prefix(Self.capacity))
    }

    /// Stored data; `nil` gives an empty list, unreadable data throws.
    public init(data: Data?) throws {
        guard let data else {
            self.init()
            return
        }
        self = try JSONDecoder().decode(Self.self, from: data)
    }

    public func data() throws -> Data { try JSONEncoder().encode(self) }

    /// `id` first, without duplicates, at most `capacity`.
    public func recording(_ id: String) -> PaletteRecents {
        PaletteRecents(ids: [id] + ids.filter { $0 != id })
    }
}
