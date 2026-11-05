/// An app's command identifiers, usually a `String` enum. The raw value names the command in shortcut set files and in
/// stored bindings; `allCases` is the registry order, which settles ties (the first command keeps a key bound twice).
public protocol CommandIdentifier: RawRepresentable<String>, Hashable, Sendable, CaseIterable
where AllCases: Sendable {}
