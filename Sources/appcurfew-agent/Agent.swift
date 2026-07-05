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
        print("Step 1: listing installed apps...")
        let installed = try flatpakInspector.listInstalledApps()
        print("Step 1 done, found \(installed.count) apps")
        
        print("Step 2: reporting installed apps...")
        try await apiClient.reportInstalledApps(installed)
        print("Step 2 done")

        print("Step 3: fetching allowed apps...")
        let allowed = try await apiClient.fetchAllowedApps()
        print("Step 3 done, allowed: \(allowed)")

        print("Step 4: checking running apps...")
        let running = try flatpakInspector.runningAppIdentifiers(forUser: childUsername)
        print("Step 4 done, running: \(running)")

        let disallowedRunning = running.subtracting(allowed)
        print("Disallowed running: \(disallowedRunning)")
        
        for appID in disallowedRunning {
            print("Killing \(appID)...")
            try flatpakInspector.kill(appID: appID)
            print("Killed \(appID)")
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
