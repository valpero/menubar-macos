import Foundation

final class APIClient {
    static let shared = APIClient()
    private init() {}

    static let base = URL(string: "https://valpero.com")!

    var apiKey: String = ""

    private var decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    // MARK: - Core request

    private func request<T: Decodable>(_ path: String, key: String? = nil) async throws -> T {
        let usedKey = key ?? apiKey
        guard !usedKey.isEmpty else { throw AppError.invalidKey }

        guard let url = URL(string: path, relativeTo: APIClient.base) else {
            throw AppError.networkError("Bad URL: \(path)")
        }

        var req = URLRequest(url: url, timeoutInterval: 12)
        req.setValue("Bearer \(usedKey)", forHTTPHeaderField: "Authorization")
        req.setValue("ValperoMenuBar/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw AppError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AppError.networkError("No HTTP response")
        }
        if http.statusCode == 401 { throw AppError.invalidKey }
        guard (200..<300).contains(http.statusCode) else {
            throw AppError.networkError("HTTP \(http.statusCode)")
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AppError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Endpoints

    func fetchMonitors() async throws -> [Monitor] {
        let resp: SitesResponse = try await request("/api/sites")
        return resp.sites
    }

    func fetchIncidents(limit: Int = 20) async throws -> [Incident] {
        return try await request("/api/incidents?limit=\(limit)")
    }

    func fetchAgents() async throws -> [ServerAgent] {
        return try await request("/api/agents")
    }

    func fetchHeartbeats() async throws -> [Heartbeat] {
        return try await request("/api/heartbeats")
    }

    // MARK: - Key validation

    /// Returns true if the key is valid (HTTP 200), false if invalid (HTTP 401),
    /// throws on network errors.
    func validateKey(_ key: String) async throws -> Bool {
        do {
            let _: SitesResponse = try await request("/api/sites", key: key)
            return true
        } catch AppError.invalidKey {
            return false
        }
        // Other errors (network etc.) propagate
    }
}
