# appcurfew-agent

`appcurfew-agent` is the enforcement client for [AppCurfew](https://github.com/Xocash695/AppCurfew) — 
a self-hosted screen time manager for Linux. This is the piece that actually
runs on a child's Linux machine: it polls the AppCurfew server, checks which
Flatpak apps are currently allowed, blocks anything that isn't, and reports
usage back so time limits count down correctly.

Written entirely in Swift.

## How It Works

Every ~10 seconds (configurable), the agent:

1. Reports the list of installed Flatpak apps to the server, so a parent can
   pick from a friendly dropdown instead of typing raw app identifiers
2. Fetches the current allow-list for this child from the server
3. Checks which Flatpak apps are actually running, scoped to one specific
   Linux user account (so it never touches other accounts on a shared machine)
4. Kills anything running that isn't on the allow-list
5. Reports usage for anything running that *is* allowed, so the server can
   count down daily time limits

All the actual rule logic (daily limits, day-of-week restrictions, time-of-day
windows, manual bypass) lives on the server — this agent doesn't know or care
about any of that. It just asks "what's allowed right now?" and acts on the
answer. That split is deliberate: swapping this agent out for a macOS or
Windows equivalent would only mean rewriting the small module that talks to
the OS (`FlatpakInspector.swift`) — everything else is already platform-agnostic.

## Requirements

- A Linux machine with [Flatpak](https://flatpak.org) installed
- [Swift](https://www.swift.org/install/linux/) (to build the agent — the
  install script does not install this for you)
- A running AppCurfew server, reachable from this machine
- A child profile already created on that server, with its API key

## Installation

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Xocash695/appcurfew-agent/main/install.sh)"
```

You'll be prompted for:
- The child's Linux **username** on this machine (so the agent only ever
  affects that account's processes, never a parent's or sibling's)
- Your AppCurfew server URL
- That child's API key (from the AppCurfew dashboard)

This installs the agent as a systemd service, so it starts automatically on
boot and restarts itself if it ever crashes.

### Multiple children on one machine

If more than one child shares this machine under separate Linux accounts,
just run the install script again for each one — each gets its own config
file and its own systemd service instance, fully independent of the others.

```bash
sudo systemctl status appcurfew-agent@timmy
sudo systemctl status appcurfew-agent@sarah
```

## Checking On It

```bash
sudo systemctl status appcurfew-agent@<username>
sudo journalctl -u appcurfew-agent@<username> -f
```

## Configuration

Config lives at `/etc/appcurfew/<username>.json`:

```json
{
    "serverURL": "http://100.x.x.x:8080",
    "apiKey": "the-childs-api-key",
    "childUsername": "timmy"
}
```

## Known Limitations

- **Fail-open on network loss.** If this machine loses connectivity to the
  server, enforcement pauses rather than blocking everything — a child could
  relaunch a previously-blocked app until connectivity returns and the next
  poll succeeds. This is a deliberate tradeoff for a low-stakes family tool,
  not an oversight; a stricter fail-closed mode is a possible future addition.
- **Requires the child's account to be a standard, non-admin user.** The
  agent runs as root specifically so the child can't stop or interfere with
  it — but that only holds if the child's own login doesn't have sudo/admin
  rights. If it does, no client-side agent can be fully tamper-proof against
  its own machine's admin, on any OS.
- **~10-30 second enforcement granularity**, not instant. An app can run
  briefly between polls before being caught. Fine for a family screen-time
  tool; not a precision security boundary.

## Tech Stack

- Swift, built with the Swift Package Manager
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) for CLI parsing
- `Process`/`Pipe` for shelling out to `flatpak` and `ps`
- `URLSession` for talking to the AppCurfew server
- systemd for running as an unattended background service

## A Note on AI Usage

Built with Claude as a hands-on collaborator — explaining Linux/Swift
platform quirks I hadn't hit before (like Foundation's networking APIs being
split into a separate module on Linux), working through real output from a
test VM together rather than guessing at formats, and in places directly
applying agreed-upon code changes via Claude in Xcode. Design decisions and
debugging were mine; Claude was the pair-programming partner and teacher.
