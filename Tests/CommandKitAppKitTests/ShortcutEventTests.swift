#if canImport(AppKit)
import AppKit
import CommandKit
@testable import CommandKitAppKit
import Testing

@MainActor
@Suite struct ShortcutEventTests {
    /// An event built in memory, never posted: nothing reaches a window or another app. `keyCode` is the US layout's,
    /// which `characters(byApplyingModifiers:)` reads.
    private func press(
        _ characters: String, ignoring base: String, _ flags: NSEvent.ModifierFlags, keyCode: UInt16 = 0
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil,
            characters: characters, charactersIgnoringModifiers: base, isARepeat: false, keyCode: keyCode)!
    }

    @Test func aPressGivesTheShortcutTheBindingsWrite() {
        #expect(Shortcut(event: press("#", ignoring: "#", [.shift])) == Shortcut("#", []))
        #expect(Shortcut(event: press("e", ignoring: "e", [.command], keyCode: 14)) == Shortcut("e", [.command]))
        #expect(Shortcut(event: press("\u{7F}", ignoring: "\u{7F}", [.command], keyCode: 51)) == Shortcut(Shortcut.delete, [.command]))
        #expect(Shortcut(event: press("", ignoring: "", [.option])) == nil)
    }

    @Test func capsLockAndFunctionAreNotModifiers() {
        #expect(Shortcut.modifiers([.command, .capsLock, .function, .numericPad]) == [.command])
        #expect(Shortcut.modifiers([.command, .shift, .option, .control]) == [.command, .shift, .option, .control])
    }

    @Test func flagsRoundTrip() {
        for modifiers: Set<Shortcut.Modifier> in [[], [.command], [.shift, .command], [.control, .option, .shift, .command]] {
            #expect(Shortcut.modifiers(Shortcut("k", modifiers).modifierFlags) == modifiers)
        }
    }

    @Test func theMonitorOffersOnlyKeysAndTellsWhetherTheHandlerTookThem() {
        var offered: [Shortcut] = []
        let monitor = LocalKeyMonitor { _, shortcut in
            offered.append(shortcut)
            return shortcut == Shortcut("e", [])
        }
        #expect(monitor.offer(press("e", ignoring: "e", [])))
        #expect(!monitor.offer(press("j", ignoring: "j", [])))
        #expect(!monitor.offer(press("", ignoring: "", [.option])))
        #expect(offered == [Shortcut("e", []), Shortcut("j", [])])
        #expect(!monitor.isInstalled)
    }

    /// A fake AppKit registration that counts what is added and removed.
    @MainActor private final class Registry {
        var live = 0
        var added = 0
        var removed = 0
        func monitor(_ handler: @escaping @MainActor (NSEvent, Shortcut) -> Bool = { _, _ in false }) -> LocalKeyMonitor {
            LocalKeyMonitor(
                handler: handler,
                register: { _ in
                    self.live += 1
                    self.added += 1
                    return self.added
                },
                unregister: { _ in
                    self.live -= 1
                    self.removed += 1
                })
        }
    }

    @Test func aFreedMonitorRemovesItsRegistration() {
        let registry = Registry()
        var monitor: LocalKeyMonitor? = registry.monitor()
        monitor?.install()
        monitor?.install()
        #expect(registry.live == 1 && monitor?.isInstalled == true)
        monitor = nil
        #expect(registry.live == 0 && registry.removed == 1)
    }

    @Test func removingByHandThenFreeingRemovesOnce() {
        let registry = Registry()
        var monitor: LocalKeyMonitor? = registry.monitor()
        monitor?.install()
        monitor?.remove()
        #expect(registry.live == 0 && monitor?.isInstalled == false)
        monitor = nil
        #expect(registry.removed == 1)
    }

    @Test func aMonitorNeverInstalledRegistersAndRemovesNothing() {
        let registry = Registry()
        var monitor: LocalKeyMonitor? = registry.monitor()
        #expect(monitor != nil)
        monitor = nil
        #expect(registry.added == 0 && registry.removed == 0)
    }

    @Test func theRealRegistrationComesAndGoesWithTheMonitor() {
        var monitor: LocalKeyMonitor? = LocalKeyMonitor { _, _ in false }
        monitor?.install()
        #expect(monitor?.isInstalled == true)
        monitor?.remove()
        #expect(monitor?.isInstalled == false)
        monitor?.install()
        monitor = nil
    }
}
#endif
