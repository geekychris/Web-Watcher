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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup Login Item (macOS 13+)
        do {
            try SMAppService.mainApp.register()
        } catch {
            print("Failed to register for login startup: \(error)")
        }
        
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
