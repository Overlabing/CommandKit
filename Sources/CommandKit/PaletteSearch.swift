import Foundation

/// The sections of a command palette, in the order they show without a query. `recent` is the section of the recently
/// chosen entries, listed first.
public protocol PaletteSectioning: Hashable, Sendable, CaseIterable {
    static var recent: Self { get }
}

/// An entry the palette can find: the app builds them from what is available now (its own rules), the kit only ranks.
public protocol PaletteSearchable: Sendable, Identifiable where ID == String {
    associatedtype Section: PaletteSectioning
    /// Stable across launches: recently used entries are stored by it.
    var id: String { get }
    var title: String { get }
    var section: Section { get }
    /// The key shown on the entry, also searchable (« ⇧⌘K », « cmd shift k »).
    var shortcut: Shortcut? { get }
    /// Other words that find the entry.
    var synonyms: [String] { get }
    /// False for an entry only a search shows (too many of them to list).
    var listedWithoutQuery: Bool { get }
}

/// The result of a search: non-empty sections, and the same list flat for the keyboard.
public struct PaletteResults<Item: PaletteSearchable>: Sendable {
    public struct Section: Sendable, Identifiable {
        public let section: Item.Section
        public var items: [Item]
        public var id: Item.Section { section }

        public init(section: Item.Section, items: [Item]) {
            self.section = section
            self.items = items
        }
    }

    public let sections: [Section]
    public var items: [Item] { sections.flatMap(\.items) }
    public var isEmpty: Bool { sections.isEmpty }

    public init(sections: [Section]) {
        self.sections = sections
    }
}

extension PaletteResults.Section: Equatable where Item: Equatable {}
extension PaletteResults: Equatable where Item: Equatable {}

/// Fuzzy search over palette entries, tolerant of accents and case, with recently used entries favoured.
public enum PaletteSearch {
    /// The entries ranked for `query`. Without a query: the recent ones first (the `recent` section), then each section
    /// in its order. With a query: only the entries found, the sections ordered by their best result, recent entries
    /// slightly favoured; the first entry is always the best result.
    public static func results<Item: PaletteSearchable>(
        for query: String, in items: [Item], recents: PaletteRecents
    ) -> PaletteResults<Item> {
        let normalized = PaletteText.normalize(query)
        let parsedShortcut = PaletteText.shortcutQuery(query)
        guard !normalized.isEmpty || parsedShortcut != nil else { return unfiltered(items, recents: recents) }
        var matches: [(item: Item, score: Int, order: Int)] = []
        for (order, item) in items.enumerated() {
            guard let score = PaletteText.score(normalized, shortcut: parsedShortcut, item: item) else { continue }
            matches.append((item, score, order))
        }
        // Once an entry is found by a prefix or a word, the weak matches (letters in order, a piece of a synonym's word)
        // are only noise: « arch » would also bring a « Search » command and a Space named « Hobby ».
        if matches.contains(where: { $0.score >= strongMatch }) { matches.removeAll { $0.score < weakMatchFloor } }
        var scored: [(item: Item, score: Int, order: Int)] = []
        for var match in matches {
            if let rank = recents.ids.firstIndex(of: match.item.id) { match.score += max(0, recentBonus - rank * recentStep) }
            scored.append(match)
        }
        scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.order < $1.order }
        var sections: [PaletteResults<Item>.Section] = []
        for entry in scored {
            if let index = sections.firstIndex(where: { $0.section == entry.item.section }) {
                sections[index].items.append(entry.item)
            } else {
                sections.append(PaletteResults<Item>.Section(section: entry.item.section, items: [entry.item]))
            }
        }
        return PaletteResults(sections: sections)
    }

    /// The selected entry after ↑ (-1) or ↓ (+1): held at the ends, like Spotlight; the first one without a selection.
    public static func moved(_ index: Int?, by step: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        guard let index else { return step >= 0 ? 0 : count - 1 }
        return min(max(index + step, 0), count - 1)
    }

    /// A prefix or a word of the title (`PaletteText.match`, 800 and above).
    static let strongMatch = 800
    /// Kept with a strong match: a substring of a title (600), a word of a synonym (640).
    static let weakMatchFloor = 600

    /// Recent entries shown without a query, at most.
    public static let recentLimit = 5
    private static let recentBonus = 50
    private static let recentStep = 10

    private static func unfiltered<Item: PaletteSearchable>(_ items: [Item], recents: PaletteRecents) -> PaletteResults<Item> {
        let listed = items.filter(\.listedWithoutQuery)
        let recent = recents.ids.compactMap { id in listed.first { $0.id == id } }.prefix(recentLimit)
        let recentIDs = Set(recent.map(\.id))
        var sections: [PaletteResults<Item>.Section] = []
        if !recent.isEmpty {
            sections.append(PaletteResults<Item>.Section(section: .recent, items: Array(recent)))
        }
        for section in Item.Section.allCases where section != .recent {
            let entries = listed.filter { $0.section == section && !recentIDs.contains($0.id) }
            if !entries.isEmpty { sections.append(PaletteResults<Item>.Section(section: section, items: entries)) }
        }
        return PaletteResults(sections: sections)
    }
}

