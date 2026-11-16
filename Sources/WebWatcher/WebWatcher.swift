import SwiftUI
import AppKit
import ServiceManagement

@main
struct WebWatcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    
    var store: Store!
    var scheduler: Scheduler!
    
    /// Held for the life of the process: a second copy can't take it and quits.
    private var instanceLock: Int32 = -1

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard takeInstanceLock() else {
            print("Web Watcher is already running; quitting this copy.")
            exit(0)
        }

        registerLoginItem()

        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        store = Store()
        scheduler = Scheduler(store: store)
        
        // Setup Popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 450, height: 600)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: DashboardView(store: store, scheduler: scheduler))
        
        // Setup Menu Bar Icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Web Watcher") {
                button.image = image
            } else {
                button.title = "👁️ WW"
            }
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        scheduler.start()
    }
    
    /// One Web Watcher at a time, whichever build it is (the .app, `swift
    /// build`'s binary, Xcode's): an exclusive lock on a file in Application
    /// Support, released by the kernel when the process exits.
    private func takeInstanceLock() -> Bool {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WebWatcher")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        instanceLock = open(dir.appendingPathComponent("instance.lock").path, O_CREAT | O_RDWR, 0o644)
        return instanceLock >= 0 && flock(instanceLock, LOCK_EX | LOCK_NB) == 0
    }

    /// Start at login, but only from the installed app bundle. SMAppService
    /// registers whatever executable is running, so registering from a bare
    /// build (.build/debug, Xcode's DerivedData) on every launch left one
    /// login item per build path, each opening Terminal at login.
    private func registerLoginItem() {
        guard Bundle.main.bundlePath.hasSuffix(".app") else { return }
        let service = SMAppService.mainApp
        guard service.status != .enabled else { return }
        do {
            try service.register()
        } catch {
            print("Failed to register for login startup: \(error)")
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
