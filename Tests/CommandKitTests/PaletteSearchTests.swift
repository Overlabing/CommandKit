import Foundation
import Testing
@testable import CommandKit

private enum Section: Int, PaletteSectioning {
    case recent, actions, compose, navigation
}

private struct Item: PaletteSearchable, Equatable {
    let id: String
    let title: String
    let section: Section
    var shortcut: Shortcut? = nil
    var synonyms: [String] = []
    var listedWithoutQuery = true
}

@Suite struct PaletteSearchTests {
    private let items: [Item] = [
        Item(id: "archive", title: "Archiver", section: .actions, shortcut: key("e"), synonyms: ["ranger", "classer", "terminé"]),
        Item(id: "trash", title: "Supprimer", section: .actions, shortcut: key("#"), synonyms: ["corbeille", "effacer", "poubelle", "jeter"]),
        Item(id: "pin", title: "Épingler", section: .actions, shortcut: key("p")),
        Item(id: "replyAll", title: "Répondre à tous", section: .actions, shortcut: key("r", [.shift, .command])),
        Item(id: "saveAs", title: "Enregistrer sous…", section: .actions, synonyms: ["eml", "exporter", "archiver le message", "fichier"]),
        Item(id: "nextMessage", title: "Message suivant", section: .actions),
        Item(id: "previousMessage", title: "Message précédent", section: .actions),
        Item(id: "newMessage", title: "Nouveau message", section: .compose, shortcut: key("n", [.command])),
        Item(id: "find", title: "Rechercher", section: .navigation, synonyms: ["chercher", "trouver", "recherche", "search"]),
        Item(id: "settings", title: "Réglages…", section: .navigation, synonyms: ["préférences", "options", "paramètres"]),
        Item(id: "space.hobby", title: "Aller à l'espace « Hobby »", section: .navigation, shortcut: key("2", [.command]), synonyms: ["Hobby", "aller à, ouvrir", "space"]),
        Item(id: "move.2026", title: "Déplacer vers « Archives/2026 »", section: .actions, synonyms: ["Archives/2026"], listedWithoutQuery: false),
    ]

    private func found(_ query: String, recents: PaletteRecents = .init()) -> [String] {
        PaletteSearch.results(for: query, in: items, recents: recents).items.map(\.id)
    }

    @Test func emptyQueryListsSectionsInOrderWithoutSearchOnlyEntries() {
        let results = PaletteSearch.results(for: "  ", in: items, recents: .init())
        #expect(results.sections.map(\.section) == [.actions, .compose, .navigation])
        #expect(!results.items.contains { $0.id == "move.2026" })
    }

    @Test func accentsAndCaseAreIgnored() {
        #expect(found("epingler").first == "pin")
        #expect(found("ÉPINGLER").first == "pin")
        #expect(found("repondre a tous").first == "replyAll")
        #expect(found("precedent").first == "previousMessage")
    }

    @Test func prefixBeatsSubstringBeatsFuzzy() {
        #expect(PaletteText.match("arch", in: "archiver")! > PaletteText.match("chiv", in: "archiver")!)
        #expect(PaletteText.match("chiv", in: "archiver")! > PaletteText.match("arvr", in: "archiver")!)
        #expect(PaletteText.match("rep tous", in: "repondre a tous") == 800)
    }

    @Test func fuzzyLettersStartAtAWord() {
        #expect(PaletteText.match("trjr", in: "terminer la journee") != nil)
        #expect(PaletteText.match("rmnr", in: "terminer la journee") == nil)
        // A single letter only searches word starts.
        #expect(PaletteText.match("v", in: "archiver") == nil)
    }

    @Test func synonymsFindAnEntry() {
        #expect(found("corbeille").first == "trash")
        #expect(found("preferences").first == "settings")
    }

    @Test func titleMatchesRankAboveSynonyms() {
        #expect(found("suppr").first == "trash")
    }

