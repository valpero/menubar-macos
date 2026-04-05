import Foundation

// MARK: - Monitor

struct SitesResponse: Codable {
    let sites: [Monitor]
    let total: Int
}

struct Monitor: Codable, Identifiable {
    let id: Int
    let name: String?
    let url: String
    let checkType: String
    let isUp: Bool
    let uptime30d: Double?
    let uptime24h: Double?
    let lastResponseTime: Int?   // milliseconds
    let lastCheck: String?
    let isActive: Bool

    var displayName: String { name ?? url }

    var dashboardURL: URL {
        URL(string: "https://valpero.com/dashboard/monitors/\(id)")!
    }

    enum CodingKeys: String, CodingKey {
        case id, name, url
        case checkType        = "check_type"
        case isUp             = "is_up"
        case uptime30d        = "uptime_30d"
        case uptime24h        = "uptime_24h"
        case lastResponseTime = "last_response_time"
        case lastCheck        = "last_check"
        case isActive         = "is_active"
    }
}

// MARK: - Incident

struct Incident: Codable, Identifiable {
    let id: Int
    let siteId: Int
    let siteName: String
    let siteUrl: String
    let startedAt: String
    let resolvedAt: String?
    let durationSeconds: Int?
    let cause: String?
    let isResolved: Bool

    var formattedDuration: String {
        guard let secs = durationSeconds else { return "" }
        if secs < 60 { return "\(secs)s" }
        if secs < 3600 { return "\(secs / 60)m" }
        return "\(secs / 3600)h \((secs % 3600) / 60)m"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case siteId         = "site_id"
        case siteName       = "site_name"
        case siteUrl        = "site_url"
        case startedAt      = "started_at"
        case resolvedAt     = "resolved_at"
        case durationSeconds = "duration_seconds"
        case cause
        case isResolved     = "is_resolved"
    }
}

// MARK: - Server Agent

struct ServerAgent: Codable, Identifiable {
    let id: String
    let name: String?
    let hostname: String?
    let os: String?
    let arch: String?
    let isRegistered: Bool
    let isOnline: Bool
    let lastSeenAt: String?
    let cpuPct: Double?
    let ramUsedMb: Int?
    let ramTotalMb: Int?

    var displayName: String { name ?? hostname ?? id }

    var ramPct: Double? {
        guard let used = ramUsedMb, let total = ramTotalMb, total > 0 else { return nil }
        return Double(used) / Double(total) * 100
    }

    var dashboardURL: URL {
        URL(string: "https://valpero.com/dashboard/servers/\(id)")!
    }

    enum CodingKeys: String, CodingKey {
        case id, name, hostname, os, arch
        case isRegistered = "is_registered"
        case isOnline     = "is_online"
        case lastSeenAt   = "last_seen_at"
        case cpuPct       = "cpu_pct"
        case ramUsedMb    = "ram_used_mb"
        case ramTotalMb   = "ram_total_mb"
    }
}

// MARK: - Heartbeat

struct Heartbeat: Codable, Identifiable {
    let id: Int
    let name: String
    let status: String   // "up" | "down" | "new"
    let interval: Int
    let gracePeriod: Int
    let lastPingAt: String?
    let isActive: Bool

    var isUp: Bool { status == "up" }
    var isNew: Bool { status == "new" }

    enum CodingKeys: String, CodingKey {
        case id, name, status, interval
        case gracePeriod = "grace_period"
        case lastPingAt  = "last_ping_at"
        case isActive    = "is_active"
    }
}

// MARK: - App Error

enum AppError: LocalizedError {
    case invalidKey
    case networkError(String)
    case decodingError(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidKey:           return "Invalid API key — check your Valpero settings."
        case .networkError(let m):  return "Network error: \(m)"
        case .decodingError(let m): return "Data error: \(m)"
        case .unknown:              return "An unexpected error occurred."
        }
    }
}
