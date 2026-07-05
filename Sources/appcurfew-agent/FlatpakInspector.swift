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
    
    private func runFlatpak(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/flatpak")
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    func runningAppIdentifiers(forUser username: String) throws -> Set<String> {
        let output = try runFlatpak(arguments: ["ps", "--columns=application,child-pid"])

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
    
    func kill(appID: String) throws {
         _ = try runFlatpak(arguments: ["kill", appID]) // tossing the output in the garbage cause we don't care
        // hint: `flatpak kill <appID>` is the real command
        // reuse runFlatpak(arguments: [...]) — you don't need to read its output this time
    }
}
