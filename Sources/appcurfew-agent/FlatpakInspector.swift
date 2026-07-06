//
//  FlatpakInspector.swift
//  appcurfew-agent
//
//  Created by Akash Kallumkal on 2026-07-03.
//

import Foundation

struct FlatpakInspector {
    func listInstalledApps() throws -> [InstalledAppReport] {
        let output = try runFlatpak(arguments: ["list", "--app", "--columns=application,name"])
        
        let lines = output.split(separator: "\n").map(String.init)
        
        var apps: [InstalledAppReport] = []
        for line in lines {
            // skip the header row
            if line.hasPrefix("Application ID") { continue }
            
            let parts = line.split(separator: "\t").map(String.init)
            guard parts.count == 2 else { continue }
            
            apps.append(InstalledAppReport(id: parts[0].trimmingCharacters(in: .whitespaces),
                                            name: parts[1].trimmingCharacters(in: .whitespaces)))
        }
        return apps
    }
    
    private func uid(for username: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/id")
        process.arguments = ["-u", username]

        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runFlatpak(arguments: [String], asUser username: String? = nil) throws -> String {
        let process = Process()
        if let username {
            // The agent runs as root, but Flatpak sandboxes are tracked
            // per-user, so root can't see or control another user's running
            // instances. Re-enter the target user's session with the right
            // XDG_RUNTIME_DIR so flatpak has the correct per-user context.
            process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            process.arguments = ["-u", username, "env",
                                 "XDG_RUNTIME_DIR=/run/user/\(try uid(for: username))",
                                 "flatpak"] + arguments
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/flatpak")
            process.arguments = arguments
        }

        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    func runningAppIdentifiers(forUser username: String) throws -> Set<String> {
        let output = try runFlatpak(arguments: ["ps", "--columns=application,child-pid"], asUser: username)
        print("RAW flatpak ps output: \(output.debugDescription)")
        let lines = output.split(separator: "\n").map(String.init)
            .filter { !$0.hasPrefix("Application") }   // skip the header row
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        var identifiers: Set<String> = []
        for line in lines {
            let parts = line.split(separator: "\t").map(String.init)
            guard parts.count == 2 else { continue }

            let appID = parts[0].trimmingCharacters(in: .whitespaces)
            let pid = parts[1].trimmingCharacters(in: .whitespaces)

            // Only include the app if we can confirm the owning process
            // belongs to the target child's account. A failed lookup (e.g. the
            // process already exited) is skipped silently rather than throwing.
            if let owner = try? processOwner(pid: pid), owner == username {
                identifiers.insert(appID)
            }
        }
        return identifiers
    }

    private func processOwner(pid: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-o", "user=", "-p", pid]

        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func kill(appID: String, asUser username: String) throws {
         _ = try runFlatpak(arguments: ["kill", appID], asUser: username) // tossing the output in the garbage cause we don't care
    }
}
