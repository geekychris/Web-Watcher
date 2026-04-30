import Foundation
import SwiftSoup
import WebKit

class Scheduler: ObservableObject {
    var store: Store
    private var timer: Timer?
    
    // Shared process pool and data store so if we open a WebView to authenticate, we share cookies.
    static let sharedProcessPool = WKProcessPool()
    static let sharedDataStore = WKWebsiteDataStore.default()
    
    init(store: Store) {
        self.store = store
    }
    
    func start() {
        requestNotificationPermission()
        
        // Check every minute
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkAll()
        }
        
        // Also check immediately
        checkAll()
    }
    
    func checkAll() {
        Task {
            for item in store.items {
                let now = Date()
                if let lastFetch = item.lastFetch {
                    let nextFetch = lastFetch.addingTimeInterval(TimeInterval(item.intervalMinutes * 60))
                    if now < nextFetch { continue }
                }
                
                await fetchAndProcess(item: item)
            }
        }
    }
    
    func forceCheckAll() {
        Task {
            for item in store.items {
                await fetchAndProcess(item: item)
            }
        }
    }
    
    private func fetchAndProcess(item: WatcherItem) async {
        guard let url = URL(string: item.url) else { return }
        
        do {
            // We can use a simple URLSession, but to share cookies with WKWebView, we need to extract cookies from WKWebsiteDataStore
            let cookies = await getCookies(for: url)
            
            var request = URLRequest(url: url)
            if !cookies.isEmpty {
                let headerFields = HTTPCookie.requestHeaderFields(with: cookies)
                if let cookieHeader = headerFields["Cookie"] {
                    request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
                }
            }
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                print("Error: HTTP \(httpResponse.statusCode)")
                return
            }
            
            guard let htmlString = String(data: data, encoding: .utf8) else { return }
            
            let extractedText = try extractText(from: htmlString, selector: item.selector)
            
            await MainActor.run {
                var updatedItem = item
                updatedItem.lastFetch = Date()
                
                if let oldContent = updatedItem.lastContent, !oldContent.isEmpty, oldContent != extractedText {
                    // Changed!
                    showNotification(title: "Webpage Changed!", body: "Change detected at \(item.url)")
                    updatedItem.history.insert(HistoryItem(timestamp: Date(), content: extractedText), at: 0)
                    if updatedItem.history.count > 50 {
                        updatedItem.history = Array(updatedItem.history.prefix(50))
                    }
                }
                
                updatedItem.lastContent = extractedText
                store.update(item: updatedItem)
            }
            
        } catch {
            print("Failed to fetch \(item.url): \(error)")
        }
    }
    
    private func extractText(from html: String, selector: String) throws -> String {
        let document = try SwiftSoup.parse(html)
        if selector.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return try document.body()?.text() ?? ""
        } else {
            let elements = try document.select(selector)
            if elements.isEmpty() {
                return "(Selector '\(selector)' not found)"
            }
            return try elements.text()
        }
    }
    
    private func getCookies(for url: URL) async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                Scheduler.sharedDataStore.httpCookieStore.getAllCookies { cookies in
                    let urlCookies = cookies.filter { cookie in
                        url.host?.contains(cookie.domain) ?? false
                    }
                    continuation.resume(returning: urlCookies)
                }
            }
        }
    }
    
    private func requestNotificationPermission() {
        // No permission request needed for osascript
    }
    
    private func showNotification(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
}
