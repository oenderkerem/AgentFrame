# AgentFrame

A lightweight macOS menu bar app that draws a colored border around your screen based on the status of AI coding agents (Claude Code, OpenAI Codex, or any custom agent).

- **Busy** → colored frame appears at the screen edge(s) you configured
- **Done** → color switches + optional full-screen flash
- **Idle** → frame disappears

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green) [![Ko-fi](https://img.shields.io/badge/Ko--fi-support-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/oender)

---

## Features

- Colored frame on any combination of screen edges (top / right / bottom / left)
- Individual color and opacity per status (busy / done)
- Adjustable frame thickness
- Option to disable the frame for the busy state (done state is always shown)
- Full-screen flash on task completion — auto-dismiss or persistent until click
- Configurable auto-hide delay after done (returns frame to idle automatically)
- Multi-monitor support: main screen, fixed screen, or follow the cursor
- Sound notifications
- Launch at login
- Status input via **HTTP** (default port 7842) and/or **file watching** — your choice
- UI available in **English** and **German**

---

## Installation

### Download

1. Go to [Releases](https://github.com/oenderkerem/AgentFrame/releases/latest)
2. Download `AgentFrame-x.x.x.dmg`
3. Open the DMG and drag `AgentFrame.app` to `/Applications`
4. Right-click → **Open** on first launch (macOS Gatekeeper requires this once for unsigned apps)

### Build from source

Requires macOS 13+ and Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/oenderkerem/AgentFrame.git
cd agents-frame
make install   # builds release binary and copies AgentFrame.app to /Applications
```

---

## Connecting Claude Code

Claude Code fires **hooks** — shell commands — at specific lifecycle events. AgentFrame listens for those signals and updates the frame accordingly.

### 1. Start AgentFrame

Launch the app. It starts an HTTP server on `localhost:<PORT>` in the background. The default port is 7842 and can be changed in **Settings → Integration**.

### 2. Install hooks automatically

Open **Settings → Integration**, select **Claude Code** as your agent, then click **Install Automatically**. AgentFrame writes a `PreToolUse` hook (sends `/busy`) and a `Stop` hook (sends `/done`) into `~/.claude/settings.json` — existing hooks from other tools are not touched.

Hooks are installed **once globally** and apply to all projects and sessions automatically. If you want to limit the integration to a single project, copy the snippet from Settings and paste it into `.claude/settings.json` inside that project directory instead.

### 3. Or add hooks manually to `~/.claude/settings.json`

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": ".*",
        "hooks": [
          { "type": "command", "command": "curl -s -X POST http://localhost:<PORT>/busy" }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": ".*",
        "hooks": [
          { "type": "command", "command": "curl -s -X POST http://localhost:<PORT>/done" }
        ]
      }
    ]
  }
}
```

| Hook | When it fires | Signal sent |
|---|---|---|
| `PreToolUse` | Before Claude uses any tool | `/busy` → frame appears |
| `Stop` | When Claude finishes its turn | `/done` → color switches + flash |

AgentFrame also shows a ready-to-copy snippet in **Settings → Integration**.

### Alternative: file-based

If you prefer not to use HTTP, switch to **File Watching** in Settings. Then use:

```bash
# in your hook command:
echo busy > ~/.claude/agent_frame_status   # busy
echo done > ~/.claude/agent_frame_status   # done
```

---

## Connecting OpenAI Codex

Open **Settings → Integration**, select **OpenAI Codex**, then click **Install Automatically**. AgentFrame sets the `onStart` (sends `/busy`) and `onFinish` (sends `/done`) keys in `~/.codex/config.json` — other settings in that file are not affected.

Or add manually to `~/.codex/config.json`:

```json
{
  "onStart":  "curl -s -X POST http://localhost:<PORT>/busy",
  "onFinish": "curl -s -X POST http://localhost:<PORT>/done"
}
```

---

## HTTP API

Any agent can send signals via HTTP — no dependency on Claude Code.

```
POST http://localhost:<port>/busy              →  frame appears (busy color)
POST http://localhost:<port>/done              →  frame appears (done color) + flash
POST http://localhost:<port>/idle              →  frame disappears
POST http://localhost:<port>/status            →  body: {"status":"busy|done|idle"}
```

The port defaults to `7842` and can be changed in **Settings → Integration**.

---

## Using with any agent

AgentFrame is fully agent-agnostic. The HTTP server and file watcher don't know or care which agent is calling them — any tool that can run a shell command or write a file works out of the box.

To use it with an agent not listed in Settings, just call the endpoints directly from that agent's hook/callback system:

```bash
curl -s -X POST http://localhost:<port>/busy   # agent started working
curl -s -X POST http://localhost:<port>/done   # agent finished
```

---

## Settings overview

| Tab | What you configure |
|---|---|
| General | Language, sound notifications, launch at login |
| General → Frame | Edges, thickness, color & opacity per status, busy on/off, auto-hide delay |
| General → Frame → Screen | Which monitor to draw on, follow-cursor mode |
| General → Frame → Flash | Enable flash, persistent until click, flash duration |
| General → Preview | Test buttons to trigger busy / done / idle manually |
| Integration | Agent provider, transport (HTTP / file), port, hook snippet, auto-install hooks |

---

## Contributing

Pull requests are welcome. For larger changes, open an issue first to discuss what you'd like to change.

### Releasing a new version

Releases are automated via GitHub Actions. To publish a new version:

```bash
git tag v1.2.0
git push origin v1.2.0
```

The workflow will build the app, package it as a DMG, and publish a GitHub Release with the DMG attached. The version number is read from the tag — no manual edits to `Info.plist` or the Makefile required.

The tag must follow the `v<major>.<minor>.<patch>` format.

---

## License

MIT
