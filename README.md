# Notchify

A pixel mascot for [Claude Code](https://claude.ai/code) that lives in your MacBook's notch area and reacts to what Claude is doing.

> **Requires** macOS 12+, a MacBook with a notch (Pro/Air 2021+), and Claude Code CLI.

---

## Install

### Homebrew (recommended)

```sh
brew tap kikudjira/notchify
brew install notchify
notchify config
```

> The app is not notarized. On first launch macOS will warn "unidentified developer" — right-click `Notchify.app` → Open to proceed, or run:
> ```sh
> xattr -dr com.apple.quarantine Notchify.app
> ```

### Build from source

```sh
git clone https://github.com/kikudjira/notchify
cd notchify
./scripts/build.sh   # requires Swift toolchain (xcode-select --install)
./scripts/setup.sh
```

`setup.sh` installs the CLI to `~/bin/notchify`, configures Claude Code hooks, and optionally adds Notchify to login items.

---

## Usage

Notchify is controlled by the `notchify` CLI:

```sh
notchify launch        # Launch the app (or add it to login items via 'config')
notchify quit          # Quit the running app
notchify config        # Interactive setup (hooks, sounds, startup, login item)
```

```sh
notchify set start     # Play startup animation (mascot appears)
notchify set working   # Claude is using a tool
notchify set waiting   # Claude needs your attention
notchify set done      # Claude finished a turn
notchify set error     # Something went wrong
notchify set bye       # Play goodbye animation (mascot disappears)
notchify set idle      # Hide the mascot immediately
```

The `start` animation plays automatically when you run `claude` in the terminal if you enable the shell wrapper in `notchify config` → Startup animation. Claude Code hooks trigger the other states — enable them in `notchify config` → Hooks.

---

## Animations

Notchify loads PNG frames from its resource bundle at startup. Each animation is a numbered sequence of frames:

| State     | Files                   | Loop  |
|-----------|-------------------------|-------|
| `start`   | `start_00.png` …        | once  |
| `working` | `work_0.png` … `work_2.png` | loop |
| `waiting` | `wait_00.png` … `wait_09.png` | loop |
| `done`    | `done_00.png` … `done_03.png` | once |
| `bye`     | `bye_00.png` …          | once  |

Source files (`.piskel`) are in `piskel/`. Export 60×36 px PNG frames, drop them into `Sources/Notchify/Resources/`, and rebuild.

---

## Sounds

Notchify plays a sound on each state change. Edit `~/.config/notchify/sounds.json`:

```json
{
  "start":   { "system": "Hero" },
  "done":    { "system": "Glass" },
  "waiting": { "system": "Ping" },
  "error":   { "system": "Basso" },
  "working": null,
  "idle":    null
}
```

Use `{ "system": "<name>" }` for built-in macOS sounds (Hero, Glass, Ping, Basso, Blow, Bottle, Frog, Funk, Morse, Pop, Purr, Sosumi, Submarine, Tink) or `{ "file": "~/path/to/sound.mp3" }` for a custom file. Set to `null` to disable.

Changes take effect immediately — no restart needed.

---

## Project structure

```
Sources/
  Notchify/          – main GUI app (NSPanel overlay)
    CrabRenderer.swift  pixel animation renderer
    StatusServer.swift  Unix socket IPC server
    NotchWindowController.swift  notch-area window
  notchify-cli/      – CLI binary
    main.swift          command dispatcher
    Configurator.swift  interactive config menu
scripts/
  build.sh           compile + create .app bundle
  setup.sh           install CLI, hooks, login item
  reset.sh           undo setup (for testing)
piskel/              animation source files
```

---

## Contributing

1. `./scripts/build.sh` — build both binaries and bundle
2. `pkill -f Notchify; open Notchify.app` — restart the app
3. `notchify set <status>` — test a state manually

The app communicates over a Unix domain socket at `/tmp/notchify.sock`. The CLI connects and sends plain-text status names.

---

## License

MIT — see [LICENSE](LICENSE).
