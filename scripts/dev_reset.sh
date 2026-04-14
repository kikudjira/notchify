#!/bin/bash
# Notchify reset — removes all setup.sh changes for clean re-install testing.
# Creates backups before modifying files.

set -e

echo "==> Notchify reset"
echo ""

# ---- Kill app ----
if pgrep -f "Notchify" > /dev/null 2>&1; then
    pkill -f "Notchify" && echo "==> Killed Notchify.app"
fi

# ---- Remove CLI symlink ----
if [ -L "$HOME/bin/notchify" ]; then
    rm "$HOME/bin/notchify"
    echo "==> Removed ~/bin/notchify"
fi

# ---- Remove config dir ----
if [ -d "$HOME/.config/notchify" ]; then
    rm -rf "$HOME/.config/notchify"
    echo "==> Removed ~/.config/notchify/"
fi

# ---- Remove login item ----
osascript -e 'tell application "System Events" to delete (every login item whose name is "Notchify")' 2>/dev/null \
    && echo "==> Removed login item" || true

# ---- Remove notchify lines from .zshrc ----
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [ -f "$rc" ] || continue

    # Backup
    cp "$rc" "${rc}.notchify_bak"

    # Remove block: PATH line
    # Remove block: claude() function
    python3 - "$rc" << 'EOF'
import re, sys

path = sys.argv[1]
with open(path) as f:
    content = f.read()

# Remove PATH block added by Notchify
content = re.sub(r'\n# Added by Notchify setup\nexport PATH="\$HOME/bin:\$PATH"\n', '', content)

# Remove claude() wrapper block added by Notchify
content = re.sub(
    r'\n# Added by Notchify setup[^\n]*\nfunction claude\(\) \{[^}]*\}\n?',
    '',
    content,
    flags=re.DOTALL
)

with open(path, 'w') as f:
    f.write(content)

print(f"Cleaned: {path}  (backup: {path}.notchify_bak)")
EOF

done

# ---- Remove hooks from ~/.claude/settings.json ----
SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
    cp "$SETTINGS" "$SETTINGS.notchify_bak"
    python3 - "$SETTINGS" << 'EOF'
import json, sys

path = sys.argv[1]
with open(path) as f:
    settings = json.load(f)

hooks = settings.get("hooks", {})
notchify_events = ["UserPromptSubmit", "PreToolUse", "PostToolUse", "Stop", "Notification"]

for event in notchify_events:
    if event not in hooks:
        continue
    hooks[event] = [
        entry for entry in hooks[event]
        if not any(
            "notchify" in h.get("command", "")
            for h in entry.get("hooks", [])
        )
    ]
    if not hooks[event]:
        del hooks[event]

if hooks:
    settings["hooks"] = hooks
elif "hooks" in settings:
    del settings["hooks"]

with open(path, "w") as f:
    json.dump(settings, f, indent=2)

print(f"Cleaned hooks: {path}  (backup: {path}.notchify_bak)")
EOF
fi

# ---- Remove log ----
rm -f /tmp/notchify_wrapper.log

echo ""
echo "✓ Reset complete. Now run:"
echo "  source ~/.zshrc"
echo "  ./scripts/setup.sh"
