import CommandKit
import Foundation
import Testing

@Suite struct ShortcutSetTests {
    @Test func everyFixtureSetIsValidUnderTheRules() {
        for set in Sets.all {
            let bindings = ShortcutBindings(set: set)
            #expect(bindings.conflicts.isEmpty, "\(set.id) \(bindings.conflicts)")
            for command in Command.allCases where Rules.standard.isRebindable(command) {
                for shortcut in bindings.keys(command) {
                    #expect(throws: Never.self, "\(set.id) \(command) \(shortcut.symbols)") {
                        try Rules.standard.validate(shortcut, for: command)
                    }
                }
            }
        }
    }

    @Test func theRootSetHasItsOwnKeysAndInheritsNothing() {
        let set = Sets.standard
        #expect(set.keys(for: .archive) == [key("e"), key(Shortcut.delete)])
        #expect(set.keys(for: .trash) == [key("#"), key(Shortcut.delete, [.command])])
        #expect(set.keys(for: .pageUp) == [key(Shortcut.space, [.shift])])
        #expect(set.keys(for: .draftOnly).isEmpty)
        #expect(!Command.allCases.contains { set.inherits($0) })
        #expect(set.source == nil && set.checked == nil && set.note == nil)
    }

    @Test func aSetWithoutTheCommandInheritsAndSaysSo() {
        let menus = ShortcutBindings(set: Sets.menus)
        #expect(menus.keys(.archive) == [key("a", [.control, .command])])
        #expect(!menus.isInherited(.archive))
        #expect(menus.keys(.trash) == Sets.standard.keys(for: .trash))
        #expect(menus.isInherited(.trash))
        // Only the app has Spaces: their keys are the same everywhere, without the mention.
        #expect(menus.keys(.nextSpace) == Sets.standard.keys(for: .nextSpace))
        #expect(!menus.isInherited(.nextSpace))
    }

    @Test func anInheritedKeyTheSetUsesElsewhereIsDropped() {
        // This set pins with s: snooze (s in the standard set) inherits nothing.
        #expect(Sets.star.keys(for: .pin) == [key("s")])
        #expect(Sets.star.keys(for: .snooze).isEmpty)
        #expect(Sets.star.keys(for: .find) == Sets.standard.keys(for: .find))
        // ⌫ is the set's own trash key: archive keeps only e.
        #expect(Sets.star.keys(for: .archive) == [key("a")])
        #expect(Sets.control.keys(for: .archive) == [key("e", [.control])])
    }

    @Test func aCommandMentionedWithNoKeyReceivesNothingAndAnUnmentionedOneInherits() throws {
        let file = Data(#"{"id":"quiet","shortcuts":{"archive":[],"pin":["e"]}}"#.utf8)
        let quiet = try ShortcutSet<Command>(data: file, expecting: "quiet", inheritingFrom: Sets.standard)
        // The parent gives archive e and ⌫: mentioned with no key, it gets neither.
        #expect(Sets.standard.keys(for: .archive) == [key("e"), key(Shortcut.delete)])
        #expect(quiet.own[.archive] == [])
        #expect(quiet.keys[.archive] == [])
        #expect(quiet.keys(for: .archive).isEmpty)
        #expect(!quiet.inherits(.archive))
        // Not mentioned: inherits the parent's keys, minus the one this set gives pin.
        #expect(quiet.own[.reply] == nil)
        #expect(quiet.keys(for: .reply) == Sets.standard.keys(for: .reply))
        #expect(quiet.keys(for: .trash) == Sets.standard.keys(for: .trash))
        // The key the unassigned command left is free for another one.
        let bindings = ShortcutBindings(set: quiet)
        #expect(bindings.keys(.pin) == [key("e")])
        #expect(bindings.owner(of: key("e")) == .pin)
        #expect(bindings.conflicts.isEmpty)
        // The same rule when the set is built in code.
        let built = ShortcutSet<Command>(id: "built", own: [.archive: []], inheritingFrom: Sets.standard)
        #expect(built.keys(for: .archive).isEmpty)
        #expect(built.keys(for: .reply) == Sets.standard.keys(for: .reply))
    }

    @Test func provenanceIsRead() {
        let menus = Sets.menus
        #expect(menus.id == "menus")
        #expect(menus.source == URL(string: "https://example.com/menus/shortcuts"))
        #expect(menus.checked == "2026-10-27")
        #expect(menus.note == "Read from the vendor's page.")
        #expect(menus.own[.replyAll] == [.init(key("r", [.shift, .command]), from: "Reply All (⇧⌘R)")])
        #expect(menus.own[.reply] == [.init(key("r", [.command]))])
        #expect(menus.notFound[.trash] == .some("Delete has no key on the page."))
        // A plain list of absent commands has no reasons.
        #expect(Sets.control.notFound[.snooze] == .some(nil))
        #expect(Sets.control.notFound[.archive] == nil)
    }

    @Test func aBrokenDataFileIsAnErrorNotACrash() {
        let unknown = Data(#"{"id":"letters","shortcuts":{"teleport":["t"]}}"#.utf8)
        #expect(throws: ShortcutSetError.unknownCommand("teleport")) {
            try ShortcutSet<Command>(data: unknown, expecting: "letters", inheritingFrom: Sets.standard)
        }
        let notation = Data(#"{"id":"letters","shortcuts":{"archive":["⇧3"]}}"#.utf8)
        #expect(throws: ShortcutSetError.invalidNotation("⇧3")) {
            try ShortcutSet<Command>(data: notation, expecting: "letters", inheritingFrom: Sets.standard)
        }
        let mismatched = Data(#"{"id":"control","shortcuts":{}}"#.utf8)
        #expect(throws: ShortcutSetError.mismatchedID(expected: "letters", found: "control")) {
            try ShortcutSet<Command>(data: mismatched, expecting: "letters", inheritingFrom: Sets.standard)
        }
        let absent = Data(#"{"id":"letters","shortcuts":{},"notFound":{"teleport":"No such thing."}}"#.utf8)
        #expect(throws: ShortcutSetError.unknownCommand("teleport")) {
            try ShortcutSet<Command>(data: absent, expecting: "letters", inheritingFrom: Sets.standard)
        }
        #expect(throws: DecodingError.self) {
            try ShortcutSet<Command>(data: Data("{".utf8), expecting: "letters", inheritingFrom: nil)
        }
    }
}

