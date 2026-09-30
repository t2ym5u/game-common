# Changelog

## [1.5.0] - 2026-09-30

### Added
- `PluginBase:getPluginId()` -- the plugin's stable id, captured at init time.
- `PluginBase:stopPlugin()` and `PluginBase:deletePluginSettings()`, the hooks
  KOReader 2026.07 calls when a plugin is deleted from the device (PR #15240).
  The first closes an open game screen, the second drops the game's row from
  the shared `game_stats.lua` so a deleted game stops showing up in Dashboard.
- `StatsExporter:remove()`.

### Fixed
- Play statistics were recorded under a key no tool could match.
  `ReaderUI`/`FileManager:registerModule()` rewrite a plugin instance's `name`
  to `reader<id>` / `filemanager<id>` immediately after it is built, so every
  game's stats were split across two rows and neither one carried the plugin's
  actual id. Settings and stats are now keyed on `getPluginId()`, and rows
  written under the old keys are merged back on first read.

## [1.3.0] - 2026-09-30

### Added
- `hint.lua` — the machinery behind the Hint button. Boards differ far more
  than they look (grids of digits, grids of booleans, rectangles, bridges), so
  a board describes itself once through a spec table and gets `findHint` and
  `applyHint` for free via `Hint.install`.
- `ScreenBase:onHint()` — drives the two-tap reveal: the first tap names the
  cell that is about to give, the second acts on it. A cell contradicting the
  solution always takes priority over revealing a fresh one, and is emptied
  rather than solved.

## [1.2.7] - 2026-07-29

### Added
- `keyboard_widget.lua`: shared on-screen letter keyboard (QWERTY/AZERTY,
  optional ⌫/↵ special keys, optional per-key background coloring). Used by
  `wordle`, `crossword`, `cryptogram`, `arrowwords`, and `wordladder`,
  replacing each plugin's own hand-rolled `ButtonTable`-based keyboard.

### Changed
- `grid_widget_base.lua`: added a `max_value` option so the auto-sized
  number font is measured against the widest string the widget will
  actually paint (e.g. `n*n` for a fill-the-grid game) instead of always
  assuming a single digit, which could overflow into neighboring cells on
  larger grids. Used by `hidato` and `numbrix`.

## [1.2.6] - 2026-07-17

### Fixed
- `i18n.lua`: restore `sudokukiller.koplugin`'s one FR string here. That
  plugin is sudoku_common-family (vendors its own `common/`), not
  game-common-family, so it has no reliable `package.path` to this module —
  the 1.2.5 migration wrongly moved it out to a local `i18n_fr.lua` and
  called `i18n.extend()` at plugin load time, which crashed on load and
  dropped the plugin from KOReader's Tools menu entirely.

## [1.2.5] - 2026-07-17

### Changed
- `i18n.lua`: added an `extend(tbl)` API so each plugin can merge its own
  translations in from a local `i18n_fr.lua`, called via
  `require("i18n").extend(lrequire("i18n_fr"))` in `main.lua`.
- Moved ~35 plugins' plugin-specific translation strings out of the shared
  table into each plugin's own repo (e.g. `dice.koplugin`, `dashboard.koplugin`,
  `boggle.koplugin`, `balance.koplugin`, ...). Only strings genuinely shared
  by several plugins remain here.

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
