/// Key triage: a key typed where the focus is gives a command or nothing. One lookup for every key the triage reads,
/// built once per change of the bindings. The app passes each key press of its window through it and performs the
/// command the same way as its menu item.
///
/// `Focus` is the app's own description of where the keyboard focus is (a list, a page, a text field…). A focus missing
/// from `accepted` triages nothing: text input keeps its keys.
public struct TriageTable<ID: CommandIdentifier, Focus: Hashable & Sendable>: Sendable, Hashable {
    /// Every key of the triage commands, the menu's included, and its command.
    public let commands: [Shortcut: ID]
    /// The commands each focus performs.
    public let accepted: [Focus: Set<ID>]

    /// `commands` in priority order: a key bound twice (stored overrides against a changed set,
    /// `ShortcutBindings.conflicts`) goes to the first, a user error shown in the settings, never a crash.
    public init(_ bindings: ShortcutBindings<ID>, commands: [ID], accepted: [Focus: Set<ID>]) {
        var table: [Shortcut: ID] = [:]
        for command in commands {
            for key in bindings.keys(command) where table[key] == nil {
                table[key] = command
            }
        }
        self.commands = table
        self.accepted = accepted
    }

    /// The command of `shortcut` typed in `focus`, nil when the press is not the triage's.
    public func command(for shortcut: Shortcut, in focus: Focus) -> ID? {
        guard let command = commands[shortcut], accepted[focus]?.contains(command) == true else { return nil }
        return command
    }
}
