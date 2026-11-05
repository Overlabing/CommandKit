/// A keyboard shortcut, as data: one key and its modifiers.
public struct Shortcut: Sendable, Hashable {
    public enum Modifier: Sendable, Hashable, CaseIterable {
        case command, shift, option, control
    }

    public let key: Character
    public let modifiers: Set<Modifier>

    /// The arrow keys, with the characters AppKit gives them (`NSDownArrowFunctionKey`, `NSUpArrowFunctionKey`), those of
    /// `KeyEquivalent.downArrow` and `.upArrow`.
    public static let downArrow: Character = "\u{F701}"
    public static let upArrow: Character = "\u{F700}"
    /// `NSLeftArrowFunctionKey`, `NSRightArrowFunctionKey` (`KeyEquivalent.leftArrow`, `.rightArrow`).
    public static let leftArrow: Character = "\u{F702}"
    public static let rightArrow: Character = "\u{F703}"
    /// Space and Return (`KeyEquivalent.space`, `.return`).
    public static let space: Character = " "
    public static let returnKey: Character = "\r"
    /// The Delete (backspace) key, as AppKit reports it (`NSDeleteCharacter`, `KeyEquivalent.delete`).
    public static let delete: Character = "\u{7F}"
    /// The forward delete key, ⌦ (`NSDeleteFunctionKey`, `KeyEquivalent.deleteForward`).
    public static let forwardDelete: Character = "\u{F728}"
    /// Escape (`KeyEquivalent.escape`): cancels a shortcut recorder, never bound.
    public static let escape: Character = "\u{1B}"
    /// Tab (`KeyEquivalent.tab`): moves the keyboard focus, never bound.
    public static let tab: Character = "\t"

    /// Keys that keep their modifiers as typed (⇧Space, ⌘↓, ⌘⌫), unlike a printable character that carries Shift.
    static let specialKeys: Set<Character> = [space, returnKey, upArrow, downArrow, leftArrow, rightArrow, delete, forwardDelete, escape, tab]

    public init(_ key: Character, _ modifiers: Set<Modifier> = [.command]) {
        self.key = key
        self.modifiers = modifiers
    }

    /// The shortcut a key press stands for, from what AppKit reports: `characters` (modifiers applied), `baseCharacters`
    /// (`characters(byApplyingModifiers: [])`, the key with no modifier) and the modifiers held. `nil` for a dead key or
    /// several characters. One rule for key triage and for a shortcut recorder:
    /// - Space, ↩, ⌫ and the arrows keep their modifiers (⇧Space, ⌘↓, ⌘⌫).
    /// - With ⌘ or ⌃, the key is the unmodified one and every modifier is kept (⇧⌘R, ⇧⌘7, ⌃]).
    /// - Otherwise a printable character already carries Shift and Option (`#` comes from ⇧3, or ⌥⇧ on some layouts):
    ///   they are dropped; without Shift the letter is lowercased (Caps Lock). ⇧I is the key « I » with no modifier.
    public init?(characters: String, baseCharacters: String? = nil, modifiers: Set<Modifier>) {
        guard characters.count == 1, let character = characters.first else { return nil }
        if Self.specialKeys.contains(character) {
            self.init(character, modifiers)
        } else if !modifiers.isDisjoint(with: [.command, .control]) {
            let base = baseCharacters.flatMap { $0.count == 1 ? $0.first : nil } ?? character
            self.init(Character(base.lowercased()), modifiers)
        } else {
            let key = modifiers.contains(.shift) ? character : Character(character.lowercased())
            self.init(key, [])
        }
    }

    /// The shortcut written as a macOS menu writes it: modifiers in the order ⌃⌥⇧⌘, then the key, a capital under a
    /// modifier (« ⇧⌘R »), as is alone (« e », « # »). A bare capital letter is typed with Shift: « ⇧I ».
    public var symbols: String {
        let prefix = Self.modifierSymbols(modifiers)
        switch key {
        case Self.space: return prefix + localized("Space")
        default:
            if let name = Self.keyNames[key] { return prefix + name }
            if prefix.isEmpty, Self.isUppercaseLetter(key) { return "⇧" + String(key) }
            return prefix + (prefix.isEmpty ? String(key) : String(key).uppercased())
        }
    }

    /// The shortcut as written in a shortcut set file and in stored bindings: the menu symbols, with « Space » for the
    /// space bar so the notation does not depend on the language.
    public var notation: String {
        key == Self.space ? Self.modifierSymbols(modifiers) + "Space" : symbols
    }

