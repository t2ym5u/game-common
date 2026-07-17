# Changelog

## [1.2.4] - 2026-07-17

### Added
- `i18n.lua`: added French translations for `dice.koplugin` UI strings.

## [1.2.3] - 2026-07-17

### Removed
- `chess_pieces.lua` and `chess_pieces_img/*.png`, moved out to
  `echecs.koplugin` and `coursdechecs.koplugin` as vendored, duplicated files.
  They were only ever used by those two plugins — keeping them here meant
  every other game-common consumer's shared-library fetch pulled chess PNGs
  it would never use. Same rationale as the sudoku-common family's vendored,
  diverged files.

## [1.2.2] - 2026-07-17

### Fixed
- `chess_pieces.lua` and `chess_pieces_img/*.png` have been in this repo since
  the initial commit, but manifest.json's `common.files` list never included
  them, so PluginManager's `ensureCommon()` never fetched them onto real
  devices. echecs/coursdechecs always fell back to pixel-art piece rendering
  there, while local checkouts (which have every file on disk regardless of
  the manifest) always rendered the real piece images. No code here changed;
  this tag exists purely to bump the version so devices already on 1.2.1
  redownload once the manifest is corrected.

## [1.2.0] - 2026-07-10

### Added
- `stats_exporter.lua`: cross-plugin play-session tracker. Records sessions, last_played
  and time_played for each plugin automatically via plugin_base.
- `daily_seed.lua`: deterministic daily seed (Park-Miller LCG) for puzzle-of-the-day modes.
- `plugin_base.lua`: auto-records session count and time to stats_exporter on screen close.
- `i18n.lua`: added translations for Dashboard UI strings, Binairo, and time-format helpers.

## [1.1.0] - 2026-07-08

### Added
- `i18n.lua`: drop-in replacement for `require("gettext")` with 350+ FR translations.
  Auto-detects KOReader language setting; falls back to gettext for unknown languages.
  Add `de`, `es`, … keys to any entry to support more languages without touching plugin code.
- All modules (`screen_base`, `menu_helper`, `plugin_base`, `settings_dialog`, `undo_stack`)
  now use `require("i18n")` — buttons, menus, and status messages translate automatically.
- `screen_base.lua`: `makeRulesButtonConfig` uses `_.lang()` from the i18n module.

## [1.0.0] - 2025-11-01

### Added
- Initial release (split from koreader-plugins monorepo)
