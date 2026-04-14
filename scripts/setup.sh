#!/bin/bash
# Notchify setup — installs CLI, configures Claude Code hooks, optionally adds to login items.
# Works both after build.sh (from source) and after unzipping a pre-built release.

set -e

# ---- Find Notchify.app ----
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP=$(find "$SCRIPT_DIR/.." "$(pwd)" -maxdepth 2 -name "Notchify.app" 2>/dev/null | head -1)

if [ -z "$APP" ]; then
    echo "Error: Notchify.app not found near this script or current directory."
    echo "Run ./scripts/build.sh first, or place this script next to Notchify.app."
    exit 1
fi

APP="$(cd "$APP" && pwd)"
echo "==> Found: $APP"

# ---- Save app path for config tool ----
mkdir -p "$HOME/.config/notchify"
echo "$APP" > "$HOME/.config/notchify/app_path"

# ---- Install CLI symlink ----
mkdir -p "$HOME/bin"
CLI_LINK="$HOME/bin/notchify"
ln -sf "$APP/Contents/MacOS/notchify-cli" "$CLI_LINK"
echo "==> CLI symlinked: ~/bin/notchify"

# ---- Ensure ~/bin is in PATH ----
add_to_path() {
    local rc_file="$1"
    if [ -f "$rc_file" ] && ! grep -q 'export PATH="$HOME/bin:$PATH"' "$rc_file"; then
        echo '' >> "$rc_file"
        echo '# Added by Notchify setup' >> "$rc_file"
        echo 'export PATH="$HOME/bin:$PATH"' >> "$rc_file"
        echo "==> Added ~/bin to PATH in $rc_file"
    fi
}

if ! echo "$PATH" | grep -q "$HOME/bin"; then
    add_to_path "$HOME/.zshrc"
    add_to_path "$HOME/.bashrc"
    echo "    Note: Run 'source ~/.zshrc' (or open a new terminal) to apply PATH changes."
fi

# ---- Claude Code hooks ----
echo ""
echo "==> Claude Code hooks"

SETTINGS="$HOME/.claude/settings.json"
if [ ! -f "$SETTINGS" ]; then
    mkdir -p "$(dirname "$SETTINGS")"
    echo "{}" > "$SETTINGS"
fi

ask_hook() {
    local prompt="$1"
    local default="y"
    read -r -p "$prompt [Y/n] " answer
    answer="${answer:-y}"
    [[ "$answer" =~ ^[Yy]$ ]]
}

INSTALL_WORKING=false
INSTALL_DONE=false
INSTALL_WAITING=false

ask_hook "Install hook: Claude starts using a tool → show 'working'?" && INSTALL_WORKING=true
ask_hook "Install hook: Claude finishes a turn → show 'done'?"        && INSTALL_DONE=true
ask_hook "Install hook: Claude needs your attention → show 'waiting'?" && INSTALL_WAITING=true

if $INSTALL_WORKING || $INSTALL_DONE || $INSTALL_WAITING; then
    cp "$SETTINGS" "$SETTINGS.bak"

    python3 - "$SETTINGS" "$INSTALL_WORKING" "$INSTALL_DONE" "$INSTALL_WAITING" << 'EOF'
import json, sys

path, install_working, install_done, install_waiting = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

with open(path) as f:
    settings = json.load(f)

hooks = settings.setdefault("hooks", {})

def ensure_hook(event, command):
    event_hooks = hooks.setdefault(event, [])
    for entry in event_hooks:
        for h in entry.get("hooks", []):
            if h.get("command") == command:
                return
    event_hooks.append({"hooks": [{"type": "command", "command": command}]})

if install_working == "true":
    ensure_hook("UserPromptSubmit", "~/bin/notchify set working")
    ensure_hook("PostToolUse",      "~/bin/notchify set working")
if install_done == "true":
    ensure_hook("Stop",             "~/bin/notchify set done")
if install_waiting == "true":
    ensure_hook("Notification",     "~/bin/notchify set waiting")

with open(path, "w") as f:
    json.dump(settings, f, indent=2)

print(f"Hooks saved to {path}")
EOF
fi

# ---- Startup animation (claude shell wrapper) ----
echo ""
echo "==> Launch animation"
read -r -p "Show startup animation when running 'claude' in terminal? [Y/n] " answer
answer="${answer:-y}"
if [[ "$answer" =~ ^[Yy]$ ]]; then
    add_claude_wrapper() {
        local rc_file="$1"
        if [ -f "$rc_file" ] && ! grep -q 'notchify set start' "$rc_file"; then
            cat >> "$rc_file" << 'WRAPPER'

# Added by Notchify setup — startup animation
function claude() {
  ~/bin/notchify set start
  command claude "$@"
  ~/bin/notchify set bye
}
WRAPPER
            echo "==> Added claude wrapper to $rc_file"
        fi
    }
    add_claude_wrapper "$HOME/.zshrc"
    add_claude_wrapper "$HOME/.bashrc"
    echo "    Restart terminal or run 'source ~/.zshrc' to apply."
fi

# ---- Login Item ----
echo ""
echo "==> Autostart"
read -r -p "Launch Notchify automatically on login? [Y/n] " answer
answer="${answer:-y}"
if [[ "$answer" =~ ^[Yy]$ ]]; then
    osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$APP\", hidden:true}" 2>/dev/null \
        && echo "==> Added to login items." \
        || echo "    Could not add login item automatically. Add Notchify.app manually in System Settings > General > Login Items."
fi

# ---- Sound config ----
echo ""
echo "==> Sounds"
read -r -p "Create a sounds config file (~/.config/notchify/sounds.json)? [Y/n] " answer
answer="${answer:-y}"
if [[ "$answer" =~ ^[Yy]$ ]]; then
    mkdir -p "$HOME/.config/notchify"
    SOUNDS_FILE="$HOME/.config/notchify/sounds.json"
    if [ ! -f "$SOUNDS_FILE" ]; then
        cat > "$SOUNDS_FILE" << 'SOUNDS'
{
  "start":   { "system": "Hero" },
  "done":    { "system": "Glass" },
  "waiting": { "system": "Ping" },
  "error":   { "system": "Basso" },
  "working": null,
  "idle":    null
}
SOUNDS
        echo "==> Created $SOUNDS_FILE"
        echo "    Edit it to assign sounds. System sounds: Hero, Glass, Ping, Basso, Blow,"
        echo "    Bottle, Frog, Funk, Morse, Pop, Purr, Sosumi, Submarine, Tink."
        echo "    For custom files: { \"file\": \"~/path/to/sound.mp3\" }"
    else
        echo "    Already exists, skipping: $SOUNDS_FILE"
    fi
fi

# ---- Launch ----
echo ""
echo "==> Launching Notchify..."
open "$APP"

# ---- Done ----
echo ""
echo "✓ Notchify is set up!"
echo ""
echo "Test it:"
echo "  notchify set working"
echo "  notchify set waiting"
echo "  notchify set done"
echo "  notchify set error"
echo "  notchify set idle"
echo ""
echo "If 'notchify' command is not found, run: source ~/.zshrc"
