// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import ArgumentParser

@main
struct AppCurfewStatus: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "appcurfew-status",
        abstract: "Show remaining screen time for each allowed app."
    )

    // Defaults to the current user's own config. A child runs `appcurfew-status`
    // with no arguments and it reads /etc/appcurfew/<their-username>.json — the
    // same file the agent uses for that child. See the permission notes below.
    @Option(help: "Path to the config file")
    var configPath: String = "/etc/appcurfew/\(NSUserName()).json"

    func run() async throws {
        let configURL = URL(fileURLWithPath: configPath)

        let data: Data
        do {
            data = try Data(contentsOf: configURL)
        } catch {
            throw ValidationError("""
                Couldn't read config at \(configPath): \(error.localizedDescription)
                If this is another child's config, or the file isn't readable by \
                your user, pass --config-path pointing at your own config file.
                """)
        }

        let config = try JSONDecoder().decode(AgentConfig.self, from: data)

        guard let baseURL = URL(string: config.serverURL) else {
            throw ValidationError("Invalid serverURL in config: \(config.serverURL)")
        }

        let apiClient = APIClient(baseURL: baseURL, apiKey: config.apiKey)
        let statuses = try await apiClient.fetchAllowedApps()

        guard !statuses.isEmpty else {
            print("No allowed apps configured.")
            return
        }

        for status in statuses {
            print("\(status.appIdentifier) — \(describe(status.remainingSeconds))")
        }
    }

    /// Formats remaining seconds as "12m 30s left", or "no limit" when nil.
    private func describe(_ remainingSeconds: Int?) -> String {
        guard let remainingSeconds else { return "no limit" }
        let clamped = max(0, remainingSeconds)
        let minutes = clamped / 60
        let seconds = clamped % 60
        return "\(minutes)m \(seconds)s left"
    }
}
