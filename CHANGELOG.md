# Changelog

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
