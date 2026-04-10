#!/bin/bash
# caveman — one-command hook installer for Claude Code
# Installs: SessionStart hook (auto-load rules) + UserPromptSubmit hook (mode tracking)
# Usage: bash hooks/install.sh
set -e

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"

HOOK_FILES=("caveman-activate.js" "caveman-mode-tracker.js")

# Resolve source directory (script must be run from inside the cloned repo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null)" 2>/dev/null && pwd)"

echo "Installing caveman hooks..."

# 1. Ensure hooks dir exists
mkdir -p "$HOOKS_DIR"

# 2. Copy hook files (must be run from inside the cloned repo)
for hook in "${HOOK_FILES[@]}"; do
  if [ -f "$SCRIPT_DIR/$hook" ]; then
    cp "$SCRIPT_DIR/$hook" "$HOOKS_DIR/$hook"
  else
    echo "❌ Hook file not found: $SCRIPT_DIR/$hook"
    echo "   Run this script from inside the cloned RMacris/caveman repo."
    exit 1
  fi
  echo "  Installed: $HOOKS_DIR/$hook"
done

# 3. Wire hooks into settings.json (idempotent)
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

node -e "
  const fs = require('fs');
  const settings = JSON.parse(fs.readFileSync('$SETTINGS', 'utf8'));
  if (!settings.hooks) settings.hooks = {};

  // SessionStart — auto-load caveman rules
  if (!settings.hooks.SessionStart) settings.hooks.SessionStart = [];
  const hasStart = settings.hooks.SessionStart.some(e =>
    e.hooks && e.hooks.some(h => h.command && h.command.includes('caveman'))
  );
  if (!hasStart) {
    settings.hooks.SessionStart.push({
      hooks: [{
        type: 'command',
        command: 'node $HOOKS_DIR/caveman-activate.js',
        timeout: 5,
        statusMessage: 'Loading caveman mode...'
      }]
    });
  }

  // UserPromptSubmit — track mode changes when user types /caveman commands
  if (!settings.hooks.UserPromptSubmit) settings.hooks.UserPromptSubmit = [];
  const hasPrompt = settings.hooks.UserPromptSubmit.some(e =>
    e.hooks && e.hooks.some(h => h.command && h.command.includes('caveman'))
  );
  if (!hasPrompt) {
    settings.hooks.UserPromptSubmit.push({
      hooks: [{
        type: 'command',
        command: 'node $HOOKS_DIR/caveman-mode-tracker.js',
        timeout: 5,
        statusMessage: 'Tracking caveman mode...'
      }]
    });
  }

  fs.writeFileSync('$SETTINGS', JSON.stringify(settings, null, 2) + '\n');
"
echo "  Hooks wired in settings.json"

echo ""
echo "Done! Restart Claude Code to activate."
echo ""
echo "What's installed:"
echo "  - SessionStart hook: auto-loads caveman rules every session"
echo "  - Mode tracker hook: updates statusline badge when you switch modes"
echo "    (/caveman lite, /caveman ultra, /caveman-commit, etc.)"
echo ""
echo "Optional: Add a [CAVEMAN] badge to your statusline."
echo "See: https://github.com/RMacris/caveman/blob/main/hooks/README.md"
