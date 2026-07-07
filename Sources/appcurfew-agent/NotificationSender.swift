//
//  NotificationSender.swift
//  appcurfew-agent
//
//  Created by Akash Kallumkal on 2026-07-07.
//

import Foundation

struct NotificationSender {
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

    func sendWarning(appID: String, secondsLeft: Int, username: String) throws {
        // Round up to whole minutes for a friendlier message.
        let minutesLeft = max(1, (secondsLeft + 59) / 60)
        let body = "\(appID) — \(minutesLeft) minute\(minutesLeft == 1 ? "" : "s") left today"

        // The agent runs as root, so we re-enter the child's session to reach
        // their desktop. A graphical notification needs two pieces of the
        // user's session context: XDG_RUNTIME_DIR (the runtime dir) and
        // DBUS_SESSION_BUS_ADDRESS (the session bus notify-send delivers over).
        // Note: DISPLAY is deliberately NOT set — modern desktops (like KDE on
        // Wayland) don't need it for notifications, and hardcoding X11's :0
        // would be wrong on Wayland sessions anyway. D-Bus is the actual
        // delivery mechanism regardless of display server.
        let uid = try uid(for: username)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-u", username, "env",
                             "XDG_RUNTIME_DIR=/run/user/\(uid)",
                             "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\(uid)/bus",
                             "notify-send",
                             "Screen Time Warning",
                             body]
        try process.run()
        process.waitUntilExit()
    }
}
