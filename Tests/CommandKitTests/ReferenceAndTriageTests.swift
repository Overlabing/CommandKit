import CommandKit
import Testing

@Suite struct ShortcutReferenceTests {
    private let groups: [ShortcutReference<Command>.Group] = [
        .init(
            id: "browse", title: "Browse", commands: [.next, .previous, .first, .last, .open, .nextSpace],
            fixedRows: [.init(id: "goToSpace", title: "Go to Space 1 to 9", keys: ["⌘1…⌘9"])]),
        .init(id: "act", title: "Act", commands: [.reply, .replyAll, .archive, .trash, .snooze, .draftOnly]),
    ]

    @Test func theReferenceListsBoundCommandsThenFixedRows() {
        let sections = ShortcutReference.sections(groups, bindings: .standard, title: title)
        #expect(sections.map(\.id) == ["browse", "act"])
        #expect(sections.map(\.title) == ["Browse", "Act"])
        let rows = sections.flatMap(\.rows)
        #expect(rows.first { $0.id == "replyAll" }?.keys == ["⇧⌘R", "a"])
        #expect(rows.first { $0.id == "open" }?.keys == ["o", "↩"])
        #expect(rows.first { $0.id == "open" }?.title == "Title of open")
        #expect(sections[0].rows.last?.id == "goToSpace")
        #expect(sections[0].rows.last?.command == nil)
        // A command without a key has no row.
        #expect(!rows.contains { $0.id == "draftOnly" })
        #expect(Set(rows.map(\.id)).count == rows.count)
    }

    @Test func theSettingsListEveryCommandEvenWithoutKey() {
        let rows = ShortcutReference.editableSections(groups, bindings: .standard, title: title).flatMap(\.rows)
        #expect(rows.contains { $0.command == .draftOnly && $0.keys.isEmpty })
        #expect(!rows.contains { $0.command == nil })
        #expect(rows.compactMap(\.command) == groups.flatMap(\.commands))
    }

    @Test func rowsSayInheritedAndOverridden() throws {
        var bindings = ShortcutBindings(set: Sets.menus)
        let rows = ShortcutReference.sections(groups, bindings: bindings, title: title).flatMap(\.rows)
        #expect(rows.first { $0.command == .trash }?.isInherited == true)
        #expect(rows.first { $0.command == .replyAll }?.isInherited == false)
        try bindings.record(key("y"), for: .trash, rules: Rules.standard)
        let changed = try #require(ShortcutReference.row(.trash, bindings, title: "Trash"))
        #expect(changed.isOverridden && !changed.isInherited)
        #expect(changed.keys == ["y", "⌘⌫"])
        // An unbound command is never « inherited ».
        let star = ShortcutBindings(set: Sets.star)
        #expect(ShortcutReference.row(.snooze, star, title: "Snooze") == nil)
        #expect(ShortcutReference.row(.snooze, star, title: "Snooze", includingUnbound: true)?.isInherited == false)
    }
}

@Suite struct TriageTableTests {
    private let table = triage(.standard)

    @Test func everyTriageKeyGivesItsCommandInTheList() {
        let expected: [Shortcut: Command] = [
            key("j"): .next, key("k"): .previous,
            key(Shortcut.upArrow, [.command]): .first, key(Shortcut.downArrow, [.command]): .last,
            key("o"): .open, key(Shortcut.returnKey): .open,
            key(Shortcut.space): .pageDown, key(Shortcut.space, [.shift]): .pageUp,
            key("e"): .archive, key("#"): .trash, key("p"): .pin, key("u"): .toggleRead, key("s"): .snooze,
            key("r"): .reply, key("a"): .replyAll, key("f"): .forward, key("/"): .find,
            key(Shortcut.delete): .archive, key(Shortcut.delete, [.command]): .trash,
        ]
        for (shortcut, command) in expected {
            #expect(table.command(for: shortcut, in: .list) == command, "\(shortcut.symbols)")
        }
        // The table holds every key of a triage command, its menu shortcut included (⌘R, ⇧⌘U).
        #expect(table.command(for: key("r", [.command]), in: .list) == .reply)
        #expect(table.commands.count == Rules.triage.map { ShortcutBindings<Command>.standard.keys($0).count }.reduce(0, +))
    }

    @Test func nothingIsTriagedInTextOrElsewhere() {
        for shortcut in table.commands.keys {
            #expect(table.command(for: shortcut, in: .text) == nil)
            #expect(table.command(for: shortcut, in: .elsewhere) == nil)
        }
    }

    @Test func aFocusTakesOnlyItsCommands() {
        for character: Character in ["e", "#", "p", "u", "r", "a", "f", "j", "k", "/", "s"] {
            #expect(table.command(for: key(character), in: .page) == table.command(for: key(character), in: .list))
        }
        #expect(table.command(for: key(Shortcut.space), in: .page) == nil)
        #expect(table.command(for: key(Shortcut.space, [.shift]), in: .page) == nil)
        #expect(table.command(for: key(Shortcut.downArrow, [.command]), in: .page) == nil)
        #expect(table.command(for: key(Shortcut.returnKey), in: .page) == nil)
        #expect(table.command(for: key("o"), in: .page) == nil)
    }

    @Test func otherCommandsKeysAndPlainArrowsAreNotTriaged() {
        for shortcut in [
            key("e", [.command, .option]), key("b", [.command]), key(Shortcut.downArrow), key(Shortcut.upArrow),
            key("j", [.control]),
        ] {
            #expect(table.command(for: shortcut, in: .list) == nil, "\(shortcut.symbols)")
        }
    }

    @Test func theTriageFollowsTheChosenSet() {
        let letters = triage(ShortcutBindings(set: Sets.letters))
        #expect(letters.command(for: key("e"), in: .list) == .archive)
        #expect(letters.command(for: key("j"), in: .list) == .next)
        #expect(letters.command(for: key("c"), in: .list) == .newMessage)
        let menus = triage(ShortcutBindings(set: Sets.menus))
        #expect(menus.command(for: key("a", [.control, .command]), in: .list) == .archive)
        #expect(menus.command(for: key("r", [.shift, .command]), in: .list) == .replyAll)
        #expect(menus.command(for: key("a"), in: .list) == nil)
    }
}
