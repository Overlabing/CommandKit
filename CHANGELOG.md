# Changelog

## 0.1.3

### Fixed

- **`Shortcut.editsText` is narrowed to the keys the Cocoa text system binds** (`StandardKeyBinding.dict`,
  AppKit.framework/Resources). It flagged ⌘ with an arrow whatever else was held, and ⌫ with any modifier, so
  `ShortcutBindings.shortcut(_:)` refused as menu keys ⌃⌘← and ⌃⌘→ (Show Previous and Next Space) and ⇧⌘⌫ (Empty
  Trash, Clear History…), and `record` refused them outside the triage. Now:
  - ⌘ with an arrow edits text only with ⇧ or alone (⌘←, ⇧⌘←…). ⌃⌘←, ⌃⌘→, ⌃⌘↑, ⌃⌘↓ and ⌃⇧⌘ arrows become menu keys.
    ⌥⌘ arrows stay menu keys, as before.
  - ⌫ edits text alone and with ⇧, ⌥ or ⌃ (⌥⌫ deleteWordBackward:, ⌃⌫), and with ⌘ alone (⌘⌫
    deleteToBeginningOfLine:). ⌘ with another modifier no longer does: ⇧⌘⌫, ⌥⌘⌫ (Delete Immediately), ⌃⌘⌫ become menu keys.
  - ⌥ with an arrow is bound by the text system (moveWordLeft:, ⌥↓ paragraph end) but stays a menu key, unchanged since
    0.1.0: apps use ⌥↑ and ⌥↓ for the previous and next message. Counting it is a one-line change if an app wants it.
  - The Emacs ⌃ letters are unchanged.
  - Keys that become menu keys: ⌃⌘←, ⌃⌘→, ⌃⌘↑, ⌃⌘↓ (also with ⇧), ⇧⌘⌫, ⌥⌘⌫, ⌃⌘⌫. Keys that stop being menu keys: none
    except ⌦ alone, ⇧⌦, ⌥⌦, ⌃⌦ and ⌘⌦, which 0.1.2 could not even write (see Added).

### Added

- `Shortcut.forwardDelete` (⌦, `NSDeleteFunctionKey`): a key with a notation (`⌥⌦`), kept with its modifiers by
  `Shortcut(characters:modifiers:)`, and counted by `editsText` like ⌫. Before, ⌦ was an unknown character that edited
  nothing. A stored `"⌦"` that 0.1.2 ignored is now read.

### Changed

- The dependency on AppSupportKit is `.upToNextMinor(from: "0.1.1")` instead of an exact pin. Kits depend on each other
  by patch range; apps pin exact (0.1.2 pinned AppSupportKit `exact: "0.1.2"`, which this release replaces).

## 0.1.2

### Added

- `ShortcutBindings.unbind(_:rules:)`, symmetric to `record(_:for:rules:)`: the user's explicit « no shortcut » for a
  command. It writes the empty override (`overrides[command] = []`): the command has no keys, `isOverridden` is true,
  `isInherited` is false, and its former keys are free for another command. The override is written even when the set
  already leaves the command without a key, so the choice is recorded. A command that `rules.fixed` keeps is refused
  with `ShortcutBindingError.notRebindable`, as `record` does, and nothing changes. `reset(_:)` undoes it; the stored
  JSON keeps `"command": []` and reads back unchanged.

### Changed

- The dependency on AppSupportKit moves from `exact: "0.1.1"` to `exact: "0.1.2"`, so that an app pinning both kits at
  0.1.2 resolves one version. CommandKit uses only `Localization`, which did not change.

## 0.1.1

### Fixed

- `LocalKeyMonitor` removes its event monitor when it is freed. The monitor holds the object weakly, so a freed one used
  to leave a pass-through monitor registered for the life of the process.

### Documented and pinned by tests

- A command mentioned with an empty key list is unassigned and receives nothing by inheritance; a command not mentioned
  inherits. This holds in a set file (`"command": []`), in a set built in code (`own[command] = []`), and in the user's
  overrides (`overrides[command] = []`: no keys, `isOverridden` is true, the set is not used). An empty override
  survives `data()` and `read` unchanged. No behavior changed; the rule was already in the code and is now tested.
- `ShortcutBindings` equality and hashing compare the whole value, the set and every override, not the set's id alone.
  Unchanged since 0.1.0; stated here because an app whose own type compared the set id only will see a difference.

## 0.1.0

First release, extracted from one app so that a second can share it.

### Added

- **CommandKit**: `CommandIdentifier`; `Shortcut`, its notation, menu symbols and the normalization of a typed key;
  `ShortcutSet`, read from a data file, with inheritance from a parent set, a source note per key and absent commands
  with their reasons; `ShortcutBindings`, the user's overrides on a set, with the menu key, conflicts, recording under
  `BindingRules`, and storage; `ShortcutReference`; `TriageTable`; `PaletteSearch`, `PaletteResults` and
  `PaletteRecents`.
- **CommandKitAppKit**: `Shortcut(event:)`, modifier flags, and `LocalKeyMonitor`.
