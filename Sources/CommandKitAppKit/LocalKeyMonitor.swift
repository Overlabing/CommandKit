#if canImport(AppKit)
import AppKit
import CommandKit

/// The app's single entry point for triage keys: every key press of the app goes through `handler` before the first
/// responder. A local monitor rather than a key handler per view, so that a list (whose type-select would take letters)
/// and a web view go through the same rule. `handler` returns true when it took the press, which then goes no further;
/// false lets the press follow its usual path, untouched. A press that is no key (a dead key) is never offered.
@MainActor
public final class LocalKeyMonitor {
    private var monitor: Any?
    private let handler: @MainActor (NSEvent, Shortcut) -> Bool

    public init(handler: @escaping @MainActor (NSEvent, Shortcut) -> Bool) {
        self.handler = handler
    }

    public var isInstalled: Bool { monitor != nil }

    /// Starts reading key presses; a second call does nothing.
    public func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // AppKit calls a local monitor on the main thread, during `sendEvent`: the event never leaves the main
            // actor, hence `nonisolated(unsafe)` to hand it over.
            nonisolated(unsafe) let event = event
            let taken = MainActor.assumeIsolated { self?.offer(event) ?? false }
            return taken ? nil : event
        }
    }

    public func remove() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }

    /// What the monitor does with a press: true when `handler` took it.
    public func offer(_ event: NSEvent) -> Bool {
        guard let shortcut = Shortcut(event: event) else { return false }
        return handler(event, shortcut)
    }
}
#endif
