#if canImport(AppKit)
import AppKit
import CommandKit

extension Shortcut {
    /// The shortcut a key press stands for (`init(characters:baseCharacters:modifiers:)`), for a triage table and a
    /// shortcut recorder alike; nil for a dead key or a key that composes several characters.
    public init?(event: NSEvent) {
        self.init(
            characters: event.characters ?? "", baseCharacters: event.characters(byApplyingModifiers: []),
            modifiers: Self.modifiers(event.modifierFlags))
    }

    /// The modifiers of `flags` that a shortcut keeps (Caps Lock, Fn and the numeric pad are not modifiers here).
    public static func modifiers(_ flags: NSEvent.ModifierFlags) -> Set<Modifier> {
        let flags = flags.intersection(.deviceIndependentFlagsMask)
        var modifiers: Set<Modifier> = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        return modifiers
    }

    /// The flags of an `NSMenuItem` or a synthesized key event with this shortcut's modifiers.
    public var modifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains(.command) { flags.insert(.command) }
        if modifiers.contains(.shift) { flags.insert(.shift) }
        if modifiers.contains(.option) { flags.insert(.option) }
        if modifiers.contains(.control) { flags.insert(.control) }
        return flags
    }
}
#endif
