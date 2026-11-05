# CommandKit

Keyboard shortcuts and command palette logic shared by Overlabing's Mac and iOS apps. A Swift package for macOS 26 and
iOS 26, Swift 6 with strict concurrency, MIT licensed. Its only dependency is
[AppSupportKit](https://github.com/Overlabing/AppSupportKit) (`Localization`).

The kit never names an app and never holds a command. Each app brings its command identifiers, their titles and
symbols, its shortcut set files, its binding rules, its triage focus, the palette's entries and when they are available,
and the key it stores the bindings under. The kit's own strings use English keys, with French in its String Catalog.

| Product | What it holds |
|---|---|
| `CommandKit` | `CommandIdentifier`; `Shortcut` (notation, menu symbols, normalization of a typed key, keys that edit text); `ShortcutSet` (data files, inheritance from a parent set, each key's source note, absent commands and why); `ShortcutBindings` (a set plus the user's overrides, the menu key, conflicts, recording, unbinding, storage); `BindingRules`; `ShortcutReference` (sections for a help panel and a settings pane); `TriageTable` (a key and a focus give a command); `PaletteSearch`, `PaletteResults`, `PaletteRecents` (accent-tolerant fuzzy ranking, shortcut queries, recent entries) |
| `CommandKitAppKit` | macOS only: `Shortcut(event:)`, the modifier flags both ways, and `LocalKeyMonitor`, the app's single entry point for triage keys |

## Using it

```swift
.package(url: "https://github.com/Overlabing/CommandKit", exact: "0.1.0"),
```

An app declares its commands and reads its sets once:

```swift
enum CommandID: String, CommandIdentifier { case archive, reply, settings /* … */ }

let standard = try ShortcutSet<CommandID>(data: ownFile, expecting: "standard", inheritingFrom: nil)
let vendor = try ShortcutSet<CommandID>(data: vendorFile, expecting: "vendor", inheritingFrom: standard)
var bindings = try ShortcutBindings.read(stored, sets: [standard, vendor], standard: ShortcutBindings(set: standard)).bindings
try bindings.record(Shortcut("y", []), for: .archive, rules: rules)
store(try bindings.data(), under: "myapp.shortcuts")
```

## Shortcut set files

```json
{
  "id": "vendor",
  "source": "https://example.com/keyboard-shortcuts",
  "checked": "2026-10-27",
  "note": "How the page was read.",
  "shortcuts": {
    "reply": ["⌘R", { "shortcut": "r", "from": "Reply (R)" }],
    "archive": ["e"]
  },
  "notFound": { "snooze": "The page has no snooze." }
}
```

A key is written as a macOS menu writes it: the modifiers in the order ⌃⌥⇧⌘, then one key (a character, ↑ ↓ ← → ↩ ⌫ ⌦, or
`Space`). A bare capital letter is typed with Shift (`⇧I`); Shift on a bare symbol is written as the symbol (`#`, not
`⇧3`). The first key of a command is its menu key, unless it edits text (⌫, ⌘↓, ⌃E), which only a triage table reads. `Shortcut.editsText` follows the Cocoa text
system's bindings (`StandardKeyBinding.dict`): ⌫ and ⌦ alone or with ⇧, ⌥, ⌃ or ⌘ alone; ⌘ or ⇧⌘ with an arrow; ⌃ with
an Emacs letter. ⇧⌘⌫ (Empty Trash), ⌥⌘⌫, ⌃⌘← and ⌃⌘→ (Show Previous and Next Space), ⌥⌘← and ⌥⌘→ are menu keys.
⌥ with an arrow is a menu key too, though the text system binds it (word moves): apps use ⌥↑ and ⌥↓ for the previous and
next message.
Each key may carry `from`, where it comes from. `notFound` lists the commands the source was checked for and does not
document, either as a list or with a reason each; they inherit the parent set's keys, minus any key the set already
gives to another command, and a reference marks them. Commands the parent has and the file does not mention inherit
silently.

A command listed under `shortcuts` with an empty list (`"snooze": []`) is unassigned: it receives nothing from the
parent set. A command the file does not mention inherits. Mentioning is what stops inheritance, not having keys. The
user's overrides follow the same rule: `overrides[command] = []` means no shortcut (`isOverridden` is true, `keys` is
empty, and the set's keys are not used), while a command with no override follows the set. An empty override is stored
as `"command": []` and read back unchanged.

`unbind(_:rules:)` writes that empty override, the user's explicit « no shortcut »: the command's keys, the set's
included, are gone and free for another command, `isOverridden` is true and `isInherited` false. It does so even for a
command the set already leaves without a key. A command `BindingRules.fixed` keeps cannot be unbound: it throws
`.notRebindable`, as `record` does, and nothing changes. `reset(_:)` undoes it.

```swift
try bindings.unbind(.snooze, rules: rules)   // no shortcut for Snooze
bindings.reset(.snooze)                      // the set's keys again
```

## Rules

`BindingRules` is data the app gives: the commands whose keys never change, the reserved keys, keys only one command
may take, the commands used while typing (their key needs ⌘ or ⌃), the commands a triage table reads (only they may take
a key that edits text), and the commands whose shortcut reaches the menu before the focused view. Escape and Tab are
always reserved. A recorded key is also refused when another command has it: menu shortcuts work everywhere, so a key
is unique in the whole app.

## Developing

`./check.sh` runs the tests with French then English pinned, builds for the iOS simulator, and runs AppTooling's leak
scan over the tree and the whole history. It fetches AppTooling at the version pinned in `scripts/apptooling.pin`.
CI runs the same script.

Releases are annotated tags `vX.Y.Z`, never moved. Apps pin `exact:`; kits depend on each other by patch range
(`.upToNextMinor(from:)`), so an app's exact pin of AppSupportKit decides the version built.
