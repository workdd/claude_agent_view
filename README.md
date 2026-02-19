# Claude Agent View

A native macOS floating dock app for managing and chatting with your Claude Code agents.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## What is this?

Claude Agent View sits at the bottom of your screen as a floating dock with animated 3D-style agent characters. Click an agent to open a chat window and start a conversation. It reads your existing Claude Code agent definitions from `~/.claude/agents/` and syncs with `claude-mem` memories.

### Key Features

- **Agent Dock** -- Floating transparent dock with 3D glass-orb characters (bear, pig, cat) representing your agents
- **~/.claude/agents/ Sync** -- Auto-loads agent definitions from your Claude Code `.md` files, watches for changes in real-time
- **Multi-Agent Collaboration** -- Use `@Backend @Researcher` or `@all` to send a task to multiple agents simultaneously
- **Claude Subscription (OAuth)** -- Connect via your existing Claude subscription -- no separate API key needed
- **Repositionable Dock** -- Scroll or drag the dock to any position on screen
- **Compact / Full Mode** -- Toggle between minimal and full display modes
- **claude-mem Integration** -- Browse and search all your Claude Code memories directly from the app
- **Claude Code Sync** -- View CLAUDE.md files, MCP plugins, agent skills, and settings in one place

## Prerequisites

- macOS 14 (Sonoma) or later
- [Claude Code](https://claude.ai/code) installed and authenticated
- (Optional) `claude-mem` MCP plugin for memory browsing

## Quick Start

```bash
# Clone the repo
git clone https://github.com/manchann/claude_agent_view.git
cd claude_agent_view

# Build
swift build -c release

# Create .app bundle
bash scripts/build-app.sh

# Run
open build/AgentDock.app
```

## Agent Setup

The app reads agent definitions from `~/.claude/agents/*.md`. Each file uses YAML frontmatter:

```markdown
---
name: backend
description: Backend API development agent
tools: Read, Write, Edit, Bash
model: sonnet
skills: api-designer, postgres-pro
---

Your agent's system prompt goes here...
```

### Default Character Mapping

| Agent Name | Character | Style |
|------------|-----------|-------|
| backend | bear | Warm brown 3D orb |
| frontend-designer | pig | Pink/purple 3D orb |
| researcher | cat | Cool blue 3D orb |

New agents are automatically assigned characters based on their name.

## Multi-Agent Collaboration

In any chat window, use `@` mentions to collaborate:

```
@Backend @Frontend Design a REST API for user profiles and build the React UI
```

This sends the message to both agents simultaneously. Each agent focuses on their specialty and responses are combined.

Use `@all` to broadcast to every agent:

```
@all Review this architecture decision and give your perspective
```

## Dock Interaction

- **Click** an agent to open its chat window
- **Hover** to see agent name, role, and status popup
- **Scroll wheel** to move the dock up/down/left/right
- **Drag** to reposition the dock anywhere on screen
- **Minimize** button to toggle compact mode (small orbs only)
- **Menu bar** > "Reset Position" to snap back to default

## Connection Modes

### Claude Subscription / OAuth (Recommended)
Uses your existing Claude Code CLI authentication. Click "Connect via Claude Account" in Settings to authenticate through your browser. No API key needed.

### API Key
Enter your Anthropic API key in Settings for direct API access with streaming responses.

## Memory Browser

If you have the `claude-mem` MCP plugin installed, the Memory tab shows all your cross-session memories:

- Search by keyword
- Filter by type (discovery, feature, bugfix, decision)
- View full observation details with facts and narrative

## Project Structure

```
Sources/AgentDock/
  App/           -- AppDelegate, AgentDockApp (entry point)
  Models/        -- Agent, ChatMessage
  ViewModels/    -- AgentViewModel (state management)
  Views/         -- DockView, ChatView, SettingsView, AgentCharacterView, etc.
  Windows/       -- FloatingPanel, ChatPanel (NSPanel subclasses)
  Services/      -- ClaudeService, ClaudeCLIService, AgentFileService,
                    MemoryService, CollaborationService, ClaudeCodeSyncService
```

## Building from Source

```bash
# Debug build
swift build

# Release build + .app bundle
bash scripts/build-app.sh
```

The app runs as a menu bar agent (no Dock icon). Access it from the menu bar icon or the floating dock at the bottom of your screen.

## License

MIT
