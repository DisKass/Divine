# Implementation Plan - Skill `/bug` Creation

Creation of the `/bug` skill in `.agents/skills/bug/SKILL.md` to automate bug triaging. When invoked, the agent investigates whether a reported bug was caused by recent changes (regressions) or if it's a pre-existing bug. If caused by recent changes, the agent fixes it. If pre-existing, the agent notifies the user and logs the bug in `KNOWN_BUGS.md`.

## User Review Required

> [!IMPORTANT]
> **Location & Format of Known Bugs Log**: We propose placing `KNOWN_BUGS.md` in the root of the project directory. Each entry will follow a structured markdown format with timestamp, description, root cause, affected components, and open status.

## Proposed Changes

### `.agents/skills/bug`

#### [NEW] [SKILL.md](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/.agents/skills/bug/SKILL.md)
Create the new skill specification file containing:
- YAML frontmatter (`name: bug`, pushy trigger description for `/bug` and bug triaging requests).
- **Step 1: Root Cause Investigation**: How to inspect error logs, stack traces, and relevant code.
- **Step 2: Causality Analysis**: How to check git diffs (`git diff`, `git log`), uncommitted changes, and recent session entries in `DEVELOPMENT_LOG.md` to determine if the bug is a regression caused by recent modifications or a pre-existing issue.
- **Step 3: Decision & Execution**:
  - **Recent Regression**: Fix the bug in place, verify the fix, and report what went wrong and how it was fixed.
  - **Pre-existing Bug**: Notify the user clearly, document the issue in `KNOWN_BUGS.md`, and leave the code untouched unless explicitly requested otherwise.
- **Template for `KNOWN_BUGS.md`**: Specification of the layout and field structure for appending pre-existing bugs.

### Project Root

#### [NEW] [KNOWN_BUGS.md](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/KNOWN_BUGS.md)
Create initial `KNOWN_BUGS.md` file with header structure and explanatory instructions.

## Verification Plan

### Automated / Manual Verification
1. Inspect `.agents/skills/bug/SKILL.md` to ensure valid YAML frontmatter and clear, unambiguous prompt instructions.
2. Verify file creation of `.agents/skills/bug/SKILL.md` and initial `KNOWN_BUGS.md`.
3. Check project rules alignment (no automatic commits, no CLI editing of files, proper logging).
