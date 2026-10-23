import AppKit
import RestCore
import SwiftUI

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var model: AppModel!
    private var item: NSStatusItem!
    private let popover = NSPopover()
    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainMenu = NSMenu()
        let appEntry = NSMenuItem(); mainMenu.addItem(appEntry)
        let appMenu = NSMenu(); appEntry.submenu = appMenu
        appMenu.addItem(withTitle: "Скрыть Blinkwell", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let panelEntry = appMenu.addItem(withTitle: "Показать панель", action: #selector(togglePanel), keyEquivalent: "p")
        panelEntry.target = self; panelEntry.keyEquivalentModifierMask = [.command, .shift]
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Завершить Blinkwell", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = mainMenu
        model = AppModel()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "leaf", accessibilityDescription: "Blinkwell — отдых от экрана")
        item.button?.toolTip = "Blinkwell — забота о себе за экраном"
        item.button?.target = self; item.button?.action = #selector(togglePanel)
        popover.behavior = .transient
        popover.delegate = self
        let controller = NSHostingController(rootView: PanelView(model: model) { [weak self] in self?.popover.performClose(nil) })
        controller.sizingOptions = [.preferredContentSize]
        popover.contentViewController = controller
        model.showMain()
    }
    @objc private func togglePanel() {
        guard let button = item.button else { return }
        if popover.isShown { popover.performClose(nil); return }
        model.tick()
        popover.animates = model.preferences.animations
        // A status-item popover must stay in the user's current Space. Activating
        // the regular app here switches to its main window's Space and closes a
        // transient popover when another app is full screen.
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        configurePopoverWindow()
        popover.contentViewController?.view.window?.makeKey()
    }
    func popoverWillShow(_ notification: Notification) { configurePopoverWindow() }
    func popoverDidShow(_ notification: Notification) { configurePopoverWindow() }
    private func configurePopoverWindow() {
        guard let window = popover.contentViewController?.view.window else { return }
        // Preserve AppKit's popover behavior while replacing mutually exclusive
        // Space/full-screen flags. No global activation-policy or Dock changes.
        var behavior = window.collectionBehavior
        behavior.subtract([.moveToActiveSpace, .fullScreenPrimary, .fullScreenNone, .primary, .auxiliary])
        behavior.formUnion([.canJoinAllSpaces, .fullScreenAuxiliary, .canJoinAllApplications])
        if window.collectionBehavior != behavior { window.collectionBehavior = behavior }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { model.flush() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model.showMain(); return true
    }
}

@main enum PauseApplication {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.regular); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
