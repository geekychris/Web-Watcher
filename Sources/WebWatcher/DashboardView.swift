import SwiftUI
import WebKit

struct DashboardView: View {
    @ObservedObject var store: Store
    var scheduler: Scheduler
    
    @State private var newUrl = ""
    @State private var newSelector = ""
    @State private var newInterval = "60"
    @State private var newIntervalUnit = "minutes"
    @State private var showingAbout = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Web Watcher")
                    .font(.headline)
                Spacer()
                Button("Check Now") {
                    scheduler.forceCheckAll()
                }
                .buttonStyle(.borderedProminent)
                
                Button("About") {
                    showingAbout = true
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Add Form
            VStack(alignment: .leading, spacing: 8) {
                Text("Add New Watcher").font(.subheadline).bold()
                
                TextField("URL (https://...)", text: $newUrl)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    TextField("CSS Selector (Optional)", text: $newSelector)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Interval", text: $newInterval)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                    
                    Picker("", selection: $newIntervalUnit) {
                        Text("mins").tag("minutes")
                        Text("hours").tag("hours")
                    }
                    .labelsHidden()
                    .frame(width: 80)
                }
                
                Button("Add Watcher") {
                    addWatcher()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(newUrl.isEmpty)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // List
            ScrollView {
                LazyVStack(spacing: 12) {
                    if store.items.isEmpty {
                        Text("No watchers added yet.")
                            .foregroundColor(.secondary)
                            .padding(.top, 20)
                    } else {
                        ForEach(store.items) { item in
                            WatcherRow(item: item, store: store)
                        }
                    }
                }
                .padding()
            }
            .background(Color(nsColor: .underPageBackgroundColor))
        }
        .frame(width: 450, height: 600)
        .alert("About", isPresented: $showingAbout) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Copyright © 2026 Chris Collins\nchris@hitorro.com")
        }
    }
    
    private func addWatcher() {
        guard !newUrl.isEmpty else { return }
        let interval = Int(newInterval) ?? 60
        let totalMinutes = newIntervalUnit == "hours" ? interval * 60 : interval
        
        let item = WatcherItem(
            url: newUrl,
            selector: newSelector,
            intervalMinutes: max(1, totalMinutes)
        )
        store.add(item: item)
        scheduler.checkAll()
        
        newUrl = ""
        newSelector = ""
        newInterval = "60"
    }
}

struct WatcherRow: View {
    let item: WatcherItem
    @ObservedObject var store: Store
    @State private var showHistory = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.url)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                Button(action: openAuthWindow) {
                    Image(systemName: "globe")
                }
                .buttonStyle(.plain)
                .help("View Rendered Page / Authenticate")
                
                Button(action: { store.delete(id: item.id) }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
            
            HStack {
                let displayInterval = (item.intervalMinutes >= 60 && item.intervalMinutes % 60 == 0) ? "\(item.intervalMinutes / 60)h" : "\(item.intervalMinutes)m"
                Menu(displayInterval) {
                    Button("1 minute") { updateInterval(1) }
                    Button("5 minutes") { updateInterval(5) }
                    Button("15 minutes") { updateInterval(15) }
                    Button("30 minutes") { updateInterval(30) }
                    Button("1 hour") { updateInterval(60) }
                    Button("2 hours") { updateInterval(120) }
                    Button("12 hours") { updateInterval(720) }
                    Button("24 hours") { updateInterval(1440) }
                }
                .menuStyle(.borderlessButton)
                .font(.caption2)
                .fixedSize()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(4)
                
                if !item.selector.isEmpty {
                    Text(item.selector)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                if let lastFetch = item.lastFetch {
                    Text("Last check: \(lastFetch.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Value:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(item.lastContent ?? "Waiting for first check...")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.green)
                    .lineLimit(3)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.1))
            .cornerRadius(6)
            
            if !item.history.isEmpty {
                Button(action: {
                    withAnimation { showHistory.toggle() }
                }) {
                    HStack {
                        Text("Show History")
                        Image(systemName: showHistory ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                if showHistory {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(item.history.prefix(5)) { hist in
                            VStack(alignment: .leading) {
                                Text(hist.timestamp, style: .time)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                Text(hist.content)
                                    .font(.system(size: 10, design: .monospaced))
                            }
                        }
                    }
                    .padding(.leading, 8)
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func updateInterval(_ newInterval: Int) {
        var updated = item
        updated.intervalMinutes = newInterval
        store.update(item: updated)
    }
    
    private func openAuthWindow() {
        if let url = URL(string: item.url) {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered, defer: false)
            window.center()
            window.title = "Rendered Page - \(item.url)"
            
            let webView = WKWebView(frame: .zero, configuration: {
                let config = WKWebViewConfiguration()
                config.processPool = Scheduler.sharedProcessPool
                config.websiteDataStore = Scheduler.sharedDataStore
                return config
            }())
            
            window.contentView = webView
            window.makeKeyAndOrderFront(nil)
            
            webView.load(URLRequest(url: url))
        }
    }
}
