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
    let notificationSender: NotificationSender
    let childUsername: String
    let warnThresholdSeconds: Int
    let pollInterval: UInt64 = 10 //every seconds it gets polled to see what is allowed or not

    func runOnce(warnedToday: inout Set<String>) async throws {
        print("Step 1: listing installed apps...")
        let installed = try flatpakInspector.listInstalledApps()
        print("Step 1 done, found \(installed.count) apps")
        
        print("Step 2: reporting installed apps...")
        try await apiClient.reportInstalledApps(installed)
        print("Step 2 done")

        print("Step 3: fetching allowed apps...")
        let allowedStatuses = try await apiClient.fetchAllowedApps()
        // Identifiers only, for the subtract/intersect logic against running apps.
        let allowed = Set(allowedStatuses.map { $0.appIdentifier })
        // Per-app remaining time, for the low-time warning below.
        let remainingByApp = Dictionary(uniqueKeysWithValues:
            allowedStatuses.map { ($0.appIdentifier, $0.remainingSeconds) })
        print("Step 3 done, allowed: \(allowed)")

        print("Step 4: checking running apps...")
        let running = try flatpakInspector.runningAppIdentifiers(forUser: childUsername)
        print("Step 4 done, running: \(running)")

        let disallowedRunning = running.subtracting(allowed)
        print("Disallowed running: \(disallowedRunning)")
        
        for appID in disallowedRunning {
            print("Killing \(appID)...")
            try flatpakInspector.kill(appID: appID, asUser: childUsername)
            print("Killed \(appID)")
        }

        let allowedAndRunning = running.intersection(allowed)
        for appID in allowedAndRunning {
            try await apiClient.reportUsage(appIdentifier: appID, secondsUsed: Int(pollInterval))
            print("Reported \(pollInterval)s of usage for \(appID)")

            // One-time low-time warning: only when the server reported remaining
            // time, the child is down to their last two minutes, and we haven't
            // already warned about this app.
            if let remaining = remainingByApp[appID] ?? nil,
               remaining > 0, remaining <= warnThresholdSeconds,
               !warnedToday.contains(appID) {
                try notificationSender.sendWarning(appID: appID, secondsLeft: remaining, username: childUsername)
                warnedToday.insert(appID)
                print("Warned about low time for \(appID) (\(remaining)s left)")
            }
        }
    }


    func run() async {
        // Tracks which apps have already had their low-time warning fired, so
        // the notification is one-time rather than every poll. Lives across
        // loop iterations without needing Agent to be a mutable reference type.
        var warnedToday: Set<String> = []
        while true {
            do {
                try await runOnce(warnedToday: &warnedToday)
            } catch {
                print("Agent loop error: \(error)")
            }
            try? await Task.sleep(nanoseconds: pollInterval * 1_000_000_000)
        }
    }
}
