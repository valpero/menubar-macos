import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!
    var popover: NSPopover!
    let appState = AppState()
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ── Status Item ──────────────────────────────────────────
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateTitle(loading: false, key: appState.apiKey, down: 0, total: 0)

        if let btn = statusItem.button {
            btn.target = self
            btn.action = #selector(togglePopover(_:))
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // ── Popover ──────────────────────────────────────────────
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 500)
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PopoverView()
                .environmentObject(appState)
        )

        // ── Subscribe to state changes → update menu bar title ───
        Publishers.CombineLatest3(
            appState.$monitors,
            appState.$isLoading,
            appState.$apiKey
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] monitors, loading, key in
            guard let self else { return }
            let down = monitors.filter { !$0.isUp }.count
            self.updateTitle(loading: loading, key: key, down: down, total: monitors.count)
        }
        .store(in: &cancellables)

        // Close popover when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.popover.performClose(nil)
        }

        // Wire settings action
        appState.onOpenSettings = { [weak self] in self?.openSettings() }

        // Initial refresh
        appState.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let m = eventMonitor { NSEvent.removeMonitor(m) }
    }

    // MARK: - Title update

    private func updateTitle(loading: Bool, key: String, down: Int, total: Int) {
        guard let btn = statusItem.button else { return }
        let attr = NSMutableAttributedString()

        func addText(_ s: String, color: NSColor = .labelColor, size: CGFloat = 12) {
            attr.append(NSAttributedString(string: s, attributes: [
                .foregroundColor: color,
                .font: NSFont.systemFont(ofSize: size, weight: .medium),
            ]))
        }

        if key.isEmpty {
            addText("🔑")
        } else if loading && total == 0 {
            addText("●", color: .tertiaryLabelColor)
            addText(" …", color: .tertiaryLabelColor, size: 11)
        } else if down > 0 {
            addText("⚠", color: NSColor(red: 0.95, green: 0.45, blue: 0.0, alpha: 1))
            addText(" \(down)", color: .labelColor, size: 11)
        } else {
            addText("●", color: NSColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1))
            if total > 0 {
                addText(" \(total)", color: .secondaryLabelColor, size: 11)
            }
        }

        btn.attributedTitle = attr
    }

    // MARK: - Toggle popover

    @objc func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Open Settings (called from PopoverView)

    func openSettings() {
        popover.performClose(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            NSApp.activate(ignoringOtherApps: true)

            if let w = self.settingsWindow, w.isVisible {
                w.makeKeyAndOrderFront(nil)
                return
            }

            let hosting = NSHostingController(
                rootView: SettingsView().environmentObject(self.appState)
            )
            let w = NSWindow(contentViewController: hosting)
            w.title = "Valpero Settings"
            w.styleMask = [.titled, .closable, .resizable]
            w.isReleasedWhenClosed = false
            w.setContentSize(NSSize(width: 480, height: 560))
            w.minSize = NSSize(width: 400, height: 400)
            w.center()
            self.settingsWindow = w
            w.makeKeyAndOrderFront(nil)
        }
    }
}
