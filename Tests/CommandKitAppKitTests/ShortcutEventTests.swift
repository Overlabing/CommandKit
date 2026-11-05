#if canImport(AppKit)
import AppKit
import CommandKit
import CommandKitAppKit
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
}
#endif
