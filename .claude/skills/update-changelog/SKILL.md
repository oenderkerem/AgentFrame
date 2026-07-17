---
name: update-changelog
description: Remind to update CHANGELOG.md after every feature implementation in AgentFrame
---

# Update Changelog

After implementing any feature, bugfix, or breaking change in AgentFrame, **always** update `CHANGELOG.md` before reporting the task as done.

## Rules

1. All entries go under `## [Unreleased]` until a release is cut.
2. Use the correct subsection:
   - `### Added` — new features
   - `### Fixed` — bug fixes
   - `### Changed` — behaviour changes to existing features
   - `### Removed` — removed features
   - Mark breaking changes explicitly with **breaking change** in the entry text.
3. Each entry is a single bullet starting with a **bold short label** followed by an em-dash and a concise description. Example:
   ```
   - **Automatic hook removal** — when switching from HTTP to File mode, AgentFrame prompts to remove stale hooks from all supported agent configs
   ```
4. Do not reference internal file names, function names, or PR numbers in the entry — describe the user-visible behaviour.
5. If a feature touches HTTP endpoints or hook config formats, note whether it is a breaking change.

## Checklist before marking a task done

- [ ] Is there a new entry in `CHANGELOG.md` under `[Unreleased]`?
- [ ] Does the entry describe the change from the **user's perspective**?
- [ ] Is a breaking change explicitly labelled as such?
