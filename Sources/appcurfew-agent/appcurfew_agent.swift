// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import ArgumentParser

@main
struct AppCurfewAgent: AsyncParsableCommand {
    @Option(help: "Path to the config file")
    var configPath: String = "/etc/appcurfew/config.json"

    func run() async throws {
        let configURL = URL(fileURLWithPath: configPath)
        let data = try Data(contentsOf: configURL)
        let config = try JSONDecoder().decode(AgentConfig.self, from: data)

        guard let baseURL = URL(string: config.serverURL) else {
            throw ValidationError("Invalid serverURL in config: \(config.serverURL)")
        }

        let apiClient = APIClient(baseURL: baseURL, apiKey: config.apiKey)
        let flatpakInspector = FlatpakInspector()
        let agent = Agent(apiClient: apiClient, flatpakInspector: flatpakInspector)

        print("AppCurfew agent starting, polling every \(agent.pollInterval)s...")
        await agent.run()
    }
}
