# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

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