@Suite struct ShortcutBindingsTests {
    @Test func aRecordedKeyBecomesTheMenuKeyAndKeepsTheAliases() throws {
        var bindings = ShortcutBindings<Command>.standard
        try bindings.record(key("y"), for: .archive, rules: Rules.standard)
        #expect(bindings.keys(.archive) == [key("y"), key(Shortcut.delete)])
        #expect(bindings.shortcut(.archive) == key("y"))
        #expect(bindings.isOverridden(.archive))
        #expect(triage(bindings).command(for: key("y"), in: .list) == .archive)
        #expect(triage(bindings).command(for: key("e"), in: .list) == nil)
        bindings.reset(.archive)
        #expect(bindings == .standard)
    }

    @Test func recordingTheSetsOwnKeyLeavesNoOverride() throws {
        var bindings = ShortcutBindings(set: Sets.letters)
        try bindings.record(key("e"), for: .archive, rules: Rules.standard)
        #expect(bindings.overrides.isEmpty)
    }

    @Test func aTakenKeyIsRefusedWithTheCommandThatHasIt() {
        var bindings = ShortcutBindings<Command>.standard
        #expect(throws: ShortcutBindingError.taken(key("j"), by: Command.next)) {
            try bindings.record(key("j"), for: .archive, rules: Rules.standard)
        }
        #expect(bindings == .standard)
        let message = ShortcutBindingError.taken(key("j"), by: Command.next).message(appName: "Test", title: title)
        #expect(message.contains(title(.next)))
        #expect(bindings.owner(of: key("j")) == .next)
        #expect(bindings.owner(of: key("j"), other: .next) == nil)
    }

    @Test func systemKeysAndTypingKeysAreRefused() {
        var bindings = ShortcutBindings<Command>.standard
        let reservedKeys = [
            key("q", [.command]), key("w", [.command]), key(",", [.command]), key("z", [.command, .shift]),
            key("3", [.command]), key("2", [.command, .option]), key(Shortcut.escape), key(Shortcut.tab),
            key(Shortcut.downArrow), key(Shortcut.escape, [.command]), key(Shortcut.tab, [.shift]),
        ]
        for reserved in reservedKeys {
            #expect(throws: ShortcutBindingError<Command>.reserved(reserved)) {
                try bindings.record(reserved, for: .archive, rules: Rules.standard)
            }
        }
        // ⌘↩ sends: only Send may take it.
        #expect(throws: ShortcutBindingError<Command>.reserved(Rules.send)) {
            try bindings.record(Rules.send, for: .archive, rules: Rules.standard)
        }
        #expect(throws: Never.self) { try bindings.record(Rules.send, for: .send, rules: Rules.standard) }
        // A key that types text on a command used while typing.
        #expect(throws: ShortcutBindingError<Command>.typesText(key("g"))) {
            try bindings.record(key("g"), for: .bold, rules: Rules.standard)
        }
        #expect(throws: ShortcutBindingError<Command>.typesText(key("G"))) {
            try bindings.record(key("G"), for: .send, rules: Rules.standard)
        }
        #expect(throws: ShortcutBindingError<Command>.notRebindable(.settings)) {
            try bindings.record(key("g", [.command]), for: .settings, rules: Rules.standard)
        }
        #expect(!Rules.standard.isRebindable(.close))
        #expect(Rules.standard.isRebindable(.archive))
    }

    @Test func aTextEditingKeyIsRefusedOutsideTheTriage() {
        var bindings = ShortcutBindings<Command>.standard
        #expect(throws: ShortcutBindingError<Command>.editsText(key(Shortcut.delete, [.command]))) {
            try bindings.record(key(Shortcut.delete, [.command]), for: .endDay, rules: Rules.standard)
        }
        #expect(throws: ShortcutBindingError<Command>.editsText(key("k", [.control]))) {
            try bindings.record(key("k", [.control]), for: .palette, rules: Rules.standard)
        }
        #expect(bindings == .standard)
    }

    @Test func commandDeleteRecordedOnTrashStaysATriageKey() throws {
        var bindings = ShortcutBindings<Command>.standard
        try bindings.record(key(Shortcut.delete, [.command]), for: .trash, rules: Rules.standard)
        #expect(bindings.keys(.trash) == [key(Shortcut.delete, [.command])])
        // No menu item: ⌘⌫ in a search field or a sheet deletes text.
        #expect(bindings.shortcut(.trash) == nil)
        let table = triage(bindings)
        #expect(table.command(for: key(Shortcut.delete, [.command]), in: .list) == .trash)
        #expect(table.command(for: key(Shortcut.delete, [.command]), in: .text) == nil)
        #expect(table.command(for: key(Shortcut.delete, [.command]), in: .elsewhere) == nil)
        // The help still names the key.
        #expect(bindings.helpText(title: "Trash", for: .trash) == "Trash (⌘⌫)")
        // With # behind it, # is the menu key.
        var aliased = ShortcutBindings<Command>.standard
        try aliased.record(key("x", [.control, .command]), for: .trash, rules: Rules.standard)
        #expect(aliased.shortcut(.trash) == key("x", [.control, .command]))
        #expect(ShortcutBindings<Command>.standard.shortcut(.trash) == key("#"))
    }

    @Test func noMenuShortcutEditsTextInAnySet() {
        for set in Sets.all {
            let bindings = ShortcutBindings(set: set)
            for command in Command.allCases {
                #expect(bindings.shortcut(command)?.editsText != true, "\(set.id) \(command)")
            }
        }
        // ⌃E (end of line in a field) archives: a triage key, no menu shortcut.
        #expect(ShortcutBindings(set: Sets.control).shortcut(.archive) == nil)
        #expect(triage(ShortcutBindings(set: Sets.control)).command(for: key("e", [.control]), in: .list) == .archive)
        #expect(ShortcutBindings<Command>.standard.shortcut(.first) == nil)
        #expect(ShortcutBindings<Command>.standard.shortcut(.last) == nil)
    }

    @Test func helpTextNamesTheMenuKey() {
        let bindings = ShortcutBindings<Command>.standard
        #expect(bindings.helpText(title: "Archive", for: .archive) == "Archive (e)")
        #expect(bindings.helpText(title: "Reply", for: .reply) == "Reply (⌘R)")
        #expect(bindings.helpText(title: "Draft", for: .draftOnly) == "Draft")
    }

    @Test func choosingASetDropsTheChanges() throws {
        var bindings = ShortcutBindings<Command>.standard
        try bindings.record(key("y"), for: .archive, rules: Rules.standard)
        bindings.choose(Sets.control)
        #expect(bindings == ShortcutBindings(set: Sets.control))
        try bindings.record(key("y"), for: .archive, rules: Rules.standard)
        bindings.resetAll()
        #expect(bindings.overrides.isEmpty)
        #expect(bindings.set.id == "control")
    }

    @Test func overridesArePersistedAndReadBack() throws {
        var bindings = ShortcutBindings(set: Sets.menus)
        try bindings.record(key(Shortcut.delete), for: .archive, rules: Rules.standard)
        try bindings.record(key("I"), for: .toggleRead, rules: Rules.standard)
        try bindings.record(key("e", [.control, .command]), for: .endDay, rules: Rules.standard)
        let data = try bindings.data()
        let read = { (data: Data?) in try ShortcutBindings.read(data, sets: Sets.all, standard: .standard) }
        #expect(try read(data).bindings == bindings)
        #expect(try read(data).ignored.isEmpty)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains(#""base":"menus""#))
        #expect(text.contains("⌫"))
        #expect(try read(nil).bindings == .standard)
        #expect(throws: (any Error).self) { try read(Data("{".utf8)) }
        #expect(throws: ShortcutBindingsReadError.unknownSet("elsewhere")) {
            try read(Data(#"{"base":"elsewhere","overrides":{}}"#.utf8))
        }
    }

    @Test func theStoredFormatIsStable() throws {
        var bindings = ShortcutBindings(set: Sets.letters)
        try bindings.record(key(Shortcut.delete), for: .archive, rules: Rules.standard)
        try bindings.record(key("y"), for: .pin, rules: Rules.standard)
        #expect(String(decoding: try bindings.data(), as: UTF8.self) == #"{"base":"letters","overrides":{"archive":["⌫"],"pin":["y"]}}"#)
    }

    @Test func anOverrideWithNoKeyLeavesTheCommandUnassignedAndTheOthersFollowTheSet() throws {
        let bindings = ShortcutBindings(set: Sets.standard, overrides: [.archive: []])
        #expect(Sets.standard.keys(for: .archive) == [key("e"), key(Shortcut.delete)])
        #expect(bindings.keys(.archive).isEmpty)
        #expect(bindings.shortcut(.archive) == nil)
        #expect(bindings.isOverridden(.archive))
        #expect(!bindings.isInherited(.archive))
        #expect(bindings.helpText(title: "Archive", for: .archive) == "Archive")
        #expect(bindings.owner(of: key("e")) == nil)
        #expect(triage(bindings).command(for: key("e"), in: .list) == nil)
        #expect(bindings.keys(.trash) == Sets.standard.keys(for: .trash))
        #expect(!bindings.isOverridden(.trash))
        // An unassigned command does not hold the key against the others.
        var other = bindings
        #expect(throws: Never.self) { try other.record(key("e"), for: .pin, rules: Rules.standard) }
        #expect(other.keys(.pin) == [key("e")])
        // Reset gives the set's keys back.
        other.reset(.archive)
        #expect(other.keys(.archive) == Sets.standard.keys(for: .archive))
        #expect(!other.isOverridden(.archive))
    }

    @Test func anEmptyOverrideSurvivesStorageByteForByte() throws {
        let bindings = ShortcutBindings(set: Sets.letters, overrides: [.archive: [], .pin: [key("y")]])
        let data = try bindings.data()
        #expect(String(decoding: data, as: UTF8.self) == #"{"base":"letters","overrides":{"archive":[],"pin":["y"]}}"#)
        let (read, ignored) = try ShortcutBindings.read(data, sets: Sets.all, standard: .standard)
        #expect(ignored.isEmpty)
        #expect(read == bindings)
        #expect(read.overrides[.archive] == [])
        #expect(read.keys(.archive).isEmpty && read.isOverridden(.archive))
        #expect(try read.data() == data)
    }

    @Test func anUnknownStoredOverrideIsIgnoredNotEverything() throws {
        let stored = Data(#"{"base":"letters","overrides":{"archive":["⌫"],"teleport":["t"],"trash":["⇧3"],"pin":["y"]}}"#.utf8)
        let (bindings, ignored) = try ShortcutBindings.read(stored, sets: Sets.all, standard: .standard)
        #expect(bindings.set.id == "letters")
        #expect(bindings.overrides == [.archive: [key(Shortcut.delete)], .pin: [key("y")]])
        #expect(ignored == ["teleport: t", "trash: ⇧3"])
    }

    @Test func storedOverridesAgainstAChangedSetAreConflictsNotCrashes() {
        // The previous command on the next command's key, as preferences written against an older set would.
        let bindings = ShortcutBindings(set: Sets.standard, overrides: [.previous: [key("j")]])
        #expect(bindings.conflicts == [ShortcutConflict(shortcut: key("j"), commands: [.next, .previous])])
        // The triage keeps the first command of its list.
        #expect(triage(bindings).command(for: key("j"), in: .list) == .next)
    }

    @Test func aCommandBeforeTheFocusedViewTakesItsMenuKey() {
        var rules = Rules.standard
        rules.beforeFocusedView = [.palette]
        let bindings = ShortcutBindings<Command>.standard
        #expect(bindings.takesKeyBeforeFocusedView(key("k", [.command]), rules: rules))
        #expect(!bindings.takesKeyBeforeFocusedView(key("r", [.command]), rules: rules))
        #expect(!bindings.takesKeyBeforeFocusedView(key("k", [.command]), rules: Rules.standard))
    }

    @Test func messagesNameTheKeyTheCommandAndTheApp() {
        let reserved = ShortcutBindingError<Command>.reserved(key("q", [.command])).message(appName: "Test", title: title)
        let taken = ShortcutBindingError.taken(key("j"), by: Command.next).message(appName: "Test", title: title)
        let fixed = ShortcutBindingError.notRebindable(Command.settings).message(appName: "Test", title: title)
        let typing = ShortcutBindingError<Command>.typesText(key("g")).message(appName: "Test", title: title)
        let editing = ShortcutBindingError<Command>.editsText(key("k", [.control])).message(appName: "Test", title: title)
        let none = ShortcutBindingError<Command>.notAKey.message(appName: "Test", title: title)
        switch pinnedLanguage {
        case "fr":
            #expect(reserved == "⌘Q est réservé par macOS ou par Test.")
            #expect(taken == "j est déjà pris par « Title of next ».")
            #expect(fixed == "« Title of settings » garde le raccourci du système.")
            #expect(typing == "g écrirait du texte : ajoutez ⌘ ou ⌃.")
            #expect(editing == "⌃K modifie le texte d'un champ : il ne peut servir qu'aux touches du triage.")
            #expect(none == "Cette touche ne forme pas un raccourci (touche morte ou composée) : essayez-en une autre.")
        case "en":
            #expect(reserved == "⌘Q is reserved by macOS or Test.")
            #expect(taken == "j is already used by “Title of next”.")
            #expect(fixed == "“Title of settings” keeps the system's shortcut.")
            #expect(typing == "g would type text: add ⌘ or ⌃.")
            #expect(editing == "⌃K edits the text of a field: it can only be a triage key.")
            #expect(none == "This key doesn't make a shortcut (dead or composed key): try another one.")
        default:
            #expect(reserved.contains("⌘Q") && reserved.contains("Test"))
        }
    }
}
