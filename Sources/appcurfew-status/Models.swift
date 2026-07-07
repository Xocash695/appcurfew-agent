//
//  Models.swift
//  appcurfew-status
//
//  Created by Akash Kallumkal on 2026-07-07.
//
//  A deliberately minimal copy of the two model types this read-only status
//  tool needs. The full set lives in the appcurfew-agent target; sharing them
//  via a library would force the agent's entire model surface to become public,
//  so a tiny duplication is the lighter-weight choice here.
//

import Foundation

struct AgentConfig: Codable {
    let serverURL: String
    let apiKey: String
    let childUsername: String
}

struct AllowedAppStatus: Codable {
    let appIdentifier: String
    let remainingSeconds: Int?
}
