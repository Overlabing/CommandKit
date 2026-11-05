# Changelog

## 0.1.0

First release, extracted from one app so that a second can share it.

### Added

- **CommandKit**: `CommandIdentifier`; `Shortcut`, its notation, menu symbols and the normalization of a typed key;
  `ShortcutSet`, read from a data file, with inheritance from a parent set, a source note per key and absent commands
  with their reasons; `ShortcutBindings`, the user's overrides on a set, with the menu key, conflicts, recording under
  `BindingRules`, and storage; `ShortcutReference`; `TriageTable`; `PaletteSearch`, `PaletteResults` and
  `PaletteRecents`.
- **CommandKitAppKit**: `Shortcut(event:)`, modifier flags, and `LocalKeyMonitor`.