    @Test func shortcutsAreSearchable() {
        #expect(PaletteText.shortcutQuery("⇧⌘K") == "⇧⌘K")
        #expect(PaletteText.shortcutQuery("cmd shift r") == "⇧⌘R")
        #expect(PaletteText.shortcutQuery("maj+cmd+r") == "⇧⌘R")
        #expect(PaletteText.shortcutQuery("#") == "#")
        #expect(PaletteText.shortcutQuery("e") == nil)
        #expect(PaletteText.shortcutQuery("répondre") == nil)
        #expect(found("cmd shift r").first == "replyAll")
        #expect(found("⌘2").first == "space.hobby")
        #expect(found("#").first == "trash")
    }

    @Test func aStrongMatchDropsTheNoise() {
        let arch = found("arch")
        #expect(arch.first == "archive")
        #expect(!arch.contains("find"))
        #expect(!arch.contains("space.hobby"))
        // A word of a synonym stays: « archiver le message ».
        #expect(arch.contains("saveAs"))
        // Without a strong match, letters in order still count.
        #expect(found("hby").first == "space.hobby")
    }

    @Test func searchOnlyEntriesAppearWhenSearched() {
        #expect(found("2026").first == "move.2026")
    }

    @Test func noMatchGivesNoSection() {
        #expect(PaletteSearch.results(for: "zzqx", in: items, recents: .init()).isEmpty)
    }

    @Test func sectionsFollowTheirBestResult() {
        let results = PaletteSearch.results(for: "hobby", in: items, recents: .init())
        #expect(results.sections.first?.section == .navigation)
        #expect(results.items.first?.id == "space.hobby")
    }

    @Test func recentsComeFirstWithoutQuery() {
        let recents = PaletteRecents().recording("trash").recording("space.hobby")
        let results = PaletteSearch.results(for: "", in: items, recents: recents)
        #expect(results.sections.first?.section == .recent)
        #expect(results.sections.first?.items.map(\.id) == ["space.hobby", "trash"])
        // A recent entry is not listed twice.
        #expect(results.items.filter { $0.id == "trash" }.count == 1)
    }

    @Test func unavailableRecentsAreSkipped() {
        let recents = PaletteRecents().recording("gone").recording("move.2026")
        let results = PaletteSearch.results(for: "", in: items, recents: recents)
        #expect(results.sections.first?.section != .recent)
    }

    @Test func recentsAreCappedWithoutQuery() {
        var recents = PaletteRecents()
        for item in items.reversed() { recents = recents.recording(item.id) }
        let results = PaletteSearch.results(for: "", in: items, recents: recents)
        #expect(results.sections.first?.items.count == PaletteSearch.recentLimit)
    }

    @Test func recentsBreakTiesInASearch() {
        #expect(found("message").first == "nextMessage")
        #expect(found("message", recents: PaletteRecents().recording("previousMessage")).first == "previousMessage")
    }

    @Test func recordingMovesToFrontWithoutDuplicatesAndCaps() throws {
        var recents = PaletteRecents()
        for index in 0..<12 { recents = recents.recording("item.\(index)") }
        recents = recents.recording("item.9")
        #expect(recents.ids.count == PaletteRecents.capacity)
        #expect(recents.ids.first == "item.9")
        #expect(Set(recents.ids).count == recents.ids.count)
        #expect(try PaletteRecents(data: recents.data()) == recents)
        #expect(try PaletteRecents(data: nil) == PaletteRecents())
        #expect(throws: (any Error).self) { try PaletteRecents(data: Data("x".utf8)) }
    }

    @Test func selectionMovesWithinBounds() {
        #expect(PaletteSearch.moved(nil, by: 1, count: 3) == 0)
        #expect(PaletteSearch.moved(nil, by: -1, count: 3) == 2)
        #expect(PaletteSearch.moved(0, by: -1, count: 3) == 0)
        #expect(PaletteSearch.moved(2, by: 1, count: 3) == 2)
        #expect(PaletteSearch.moved(1, by: 1, count: 3) == 2)
        #expect(PaletteSearch.moved(0, by: 1, count: 0) == nil)
    }

    @Test func normalizationFoldsLigaturesAndPunctuation() {
        #expect(PaletteText.normalize("Cœur « Pro » — l'espace…") == "coeur pro l espace")
    }
}
