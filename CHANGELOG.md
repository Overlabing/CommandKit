# Changelog

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
