# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

---

## [1.3.0] - 2026-07-19

### Added
- **Update notification window** — when a newer version is available (checked at launch and every 6 hours), AgentFrame automatically shows a compact window with the new version number, release notes rendered from GitHub, and a "Download Now" button; the window appears only once per version and can be permanently dismissed with "Skip This Version"

---

## [1.2.0] - 2026-07-17

### Added
- **Namespaced HTTP endpoints** — all HTTP status endpoints now use the `/agent_frame/` path prefix (e.g. `/agent_frame/busy`, `/agent_frame/done`) so AgentFrame hooks can be reliably identified and removed without touching hooks from other tools; **breaking change**: old paths (`/busy`, `/done`, `/waiting`, `/idle`, `/status`) are no longer accepted
- **Automatic hook removal on mode switch** — when switching between HTTP Server and File Watching, AgentFrame prompts to automatically remove the previously installed hooks from all supported agent configurations (Claude Code, Codex)
- **Hook inspector in Integration tab** — a new "Installed Hooks" section shows which hook events are currently active per agent, with a one-click Remove All button
- **PostToolUse hook for Claude Code** — auto-installer now writes four hooks: `PreToolUse`, `PostToolUse` (both send `busy`), `Notification` (`waiting`), and `Stop` (`done`); `PostToolUse` keeps the frame in the busy state between consecutive tool calls
- **curl `--max-time 1 … || true`** — generated hook commands now time out after 1 second and always exit 0, so a non-running AgentFrame neither blocks Claude's tool execution nor shows a hook error in the terminal
- **Stuck-busy auto-reset** — new setting in General → Frame: if the frame stays busy with no new signal for a configurable duration (default 5 min), it resets to idle automatically; the next tool call immediately restores busy state, so this only affects sessions where the agent exits without sending a done signal
- **Apply & Restart button feedback** — the button turns orange when transport settings have changed and need a restart; after clicking it cycles through "Restarting…" → "✓ Restarted" so the result is always visible
- **Icons for Settings and About menu items** — `gearshape` and `info.circle` SF Symbols added to the menu bar menu
- **App icon in About window** — the About window header now shows the actual app icon instead of a generic SF Symbol placeholder
- **Hooks reference table in About window** — lists all four Claude Code hooks, when each fires, and which signal it sends; includes a note on the Notification hook limitation
- **SVG assets** — `Resources/icon.svg` (512×512 app icon) and `Resources/banner.svg` (1200×628 LinkedIn post image) added to the repository

### Fixed
- **Spurious waiting frame after task completion** — the `Notification` hook fires for all Claude Code notifications including task-completion alerts, not only "waiting for input" events; the `waiting` signal is now ignored unless the current state is already `busy`
- **Double flash on task completion** — `SubagentStop` was firing alongside `Stop` for every session (not just multi-agent ones); because the auto-reset could elapse between the two signals, the deduplication was bypassed and the flash triggered twice; `SubagentStop` removed from default hooks
- **Status signal race condition** — HTTP and file watcher callbacks now always dispatch to the main queue before calling `handle()`, eliminating a potential data race on `currentStatus` and the busy-timeout timer
- **`make install` / `make run` leaving duplicate app entries** — install now removes the existing `/Applications/AgentFrame.app` before copying; `make run` installs first and opens from `/Applications/` so macOS Launch Services never registers two separate app paths

### Changed
- **"Both" transport mode removed from UI** — the mode picker now offers only HTTP Server and File Watching; the internal value is preserved for backward compatibility but no longer selectable

---

## [1.1.0]

### Added
- **Waiting-for-input status** — new intermediate state between busy and done; activated via `/waiting` HTTP endpoint or file value `"waiting"`; color, opacity, and sound configurable in Settings
- **Notification hook for Claude Code** — auto-installed alongside PreToolUse and Stop so the frame switches to waiting whenever Claude prompts for user input
- **Disable live mouse tracking** — new toggle in Settings → General → Screen to turn off the 250 ms polling timer on multi-monitor setups; frame repositions on the next status change instead

### Fixed
- Multi-monitor: screen picker in Settings now refreshes dynamically when monitors are connected or disconnected
- Multi-monitor: frame overlay follows the mouse cursor in real time while busy or done
- Gatekeeper no longer blocks the DMG build — app is now signed ad-hoc before packaging
- Update-available banner no longer appears in dev builds

---

## [1.0.0]

### Added
- Menu bar app with static icon (adapts to light/dark mode)
- Colored screen frame on any combination of edges (top / right / bottom / left)
- Individual color and opacity per status (busy / done)
- Adjustable frame thickness
- Option to disable the frame for the busy state independently — done state is unaffected
- Full-screen flash on task completion — auto-dismiss or persistent until click
- Configurable auto-hide delay after done (0.5–30 s, default 2.0 s)
- Multi-monitor support: main screen, fixed screen, or follow the cursor
- Sound notifications with customizable system sound per status
- Launch at login via SMAppService
- Status input via HTTP server (default port 7842, configurable)
- Status input via file watching as an alternative to HTTP
- Agent-agnostic — works with Claude Code, OpenAI Codex, or any custom agent
- Hook snippet generator for Claude Code and OpenAI Codex in Settings → Integration
- One-click hook auto-installation:
  - Claude Code: writes `PreToolUse` and `Stop` hooks to `~/.claude/settings.json`; existing hooks from other tools are preserved
  - OpenAI Codex: writes `onStart` and `onFinish` to `~/.codex/config.json`; other keys are preserved
- About window explaining the three states, HTTP API, and hook setup
- Preview buttons in Settings → General to manually trigger busy / done / idle
- UI available in English and German
- DMG distribution via `make release`
- Automated GitHub release workflow: pushing a `v*` tag builds and publishes the DMG as a GitHub Release
