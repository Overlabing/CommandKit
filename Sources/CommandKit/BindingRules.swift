/// The rules a recorded key must follow, given by the app: which commands keep their keys, which keys nobody takes,
/// which commands are used while typing, which are read by the triage. Rules that do not depend on the other commands;
/// a key already bound elsewhere is refused by `ShortcutBindings.record(_:for:rules:)`.
public struct BindingRules<ID: CommandIdentifier>: Sendable, Hashable {
    /// Commands whose keys never change (a system menu item the app stands in for).
    public var fixed: Set<ID>
    /// Keys no command may take: the system menus, keys the app derives (⌘1…⌘9 for its Spaces), keys a list moves with.
    /// Escape and Tab, whatever their modifiers, are always reserved: Escape cancels a recorder, Tab moves the focus.
    public var reserved: Set<Shortcut>
    /// Keys only one command may take (⌘↩ for Send).
    public var exclusive: [Shortcut: ID]
    /// Commands used while typing (formatting, sending): the text view would take a key that types text, so theirs
    /// needs ⌘ or ⌃.
    public var usedWhileTyping: Set<ID>
    /// Commands whose keys a triage table reads outside text input: only they may take a key that edits text
    /// (`Shortcut.editsText`), since such a key never becomes a menu shortcut.
    public var triage: Set<ID>
    /// Commands whose shortcut reaches the menu before the focused view, even a web page that handles the key itself
    /// (`ShortcutBindings.takesKeyBeforeFocusedView`).
    public var beforeFocusedView: Set<ID>

    public init(
        fixed: Set<ID> = [], reserved: Set<Shortcut> = [], exclusive: [Shortcut: ID] = [:], usedWhileTyping: Set<ID> = [],
        triage: Set<ID> = [], beforeFocusedView: Set<ID> = []
    ) {
        self.fixed = fixed
        self.reserved = reserved
        self.exclusive = exclusive
        self.usedWhileTyping = usedWhileTyping
        self.triage = triage
        self.beforeFocusedView = beforeFocusedView
    }

    public func isRebindable(_ command: ID) -> Bool { !fixed.contains(command) }

    public func isReserved(_ shortcut: Shortcut, for command: ID) -> Bool {
        if reserved.contains(shortcut) { return true }
        if let owner = exclusive[shortcut] { return owner != command }
        return [Shortcut.escape, Shortcut.tab].contains(shortcut.key)
    }

    /// Throws, in this order, when `command` keeps its keys, the key is reserved, it types text on a command used while
    /// typing, or it edits text on a command the triage does not read.
    public func validate(_ shortcut: Shortcut, for command: ID) throws(ShortcutBindingError<ID>) {
        guard isRebindable(command) else { throw .notRebindable(command) }
        if isReserved(shortcut, for: command) { throw .reserved(shortcut) }
        if usedWhileTyping.contains(command), shortcut.isTyping { throw .typesText(shortcut) }
        if shortcut.editsText, !triage.contains(command) { throw .editsText(shortcut) }
    }
}
