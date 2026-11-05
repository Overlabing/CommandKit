import CommandKit
import Foundation

/// The commands of the test app, in registry order.
enum Command: String, CommandIdentifier {
    case newMessage, reply, replyAll, forward, send, bold, archive, trash, snooze, pin, toggleRead
    case next, previous, first, last, open, pageDown, pageUp, find
    case endDay, nextSpace, palette, settings, close, draftOnly
}

func key(_ character: Character, _ modifiers: Set<Shortcut.Modifier> = []) -> Shortcut {
    Shortcut(character, modifiers)
}

func set(_ json: String, _ id: String, inheritingFrom parent: ShortcutSet<Command>?) -> ShortcutSet<Command> {
    do {
        return try ShortcutSet(data: Data(json.utf8), expecting: id, inheritingFrom: parent)
    } catch {
        preconditionFailure("fixture \(id): \(error)")
    }
}

enum Sets {
    /// The app's own set: every command it has a key for.
    static let standard = set(
        #"""
        {
          "id": "standard",
          "shortcuts": {
            "newMessage": ["⌘N"], "reply": ["⌘R", "r"], "replyAll": ["⇧⌘R", "a"], "forward": ["⇧⌘F", "f"],
            "send": ["⇧⌘D"], "bold": ["⌘B"], "archive": ["e", "⌫"], "trash": ["#", "⌘⌫"], "snooze": ["s"],
            "pin": ["p"], "toggleRead": ["⇧⌘U", "u"], "next": ["j"], "previous": ["k"], "first": ["⌘↑"],
            "last": ["⌘↓"], "open": ["o", "↩"], "pageDown": ["Space"], "pageUp": ["⇧Space"], "find": ["⌘F", "/"],
            "endDay": ["⌥⌘E"], "nextSpace": ["⌥⌘→"], "palette": ["⌘K"], "settings": ["⌘,"], "close": ["⌘W"]
          }
        }
        """#, "standard", inheritingFrom: nil)

    /// Documents a few commands with ⌘, the others are checked and absent.
    static let menus = set(
        #"""
        {
          "id": "menus",
          "source": "https://example.com/menus/shortcuts",
          "checked": "2026-10-27",
          "note": "Read from the vendor's page.",
          "shortcuts": {
            "newMessage": ["⌘N"], "reply": ["⌘R"],
            "replyAll": [{ "shortcut": "⇧⌘R", "from": "Reply All (⇧⌘R)" }],
            "forward": ["⇧⌘F"], "send": ["⇧⌘D"], "archive": [{ "shortcut": "⌃⌘A", "from": "Archive (⌃⌘A)" }],
            "toggleRead": ["⇧⌘U"]
          },
          "notFound": {
            "trash": "Delete has no key on the page.", "snooze": "No snooze.", "pin": "No pin.", "next": "Arrows only.",
            "previous": "Arrows only.", "first": "Arrows only.", "last": "Arrows only.", "open": "Return only.",
            "pageDown": "No page keys.", "pageUp": "No page keys.", "find": "No find key."
          }
        }
        """#, "menus", inheritingFrom: standard)

    /// Control keys, some of which edit text in a field.
    static let control = set(
        #"""
        {
          "id": "control",
          "shortcuts": {
            "newMessage": ["⌘N"], "reply": ["⌘R"], "replyAll": ["⇧⌘R"], "forward": ["⌘J"], "send": ["⌘↩"],
            "archive": ["⌃E"], "trash": ["⌫"], "pin": ["⌃5"], "toggleRead": ["⌘T", "⇧⌘T"], "next": ["⌃]"],
            "previous": ["⌃["], "find": ["⌥⌘F"]
          },
          "notFound": ["snooze", "first", "last", "open", "pageDown", "pageUp"]
        }
        """#, "control", inheritingFrom: standard)

    /// Pins with s, which the standard set gives to snooze.
    static let star = set(
        #"""
        {
          "id": "star",
          "shortcuts": { "archive": ["a"], "trash": ["⌫"], "pin": ["s"], "next": ["f"], "previous": ["b"] },
          "notFound": ["snooze", "find"]
        }
        """#, "star", inheritingFrom: standard)

    /// Single letters, like a web app.
    static let letters = set(
        #"""
        {
          "id": "letters",
          "shortcuts": {
            "newMessage": ["c"], "reply": ["r"], "replyAll": ["a"], "forward": ["f"], "send": ["⌘↩"],
            "archive": ["e"], "trash": ["#"], "snooze": ["b"], "pin": ["s"], "toggleRead": ["⇧I", "⇧U"],
            "next": ["j"], "previous": ["k"], "open": ["o", "↩"], "find": ["/"]
          },
          "notFound": ["first", "last", "pageDown", "pageUp"]
        }
        """#, "letters", inheritingFrom: standard)

    static let all = [standard, menus, control, star, letters]
}

extension ShortcutBindings<Command> {
    static var standard: Self { Self(set: Sets.standard) }
}

/// The test app's rules, as an app would write them.
enum Rules {
    static let send = Shortcut(Shortcut.returnKey, [.command])
    static let system: [Shortcut] = [
        key("w", [.command]), key("q", [.command]), key("h", [.command]), key("m", [.command]), key("z", [.command]),
        key("z", [.command, .shift]), key("x", [.command]), key("c", [.command]), key("v", [.command]),
        key("a", [.command]), key("f", [.command, .control]),
    ]
    static let digits = (1...9).flatMap { digit -> [Shortcut] in
        let character = Character("\(digit)")
        return [key(character, [.command]), key(character, [.command, .option])]
    }
    static let triage: [Command] = [
        .newMessage, .reply, .replyAll, .forward, .archive, .trash, .snooze, .pin, .toggleRead, .next, .previous,
        .first, .last, .open, .pageDown, .pageUp, .find,
    ]

    static let standard = BindingRules<Command>(
        fixed: [.settings, .close],
        reserved: Set(system + digits + [key(",", [.command]), key(Shortcut.upArrow), key(Shortcut.downArrow)]),
        exclusive: [send: .send], usedWhileTyping: [.send, .bold, .draftOnly], triage: Set(triage))
}

enum Focus: Hashable, Sendable {
    case list, page, text, elsewhere
}

/// The test app's triage: the list takes every triage key, the page leaves scrolling and links to the web view.
func triage(_ bindings: ShortcutBindings<Command>) -> TriageTable<Command, Focus> {
    let native: Set<Command> = [.pageDown, .pageUp, .first, .last, .open]
    return TriageTable(
        bindings, commands: Rules.triage,
        accepted: [.list: Set(Rules.triage), .page: Set(Rules.triage).subtracting(native)])
}

func title(_ command: Command) -> String { "Title of \(command.rawValue)" }

/// The language `check.sh` pins the kit's strings to, nil when the run follows the host.
let pinnedLanguage = ProcessInfo.processInfo.environment["OVERLABING_TEST_LANGUAGE"]
