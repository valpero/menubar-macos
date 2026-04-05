import Foundation
import Combine
import ServiceManagement

@MainActor
final class AppState: ObservableObject {

    // MARK: - Published state

    @Published var monitors: [Monitor] = []
    @Published var incidents: [Incident] = []
    @Published var agents: [ServerAgent] = []
    @Published var heartbeats: [Heartbeat] = []
    @Published var isLoading = false
    @Published var lastRefresh: Date? = nil
    @Published var error: AppError? = nil
    @Published var apiKey: String = ""

    // MARK: - Preferences (UserDefaults)

    @Published var refreshInterval: Int {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
            restartTimer()
        }
    }
    @Published var showResponseTime: Bool {
        didSet { UserDefaults.standard.set(showResponseTime, forKey: "showResponseTime") }
    }
    @Published var showUptime: Bool {
        didSet { UserDefaults.standard.set(showUptime, forKey: "showUptime") }
    }

    // MARK: - Actions (set by AppDelegate)

    var onOpenSettings: (() -> Void)?

    // MARK: - Computed

    var downCount: Int { monitors.filter { !$0.isUp }.count }
    var openIncidents: [Incident] { incidents.filter { !$0.isResolved } }
    var hasKey: Bool { !apiKey.isEmpty }
    var onlineAgents: [ServerAgent] { agents.filter { $0.isOnline } }

    // MARK: - Private

    private var refreshTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private let client = APIClient.shared

    // MARK: - Init

    init() {
        self.refreshInterval = UserDefaults.standard.integer(forKey: "refreshInterval").nonZero ?? 60
        self.showResponseTime = UserDefaults.standard.object(forKey: "showResponseTime") as? Bool ?? true
        self.showUptime = UserDefaults.standard.object(forKey: "showUptime") as? Bool ?? true

        // Load key from Keychain
        if let key = KeychainManager.load(), !key.isEmpty {
            apiKey = key
            client.apiKey = key
        }

        if hasKey { startTimer() }
    }

    // MARK: - Refresh

    func refresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            await _fetch()
        }
    }

    private func _fetch() async {
        guard hasKey else { return }
        isLoading = true
        error = nil

        async let mon  = client.fetchMonitors()
        async let inc  = client.fetchIncidents()
        async let agt  = client.fetchAgents()
        async let hb   = client.fetchHeartbeats()

        do {
            let (m, i, a, h) = try await (mon, inc, agt, hb)
            monitors   = m
            incidents  = i
            agents     = a
            heartbeats = h
            lastRefresh = Date()
        } catch let e as AppError {
            error = e
            if case .invalidKey = e { apiKey = "" }
        } catch {
            self.error = .networkError(error.localizedDescription)
        }
        isLoading = false
    }

    // MARK: - Save key

    func saveKey(_ key: String) async throws {
        let valid = try await client.validateKey(key)
        guard valid else { throw AppError.invalidKey }
        try KeychainManager.save(key)
        apiKey = key
        client.apiKey = key
        startTimer()
        refresh()
    }

    func clearKey() {
        KeychainManager.delete()
        apiKey = ""
        client.apiKey = ""
        monitors = []; incidents = []; agents = []; heartbeats = []
        stopTimer()
    }

    // MARK: - Launch at Login (macOS 13+)

    var launchAtLogin: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            }
            return false
        }
        set {
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("LaunchAtLogin error: \(error)")
                }
            }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(refreshInterval) * 1_000_000_000)
                if Task.isCancelled { break }
                await _fetch()
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func restartTimer() {
        if hasKey { startTimer() }
    }
}

// MARK: - Helpers

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