    /// Reads `notation`: modifiers ⌃⌥⇧⌘ then one key (a character, ↑ ↓ ← → ↩ ⌫ ⌦ or « Space »). A capital letter under ⌘
    /// or ⌃ is its lowercase key (« ⇧⌘R »); a bare « ⇧I » is the key « I » (see `init(characters:)`). `nil` for
    /// anything else, including Shift or Option on a bare non-letter character (« ⇧3 » is written « # »).
    public init?(notation: String) {
        var modifiers: Set<Modifier> = []
        var rest = Substring(notation)
        while let first = rest.first, let modifier = Self.modifierBySymbol[first] {
            guard modifiers.insert(modifier).inserted else { return nil }
            rest = rest.dropFirst()
        }
        let key: Character
        if rest == "Space" {
            key = Self.space
        } else if rest.count == 1, let character = rest.first {
            key = Self.keyNames.first { $0.value == String(character) }?.key ?? character
        } else {
            return nil
        }
        if Self.specialKeys.contains(key) {
            self.init(key, modifiers)
        } else if !modifiers.isDisjoint(with: [.command, .control]) {
            self.init(Character(key.lowercased()), modifiers)
        } else if modifiers.isEmpty, !Self.isUppercaseLetter(key) {
            self.init(key, [])
        } else if modifiers == [.shift], Self.isLetter(key) {
            self.init(Character(key.uppercased()), [])
        } else {
            return nil
        }
    }

    /// No ⌘ nor ⌃: the key types text in a field (a letter, ⇧I, #, Space, ⌫).
    public var isTyping: Bool { modifiers.isDisjoint(with: [.command, .control]) }

    /// A key the Cocoa text system binds to a text edit or move, so that a menu item with it would act from a search
    /// field or a sheet (a menu key equivalent passes before the field that has the focus). Read from
    /// `StandardKeyBinding.dict` (AppKit.framework/Resources):
    /// - ⌫ and ⌦ alone, with ⇧, ⌥ or ⌃ (deleteBackward:, deleteWordBackward:, deleteWordForward:…), and with ⌘ alone
    ///   (⌘⌫ is deleteToBeginningOfLine:; ⌘⌦ is not in the dictionary and is treated alike). ⌘ with another modifier is
    ///   not a text key: ⇧⌘⌫ (Empty Trash, Clear History) and ⌥⌘⌫ (Delete Immediately) are menu keys.
    /// - ⌘ with an arrow, with or without ⇧ (moveToLeftEndOfLine:, moveToBeginningOfDocument: and their selecting
    ///   forms). Adding ⌃ or ⌥ makes a menu key: ⌃⌘← and ⌃⌘→ (Show Previous and Next Space), ⌥⌘←.
    ///   ⌥ with an arrow (moveWordLeft:, ⌥↓ moves to the paragraph's end) is bound by the text system too but is not
    ///   counted here, as in 0.1.0 to 0.1.2: apps use ⌥↑ and ⌥↓ as menu keys for the previous and next message.
    /// - The Emacs keys: ⌃ and a letter of the text system (⌃A, ⌃E, ⌃K…), with ⇧ or not.
    /// Such a key is never a menu shortcut (`ShortcutBindings.shortcut`), only a triage key, read outside text input.
    public var editsText: Bool {
        if key == Self.delete || key == Self.forwardDelete {
            return !modifiers.contains(.command) || modifiers == [.command]
        }
        if [Self.leftArrow, Self.rightArrow, Self.upArrow, Self.downArrow].contains(key) {
            return modifiers.contains(.command) && modifiers.isSubset(of: [.command, .shift])
        }
        if modifiers.contains(.control), modifiers.isSubset(of: [.control, .shift]) {
            return Self.textControlKeys.contains(Character(key.lowercased()))
        }
        return false
    }

    /// ⌃ letters bound by the Cocoa text system: line start / end, character and line moves, kill and yank, delete,
    /// transpose, open line, centre.
    private static let textControlKeys: Set<Character> = ["a", "b", "d", "e", "f", "h", "k", "l", "n", "o", "p", "t", "v", "y"]

    private static func modifierSymbols(_ modifiers: Set<Modifier>) -> String {
        let order: [(Modifier, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        return order.filter { modifiers.contains($0.0) }.map(\.1).joined()
    }

    private static let modifierBySymbol: [Character: Modifier] = ["⌃": .control, "⌥": .option, "⇧": .shift, "⌘": .command]

    private static let keyNames: [Character: String] = [
        downArrow: "↓", upArrow: "↑", leftArrow: "←", rightArrow: "→", returnKey: "↩", delete: "⌫", forwardDelete: "⌦", escape: "⎋",
        tab: "⇥",
    ]

    private static func isLetter(_ key: Character) -> Bool { key.isLetter && key.lowercased() != key.uppercased() }

    private static func isUppercaseLetter(_ key: Character) -> Bool { isLetter(key) && key.isUppercase }
}

extension Shortcut: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let notation = try container.decode(String.self)
        guard let shortcut = Shortcut(notation: notation) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unreadable shortcut: \(notation)")
        }
        self = shortcut
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(notation)
    }
}
