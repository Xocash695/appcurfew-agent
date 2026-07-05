//
//  Agent.swift
//  appcurfew-agent
//
//  Created by Akash Kallumkal on 2026-07-04.
//
import Foundation

struct Agent {
    let apiClient: APIClient
    let flatpakInspector: FlatpakInspector
    let childUsername: String
    let pollInterval: UInt64 = 10 //every seconds it gets polled to see what is allowed or not

    func runOnce() async throws {
        let installed = try flatpakInspector.listInstalledApps()
        try await apiClient.reportInstalledApps(installed)

        let allowed = try await apiClient.fetchAllowedApps()
        let running = try flatpakInspector.runningAppIdentifiers(forUser: childUsername)

        let disallowedRunning = running.subtracting(allowed)
        for appID in disallowedRunning {
            try flatpakInspector.kill(appID: appID)
            print("Blocked \(appID) — not on the allowed list")
        }

        let allowedAndRunning = running.intersection(allowed)
        for appID in allowedAndRunning {
            try await apiClient.reportUsage(appIdentifier: appID, secondsUsed: Int(pollInterval))
            print("Reported \(pollInterval)s of usage for \(appID)")
        }
    }


    func run() async {
        while true {
            do {
                try await runOnce()
            } catch {
                print("Agent loop error: \(error)")
            }
            try? await Task.sleep(nanoseconds: pollInterval * 1_000_000_000)
        }
    }
}