/// Normalization and scoring of the fuzzy search.
enum PaletteText {
    /// Lowercase, without accents nor ligatures (« Épingler » → « epingler », « cœur » → « coeur »), punctuation as
    /// spaces, spaces collapsed.
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .replacingOccurrences(of: "œ", with: "oe").replacingOccurrences(of: "æ", with: "ae")
        let spaced = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(spaced).split(separator: " ").joined(separator: " ")
    }

    /// The query read as a shortcut (« ⇧⌘K », « cmd shift k », « maj+cmd+k », « # »): its symbols in a menu's order, or
    /// `nil` when it is not one. A single letter is not one (it searches a title). English and French modifier names.
    static func shortcutQuery(_ query: String) -> String? {
        let aliases: [String: Shortcut.Modifier] = [
            "⌘": .command, "cmd": .command, "command": .command, "commande": .command, "pomme": .command,
            "⇧": .shift, "shift": .shift, "maj": .shift, "majuscule": .shift,
            "⌥": .option, "opt": .option, "option": .option, "alt": .option,
            "⌃": .control, "ctrl": .control, "control": .control, "controle": .control,
        ]
        var modifiers: Set<Shortcut.Modifier> = []
        var key: Character?
        var token = ""
        func flush() -> Bool {
            defer { token = "" }
            guard !token.isEmpty else { return true }
            let lower = token.lowercased()
            if let modifier = aliases[lower] {
                modifiers.insert(modifier)
                return true
            }
            guard token.count == 1, key == nil, let character = token.first else { return false }
            key = character
            return true
        }
        for character in query {
            if character == " " || character == "+" || character == "-" {
                guard flush() else { return nil }
            } else if aliases[String(character)] != nil {
                guard flush() else { return nil }
                token = String(character)
                guard flush() else { return nil }
            } else {
                token.append(character)
            }
        }
        guard flush(), let key else { return nil }
        if modifiers.isEmpty, key.isLetter || key.isNumber { return nil }
        return Shortcut(Character(key.lowercased()), modifiers).symbols
    }

    static func score<Item: PaletteSearchable>(_ query: String, shortcut: String?, item: Item) -> Int? {
        var best: Int?
        if !query.isEmpty { best = match(query, in: normalize(item.title)) }
        for synonym in item.synonyms where !query.isEmpty {
            if let score = match(query, in: normalize(synonym)) {
                best = max(best ?? 0, score * 8 / 10)
            }
        }
        if let shortcut, let symbols = item.shortcut?.symbols, shortcut == symbols {
            best = max(best ?? 0, 950)
        }
        return best
    }

    /// Exact 1000, prefix 900, each word of the query at the start of a word 800; from two letters only (« e » does not
    /// find everything), substring 600, then letters in order from the start of a word (500 at most).
    static func match(_ query: String, in text: String) -> Int? {
        guard !text.isEmpty else { return nil }
        if text == query { return 1000 }
        if text.hasPrefix(query) { return 900 }
        let words = text.split(separator: " ")
        let tokens = query.split(separator: " ")
        if tokens.allSatisfy({ token in words.contains { $0.hasPrefix(token) } }) { return 800 }
        let letters = Array(query.replacingOccurrences(of: " ", with: ""))
        guard letters.count >= 2 else { return nil }
        if text.contains(query) { return 600 }
        return subsequence(letters, in: Array(text))
    }

    /// The query's letters in order, the first at the start of a word; a bonus for consecutive letters and word starts,
    /// a penalty for gaps.
    private static func subsequence(_ letters: [Character], in text: [Character]) -> Int? {
        var best: Int?
        for start in text.indices where text[start] == letters[0] && (start == 0 || text[start - 1] == " ") {
            var score = 300
            var position = start
            var previous = start
            var matched = 1
            for letter in letters.dropFirst() {
                guard let next = text[(position + 1)...].firstIndex(of: letter) else { break }
                if next == previous + 1 { score += 15 } else { score -= min(next - previous, 10) }
                if text[next - 1] == " " { score += 20 }
                previous = next
                position = next
                matched += 1
            }
            guard matched == letters.count else { continue }
            best = max(best ?? 0, min(score, 500))
        }
        return best
    }
}
