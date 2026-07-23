# Changelog

## v1.3.0 — 2026-07-23

### Fixes
- fix(startup): keep login item working across Homebrew upgrades (#9)

### Notes
- The login item plist stored a versioned Cellar path (`/opt/homebrew/Cellar/notchify/<version>/...`). Once `brew upgrade` removed that version, launchd failed to spawn the app at every login with `EX_CONFIG`, while System Settings still showed the login item switched on — the plist file itself was still there. The app had to be started by hand with `notchify launch`.
- `Notchify.app` is now resolved through the version-stable `/opt/homebrew/opt/notchify` symlink, which survives upgrades. The Homebrew formula writes the same stable path to `~/.config/notchify/app_path`.
- New `notchify repair` command rewrites a login item plist pointing at a binary that no longer exists. `notchify launch` runs the same repair automatically, and the formula's `post_install` calls it so existing installs heal on upgrade.
- Toggling the login item now `launchctl bootstrap`s / `bootout`s the job, so it takes effect immediately instead of at the next login.

## v1.2.0 — 2026-05-21

### Features
- feat(hooks): multi-target support + Integrations submenu (#7)

### Notes
- Hooks can now be installed across multiple Claude config dirs (`~/.claude`, `~/.claude-work`, `~/.claude-personal`, ...). Useful for users splitting accounts via `CLAUDE_CONFIG_DIR`. Target list persists at `~/.config/notchify/hook_targets.json` and is editable via `notchify config → Integrations → Config targets` or the new `notchify hooks targets list|add|remove` CLI.
- The TUI's `Hooks ›` submenu is renamed to **Integrations** and now also hosts the intro/outro shell wrapper toggle (removed from the main menu). A master toggle at the top of the submenu flips all hooks plus the shell wrapper in one go — convenient for clean uninstall.
- Unchecking a target in the picker or running `notchify hooks targets remove <path>` strips Notchify's own hook entries from that dir's `settings.json` before forgetting it. Unrelated hooks in the same file are preserved.
- New `--config-dir <path>` flag (repeatable) on `notchify launch` and `notchify hooks reinstall` for scripted one-off overrides without mutating the saved target list.
- `notchify launch` prints a one-line hint when multiple Claude config dirs are detected on first run.

## v1.1.0 — 2026-04-29

### Features
- feat(display): per-screen profiles + .center direction (#5)

### Notes
- `display.json` schema gains explicit `notch` and `external` profiles, each with own `horizontalOffset`, `verticalOffset`, `mascotDirection`. Auto-selected at runtime by screen notch presence.
- New `MascotDirection.center` (external profile only) — symmetric mascot growth around screen center, fixes default off-center placement on monitors without a notch.
- Legacy flat `display.json` migrates automatically into the `notch` profile on first launch; external profile defaults to `.center`.
- CLI configurator (`notchify config` → Display) now renders both profiles sequentially with explicit headings instead of a tab switcher.

## v1.0.32 — 2026-04-21

### Fixes
- fix(animation): unify all mascot animation speeds to 0.20s (#3)

## v1.0.31 — 2026-04-21

### Features
- feat(animation): refresh waiting mascot + add update docs (#1)
