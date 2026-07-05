//
//  APIClient.swift
//  appcurfew-agent
//
//  Created by Akash Kallumkal on 2026-07-03.
//

import Foundation

struct APIClient {
    let baseURL: URL
    let apiKey: String

    func fetchAllowedApps() async throws -> [String] {
        var request = URLRequest(url: baseURL.appendingPathComponent("allowed-apps"))
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([String].self, from: data)
    }

    func reportUsage(appIdentifier: String, secondsUsed: Int) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("usage-report"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(UsageReportRequest(appIdentifier: appIdentifier, secondsUsed: secondsUsed))

        _ = try await URLSession.shared.data(for: request)
    }

    func reportInstalledApps(_ apps: [InstalledAppReport]) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("installed-apps"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(InstalledAppsRequest(apps: apps))

        _ = try await URLSession.shared.data(for: request)
    }
}
