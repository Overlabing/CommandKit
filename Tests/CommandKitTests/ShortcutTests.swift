import CommandKit
import Foundation
import Testing

@Suite struct ShortcutTests {
    @Test func symbolsReadLikeAMenu() {
        #expect(Shortcut("r").symbols == "⌘R")
        #expect(Shortcut("r", [.command, .shift]).symbols == "⇧⌘R")
        #expect(Shortcut("k", [.command, .control, .option]).symbols == "⌃⌥⌘K")
        #expect(Shortcut("e", []).symbols == "e")
        #expect(Shortcut("#", []).symbols == "#")
        #expect(Shortcut(Shortcut.delete, [.command]).symbols == "⌘⌫")
        // A bare capital is typed with Shift (⇧I).
        #expect(Shortcut("I", []).symbols == "⇧I")
    }

    @Test func theSpaceBarIsNamedInTheUsersLanguage() {
        let name = Shortcut(Shortcut.space, [.shift]).symbols
        switch pinnedLanguage {
        case "fr": #expect(name == "⇧Espace")
        case "en": #expect(name == "⇧Space")
        default: #expect(name.hasPrefix("⇧"))
        }
        // The notation does not depend on the language.
        #expect(Shortcut(Shortcut.space, [.shift]).notation == "⇧Space")
    }

    @Test func typedCharactersAreNormalised() {
        // `#` already carries Shift (⇧3) or Option and Shift (some layouts): a bare key.
        #expect(Shortcut(characters: "#", modifiers: [.shift]) == key("#"))
        #expect(Shortcut(characters: "#", modifiers: [.shift, .option]) == key("#"))
        // Caps Lock: « E » without Shift stays e; ⇧E is the key « E ».
        #expect(Shortcut(characters: "E", modifiers: []) == key("e"))
        #expect(Shortcut(characters: "E", modifiers: [.shift]) == key("E"))
        // Space, ↩ and the arrows keep their modifiers.
        #expect(Shortcut(characters: " ", modifiers: [.shift]) == key(Shortcut.space, [.shift]))
        #expect(Shortcut(characters: "\u{F701}", modifiers: [.command]) == key(Shortcut.downArrow, [.command]))
        // ⌘ and ⌃ stay: ⌘E is not e. With them the key is the unmodified one, Shift kept (⇧⌘R, ⇧⌘7, ⌃]).
        #expect(Shortcut(characters: "e", modifiers: [.command]) == key("e", [.command]))
        #expect(Shortcut(characters: "R", baseCharacters: "r", modifiers: [.command, .shift]) == key("r", [.command, .shift]))
        #expect(Shortcut(characters: "&", baseCharacters: "7", modifiers: [.command, .shift]) == key("7", [.command, .shift]))
        #expect(Shortcut(characters: "\u{1D}", baseCharacters: "]", modifiers: [.control]) == key("]", [.control]))
        // ⌫ keeps its modifiers (⌘⌫); a bare ⇧I is the key « I ».
        #expect(Shortcut(characters: "\u{7F}", modifiers: [.command]) == key(Shortcut.delete, [.command]))
        #expect(Shortcut(characters: "I", modifiers: [.shift]) == key("I"))
        // A dead key (⌥e) or several characters: nothing.
        #expect(Shortcut(characters: "", modifiers: [.option]) == nil)
        #expect(Shortcut(characters: "ab", modifiers: []) == nil)
    }

    @Test func notationReadsAndWritesEveryKey() {
        for set in Sets.all {
            for keys in set.keys.values {
                for shortcut in keys {
                    #expect(Shortcut(notation: shortcut.notation) == shortcut, "\(shortcut.notation)")
                }
            }
        }
        #expect(Shortcut(notation: "⇧⌘R") == key("r", [.shift, .command]))
        #expect(Shortcut(notation: "⇧Space") == key(Shortcut.space, [.shift]))
        #expect(Shortcut(notation: "⇧I") == key("I"))
        #expect(Shortcut(notation: "⇧3") == nil)
        #expect(Shortcut(notation: "⌘⌘R") == nil)
        #expect(Shortcut(notation: "") == nil)
    }

    @Test func aShortcutIsCodedAsItsNotation() throws {
        let data = try JSONEncoder().encode([key("r", [.shift, .command]), key(Shortcut.space)])
        #expect(String(decoding: data, as: UTF8.self) == #"["⇧⌘R","Space"]"#)
        #expect(try JSONDecoder().decode([Shortcut].self, from: data) == [key("r", [.shift, .command]), key(Shortcut.space)])
        #expect(throws: DecodingError.self) { try JSONDecoder().decode([Shortcut].self, from: Data(#"["⇧3"]"#.utf8)) }
    }

    @Test func textEditingKeys() {
        for editing in [
            key(Shortcut.delete), key(Shortcut.delete, [.command]), key(Shortcut.delete, [.option]),
            key(Shortcut.downArrow, [.command]), key(Shortcut.leftArrow, [.command, .shift]),
            key("e", [.control]), key("a", [.control]), key("k", [.control]), key("E", [.control, .shift]),
        ] {
            #expect(editing.editsText, "\(editing.symbols)")
        }
        for menu in [
            key("r"), key("e", [.control, .command]), key(Shortcut.downArrow, [.option]),
            key(Shortcut.rightArrow, [.option, .command]), key("]", [.control]), key("5", [.control]),
            key("u", [.control]), key("e"),
        ] {
            #expect(!menu.editsText, "\(menu.symbols)")
        }
    }

    @Test func typingKeysHaveNeitherCommandNorControl() {
        #expect(key("g").isTyping)
        #expect(key("G").isTyping)
        #expect(key(Shortcut.space, [.shift]).isTyping)
        #expect(!key("g", [.command]).isTyping)
        #expect(!key("g", [.control]).isTyping)
    }
}
