---
name: clawd-on-desk-replication
description: "How to replicate this customized Claude Code setup (plugins, skills, CLAUDE.md, clawd) to a fresh machine"
metadata: 
  node_type: memory
  type: project
  originSessionId: 7fa267bf-b1ab-4b1b-991e-95019051c9a5
---

# Clawd-on-Desk Cross-Machine Replication

## Part A: CLAUDE.md + Plugins + Skills

### A1. CLAUDE.md
Copy to `$env:USERPROFILE\.claude\CLAUDE.md` (no path deps).

### A2. Markets
```powershell
claude plugin marketplace add https://github.com/anthropics/claude-plugins-official.git
claude plugin marketplace add https://github.com/anthropics/skills.git
claude plugin marketplace add https://github.com/JuliusBrussee/caveman.git
```

### A3. Plugins
```powershell
claude plugin install claude-md-management@claude-plugins-official
claude plugin install skill-creator@claude-plugins-official
claude plugin install github@claude-plugins-official
claude plugin install frontend-design@claude-plugins-official
claude plugin install document-skills@anthropic-agent-skills
claude plugin install caveman@caveman
```

### A4. Standalone skills
```powershell
git clone https://github.com/anthropic-skills/humanizer-zh.git $env:USERPROFILE\.claude\skills\humanizer-zh
git clone https://github.com/anthropic-skills/code-review-graph.git $env:USERPROFILE\.claude\skills\code-review-graph
```

### A5. MCP + proxy
settings.json depends on proxy at `127.0.0.1:15721`. Target needs MiniMax MCP configured in `~/.claude.json` under `mcpServers.MiniMax`.

---

## Part B: Clawd Desktop Pet（桌宠）

### The file that matters
Only **one file**: `%APPDATA%\clawd-on-desk\clawd-prefs.json`

Contains: position (x/y), theme (clawd), size (P:9), all agent toggles, keyboard shortcuts, permission bubble settings, auto-start, etc.

**May need to adjust `x`/`y` and `positionDisplay.bounds`** if target monitor resolution differs.

### Bootstrap on target machine
```powershell
# 1. Clone & install
git clone https://github.com/JuliusBrussee/clawd-on-desk.git $env:USERPROFILE\clawd-on-desk-main
cd $env:USERPROFILE\clawd-on-desk-main
npm install

# 2. Copy prefs from old machine
mkdir $env:APPDATA\clawd-on-desk -Force
Copy-Item <from-old-machine>\clawd-prefs.json $env:APPDATA\clawd-on-desk\

# 3. Register Claude Code hooks
npm run install:claude-hooks

# 4. Launch
npm start
```

### DO NOT copy
- `%APPDATA%\clawd-on-desk\` cache/log dirs (auto-regenerated)
- `~\.clawd\runtime.json` (auto-generated port)
- `~\.clawd\mobile-token.json` (machine-bound token)
- `~\.claude\settings.json` (machine-specific paths; let `install:claude-hooks` regenerate)

---

## Part C: Git Sync (CLAUDE.md + Memory + Skills)

### C1. Git repo
`~/.claude/` git repo at `https://github.com/yvanapplecheng/claude-config-sync.git` (private).

### C2. Auto-pull on startup
`~/.claude/settings.json` SessionStart hook runs `config-sync.ps1` — pulls config repo + all skill repos at Claude Code launch.

### C3. Bootstrap on target machine
```powershell
git clone <private-repo-url> $env:TEMP\claude-sync
Copy-Item $env:TEMP\claude-sync\* $env:USERPROFILE\.claude\ -Recurse -Force
Remove-Item $env:TEMP\claude-sync -Recurse -Force
cd $env:USERPROFILE\.claude
git init; git remote add origin <private-repo-url>
git fetch origin; git checkout origin/master -- .
git branch --set-upstream-to=origin/master master
```
Then run `bootstrap-other-machine.ps1` for plugins/skills install.

### What does NOT sync
- `settings.json` (machine-specific paths, proxy, clawd hooks)
- `~/.claude.json` (MCP keys, session metrics)
- `~/.claude/plugins/` cache (must `claude plugin install` per machine)
- `%APPDATA%\clawd-on-desk\clawd-prefs.json` (copy once manually)
- Session JSONL transcripts (too large)

**Why:** User wants identical Claude Code environment across multiple Windows machines. Layers identified by auditing .claude/ settings, plugin list, marketplace configs, and clawd hooks.
**How to apply:** Run the bootstrap steps above on target machine. Do NOT copy settings.json directly; let clawd's install:claude-hooks regenerate it.
