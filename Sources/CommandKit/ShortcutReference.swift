/// A shortcuts reference (a help panel, a settings pane), generated from the app's groups and the bindings: one section
/// per group, one row per bound command with its keys in order (the menu's, then the triage keys) and its title as the
/// menu writes it. A view writes no list of its own.
public enum ShortcutReference<ID: CommandIdentifier> {
    public struct Row: Sendable, Hashable, Identifiable {
        public let id: String
        public let title: String
        /// Each key written as a menu writes it (« ⇧⌘R », « a », « Space »).
        public let keys: [String]
        /// The command; nil for a row that is not bindable (⌘1…⌘9 derived from the app's Spaces, Undo).
        public let command: ID?
        /// The key comes from the parent set: the chosen set does not document this command.
        public let isInherited: Bool
        /// The user changed this command's keys.
        public let isOverridden: Bool

        public init(
            id: String, title: String, keys: [String], command: ID? = nil, isInherited: Bool = false,
            isOverridden: Bool = false
        ) {
            self.id = id
            self.title = title
            self.keys = keys
            self.command = command
            self.isInherited = isInherited
            self.isOverridden = isOverridden
        }
    }

    public struct Section: Sendable, Hashable, Identifiable {
        public let id: String
        public let title: String
        public let rows: [Row]

        public init(id: String, title: String, rows: [Row]) {
            self.id = id
            self.title = title
            self.rows = rows
        }
    }

    /// One section of the reference: its commands in order, then the rows of keys that are not commands.
    public struct Group: Sendable, Hashable {
        public let id: String
        public let title: String
        public let commands: [ID]
        public let fixedRows: [Row]

        public init(id: String, title: String, commands: [ID], fixedRows: [Row] = []) {
            self.id = id
            self.title = title
            self.commands = commands
            self.fixedRows = fixedRows
        }
    }

    /// The reference panel: commands with at least one key, then each group's fixed rows.
    public static func sections(
        _ groups: [Group], bindings: ShortcutBindings<ID>, title: (ID) -> String
    ) -> [Section] {
        groups.map { group in
            Section(
                id: group.id, title: group.title,
                rows: group.commands.compactMap { row($0, bindings, title: title($0)) } + group.fixedRows)
        }
    }

    /// The settings pane: every command of the groups, with or without a key, and no fixed row.
    public static func editableSections(
        _ groups: [Group], bindings: ShortcutBindings<ID>, title: (ID) -> String
    ) -> [Section] {
        groups.map { group in
            Section(
                id: group.id, title: group.title,
                rows: group.commands.compactMap { row($0, bindings, title: title($0), includingUnbound: true) })
        }
    }

    /// The row of a command, nil without any key (unless `includingUnbound`).
    public static func row(
        _ command: ID, _ bindings: ShortcutBindings<ID>, title: String, includingUnbound: Bool = false
    ) -> Row? {
        let keys = bindings.keys(command)
        guard includingUnbound || !keys.isEmpty else { return nil }
        return Row(
            id: command.rawValue, title: title, keys: keys.map(\.symbols), command: command,
            isInherited: !keys.isEmpty && bindings.isInherited(command), isOverridden: bindings.isOverridden(command))
    }
}
