import Foundation

/// A predefined set of shortcuts, usually read from a data file: the keys an app documents for each command, the first
/// being the menu's, the others aliases a triage table also reads. A command the set does not bind inherits the parent
/// set's keys, minus any key the set already gives to another command. Never edited at run time: the user's changes
/// are `ShortcutBindings` overrides.
public struct ShortcutSet<ID: CommandIdentifier>: Sendable, Hashable, Identifiable {
    /// One key of a command, with where it comes from.
    public struct Binding: Sendable, Hashable {
        public let shortcut: Shortcut
        /// The action's name on the cited source, or why the key was chosen; nil when the file says nothing.
        public let from: String?

        public init(_ shortcut: Shortcut, from: String? = nil) {
            self.shortcut = shortcut
            self.from = from
        }
    }

    /// The set's name in files and in stored bindings.
    public let id: String
    /// The official page the keys were read from; nil for an app's own set.
    public let source: URL?
    /// When the source was read (ISO date).
    public let checked: String?
    /// A remark on the whole set (how the source was read, what to re-check).
    public let note: String?
    /// The keys this set defines itself, first the menu's.
    public let own: [ID: [Binding]]
    /// Commands the source was checked for and does not document, with the reason when the file gives one. They
    /// inherit, and a reference says so.
    public let notFound: [ID: String?]
    /// Every command's keys once inheritance is applied.
    public let keys: [ID: [Shortcut]]

    public init(
        id: String, source: URL? = nil, checked: String? = nil, note: String? = nil, own: [ID: [Binding]],
        notFound: [ID: String?] = [:], inheritingFrom parent: ShortcutSet?
    ) {
        self.id = id
        self.source = source
        self.checked = checked
        self.note = note
        self.own = own
        self.notFound = notFound
        var keys = own.mapValues { $0.map(\.shortcut) }
        if let parent {
            let taken = Set(keys.values.joined())
            for (command, inherited) in parent.keys where keys[command] == nil {
                keys[command] = inherited.filter { !taken.contains($0) }
            }
        }
        self.keys = keys
    }

    /// The keys of `command`, first the menu's; empty when the command has none.
    public func keys(for command: ID) -> [Shortcut] { keys[command] ?? [] }

    /// The source was checked for `command` and has no key for it: its keys come from the parent set. Commands only the
    /// app has inherit without being listed, and without the mention.
    public func inherits(_ command: ID) -> Bool { notFound.keys.contains(command) }

    /// Reads a data file and checks it is the set `id`:
    ///
    ///     { "id": "…", "source": "https://…", "checked": "2026-10-27", "note": "…",
    ///       "shortcuts": { "<command>": ["⌘R", { "shortcut": "r", "from": "Reply (R)" }] },
    ///       "notFound": ["<command>"] }
    ///
    /// A key is its notation, or an object with the notation and its `from`. `notFound` is a list of commands, or an
    /// object mapping each command to its reason. Every field but `id` and `shortcuts` is optional.
    public init(data: Data, expecting id: String, inheritingFrom parent: ShortcutSet?) throws {
        let file = try JSONDecoder().decode(File.self, from: data)
        guard file.id == id else { throw ShortcutSetError.mismatchedID(expected: id, found: file.id) }
        var own: [ID: [Binding]] = [:]
        for (name, entries) in file.shortcuts {
            own[try Self.command(name)] = try entries.map { entry in
                guard let shortcut = Shortcut(notation: entry.shortcut) else {
                    throw ShortcutSetError.invalidNotation(entry.shortcut)
                }
                return Binding(shortcut, from: entry.from)
            }
        }
        var notFound: [ID: String?] = [:]
        for (name, reason) in file.notFound?.reasons ?? [] {
            notFound[try Self.command(name)] = .some(reason)
        }
        self.init(
            id: id, source: file.source.flatMap(URL.init(string:)), checked: file.checked, note: file.note, own: own,
            notFound: notFound, inheritingFrom: parent)
    }

    private static func command(_ name: String) throws -> ID {
        guard let command = ID(rawValue: name) else { throw ShortcutSetError.unknownCommand(name) }
        return command
    }

    private struct File: Decodable {
        let id: String
        let source: String?
        let checked: String?
        let note: String?
        let shortcuts: [String: [Entry]]
        let notFound: NotFound?
    }

    private struct Entry: Decodable {
        let shortcut: String
        let from: String?

        init(from decoder: any Decoder) throws {
            if let notation = try? decoder.singleValueContainer().decode(String.self) {
                shortcut = notation
                from = nil
                return
            }
            let container = try decoder.container(keyedBy: Keys.self)
            shortcut = try container.decode(String.self, forKey: .shortcut)
            from = try container.decodeIfPresent(String.self, forKey: .from)
        }

        private enum Keys: String, CodingKey { case shortcut, from }
    }

    /// `["command"]` or `{ "command": "reason" }`.
    private struct NotFound: Decodable {
        let reasons: [(String, String?)]

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let names = try? container.decode([String].self) {
                reasons = names.map { ($0, nil) }
            } else {
                reasons = try container.decode([String: String].self).sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
            }
        }
    }
}

public enum ShortcutSetError: Error, Sendable, Hashable {
    case mismatchedID(expected: String, found: String)
    case unknownCommand(String)
    case invalidNotation(String)
}
