import Foundation

/// The user's shortcuts: a predefined set plus their own changes, command by command. Menus, triage tables, a palette,
/// buttons' help and a shortcuts reference all read their keys here. The app stores `data()` under its own key.
///
/// One command per key in the whole app: menu shortcuts work in every context, so a key is unique everywhere, not per
/// context. `record(_:for:rules:)` refuses a key that breaks that or the app's `BindingRules`.
public struct ShortcutBindings<ID: CommandIdentifier>: Sendable, Hashable {
    public private(set) var set: ShortcutSet<ID>
    /// The user's keys for a command, replacing the set's (first the menu's).
    public private(set) var overrides: [ID: [Shortcut]]

    public init(set: ShortcutSet<ID>, overrides: [ID: [Shortcut]] = [:]) {
        self.set = set
        self.overrides = overrides
    }

    // MARK: Reading

    /// Every key of `command`, the menu's first.
    public func keys(_ command: ID) -> [Shortcut] { overrides[command] ?? set.keys(for: command) }

    /// The menu item's shortcut: the first key that does not edit text (`Shortcut.editsText`). A menu key equivalent
    /// passes before the text field that has the focus, so ⌘⌫, ⌘↓ or ⌃E stay triage keys.
    public func shortcut(_ command: ID) -> Shortcut? {
        keys(command).first { !$0.editsText }
    }

    /// A button's help: `title`, then the shortcut as the menu shows it (« Archive (e) », « Reply (⌘R) »).
    public func helpText(title: String, for command: ID) -> String {
        guard let shortcut = shortcut(command) ?? keys(command).first else { return title }
        return "\(title) (\(shortcut.symbols))"
    }

    public func isOverridden(_ command: ID) -> Bool { overrides[command] != nil }

    /// The key comes from the parent set because the chosen set does not document this command.
    public func isInherited(_ command: ID) -> Bool { !isOverridden(command) && set.inherits(command) }

    /// The command `shortcut` is bound to, other than `command`.
    public func owner(of shortcut: Shortcut, other command: ID? = nil) -> ID? {
        ID.allCases.first { $0 != command && keys($0).contains(shortcut) }
    }

    /// Keys bound to several commands. A valid set and `record(_:for:rules:)` never produce any; stored overrides can,
    /// once a set changes under them. A triage table then keeps the first command of its list, and the settings show
    /// the conflict.
    public var conflicts: [ShortcutConflict<ID>] {
        var owners: [Shortcut: [ID]] = [:]
        for command in ID.allCases {
            for key in Set(keys(command)) { owners[key, default: []].append(command) }
        }
        return owners.filter { $0.value.count > 1 }
            .map { ShortcutConflict(shortcut: $0.key, commands: $0.value) }
            .sorted { $0.commands.lexicographicallyPrecedes($1.commands) { $0.rawValue < $1.rawValue } }
    }

    /// The shortcut belongs to a command of `rules.beforeFocusedView`: the window gives the key to the menu before the
    /// focused view (call it from `performKeyEquivalent`).
    public func takesKeyBeforeFocusedView(_ shortcut: Shortcut, rules: BindingRules<ID>) -> Bool {
        rules.beforeFocusedView.contains { self.shortcut($0) == shortcut }
    }

    // MARK: Changes

    /// Another set: the user's changes are dropped (they were made against the previous one).
    public mutating func choose(_ set: ShortcutSet<ID>) {
        self.set = set
        overrides = [:]
    }

    /// `shortcut` becomes the menu key of `command`; its other keys stay. Throws, changing nothing, when `rules` refuse
    /// it or another command has it.
    public mutating func record(
        _ shortcut: Shortcut, for command: ID, rules: BindingRules<ID>
    ) throws(ShortcutBindingError<ID>) {
        try rules.validate(shortcut, for: command)
        if let owner = owner(of: shortcut, other: command) { throw .taken(shortcut, by: owner) }
        let current = keys(command)
        let keys = [shortcut] + current.dropFirst().filter { $0 != shortcut }
        overrides[command] = keys == set.keys(for: command) ? nil : keys
    }

    /// The set's keys again for `command`.
    public mutating func reset(_ command: ID) {
        overrides[command] = nil
    }

    /// The set as delivered: every change dropped.
    public mutating func resetAll() {
        overrides = [:]
    }

    // MARK: Storage

    /// Stored data, `{ "base": "<set id>", "overrides": { "<command>": ["<notation>"] } }`; nil gives `standard`.
    /// Unreadable data (not JSON, a set that is not in `sets`) throws. An override the app no longer understands (a
    /// command renamed, a key written another way) is left out and named in `ignored`, the others are kept: one bad
    /// entry does not cost the user every change.
    public static func read(
        _ data: Data?, sets: [ShortcutSet<ID>], standard: Self
    ) throws -> (bindings: Self, ignored: [String]) {
        guard let data else { return (standard, []) }
        let stored = try JSONDecoder().decode(Stored.self, from: data)
        guard let set = sets.first(where: { $0.id == stored.base }) else {
            throw ShortcutBindingsReadError.unknownSet(stored.base)
        }
        var overrides: [ID: [Shortcut]] = [:]
        var ignored: [String] = []
        for (name, notations) in stored.overrides.sorted(by: { $0.key < $1.key }) {
            let keys = notations.compactMap(Shortcut.init(notation:))
            guard let command = ID(rawValue: name), keys.count == notations.count else {
                ignored.append("\(name): \(notations.joined(separator: " "))")
                continue
            }
            overrides[command] = keys
        }
        return (Self(set: set, overrides: overrides), ignored)
    }

    public func data() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(
            Stored(
                base: set.id,
                overrides: Dictionary(uniqueKeysWithValues: overrides.map { ($0.key.rawValue, $0.value.map(\.notation)) })))
    }

    private struct Stored: Codable {
        let base: String
        let overrides: [String: [String]]
    }
}

public enum ShortcutBindingsReadError: Error, Sendable, Hashable {
    /// The stored bindings name a set the app does not have.
    case unknownSet(String)
}

/// One key bound to several commands.
public struct ShortcutConflict<ID: CommandIdentifier>: Sendable, Hashable {
    public let shortcut: Shortcut
    public let commands: [ID]

    public init(shortcut: Shortcut, commands: [ID]) {
        self.shortcut = shortcut
        self.commands = commands
    }
}

/// Why a key cannot be recorded; `message(appName:title:)` says it to the user.
public enum ShortcutBindingError<ID: CommandIdentifier>: Error, Sendable, Hashable {
    case notRebindable(ID)
    case reserved(Shortcut)
    case typesText(Shortcut)
    case editsText(Shortcut)
    case taken(Shortcut, by: ID)
    /// The recorder read no key: a dead key (´ waiting for its letter) or one that composes several characters.
    case notAKey

    /// The sentence for the user. `appName` is who reserves keys besides macOS; `title` gives a command's title.
    public func message(appName: String, title: (ID) -> String) -> String {
        switch self {
        case .notRebindable(let command):
            localized("“\(title(command))” keeps the system's shortcut.")
        case .reserved(let shortcut):
            localized("\(shortcut.symbols) is reserved by macOS or \(appName).")
        case .typesText(let shortcut):
            localized("\(shortcut.symbols) would type text: add ⌘ or ⌃.")
        case .editsText(let shortcut):
            localized("\(shortcut.symbols) edits the text of a field: it can only be a triage key.")
        case .taken(let shortcut, let command):
            localized("\(shortcut.symbols) is already used by “\(title(command))”.")
        case .notAKey:
            localized("This key doesn't make a shortcut (dead or composed key): try another one.")
        }
    }
}
