//
//  Models.swift
//  appcurfew-agent
//
//  Created by Akash Kallumkal on 2026-07-02.
//

import Foundation

struct AgentConfig: Codable {
    let serverURL: String
    let apiKey: String
    let childUsername: String
    let warnThresholdSeconds: Int?
}
struct InstalledAppReport: Codable {
    let id: String
    let name: String
}

struct InstalledAppsRequest: Codable {
    let apps: [InstalledAppReport]
}

struct UsageReportRequest: Codable {
    let appIdentifier: String
    let secondsUsed: Int
}

struct UsageReportResponse: Codable {
    let remainingSeconds: Int?
}

struct AllowedAppStatus: Codable {
    let appIdentifier: String
    let remainingSeconds: Int?
}
