//
//  APIClient.swift
//  appcurfew-status
//
//  Created by Akash Kallumkal on 2026-07-07.
//
//  Minimal read-only client — only the allowed-apps fetch is needed here.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct APIClient {
    let baseURL: URL
    let apiKey: String

    func fetchAllowedApps() async throws -> [AllowedAppStatus] {
        var request = URLRequest(url: baseURL.appendingPathComponent("allowed-apps"))
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([AllowedAppStatus].self, from: data)
    }
}
