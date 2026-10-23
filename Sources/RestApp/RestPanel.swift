import AppKit

/// A panel can receive button/keyboard interaction without activating the regular
/// application's desktop Space. The same policy is used before and after rest.
final class RestPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    static var currentScreen: NSScreen? {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    }
    func configureForCurrentSpace() {
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true
        var behavior = collectionBehavior
        behavior.subtract([.moveToActiveSpace,.fullScreenPrimary,.fullScreenNone,.primary,.auxiliary])
        behavior.formUnion([.canJoinAllSpaces,.fullScreenAuxiliary,.canJoinAllApplications,.ignoresCycle])
        collectionBehavior = behavior
    }
    func placeAsCard() {
        guard let screen = Self.currentScreen else { return }
        let area = screen.visibleFrame
        setFrameOrigin(NSPoint(x:area.maxX-frame.width-20,y:area.maxY-frame.height-20))
    }
    func centerOnCurrentScreen() {
        guard let screen = Self.currentScreen else { center(); return }
        let area = screen.visibleFrame
        setFrameOrigin(NSPoint(x:area.midX-frame.width/2,y:area.midY-frame.height/2))
    }
    func showWithoutSwitchingSpace(focus: Bool = false) {
        configureForCurrentSpace()
        orderFrontRegardless()
        if focus { makeKey() }
    }
}
