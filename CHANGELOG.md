# Changelog

## [1.8.0] - 2026-10-30

### Added
- `getRoundOverButtons()` may return a list of rows instead of one row, so a
  game can stack "Next round" over "New game" when the narrow landscape side
  panel can't fit them side by side. A single row works as before.

## [1.7.0] - 2026-10-30

### Added
- Daily Challenge for every puzzle: `DailySeed.run(key, fn)` runs a generator
  under a seed made of today's date and the game's id, so every device builds
  the same grid all day (LuaJIT's PRNG is the same everywhere).
  `math.randomseed` is a no-op meanwhile, since some generators reseed from the
  clock, and the clock reseeds it afterwards. `ScreenBase:onDailyGame()` and
  `makeDailyButtonConfig()` put it in the title-bar menu, right after
  "New game". New shared label "Daily Challenge" (fr/es/de).

### Fixed
- `Timer:serialize()` stopped the clock. Games save after every move, so in
  every game that did not restart it the clock froze at the first move and the
  "Solved! Time" showed only the time to that move. It now reads the clock and
  leaves it running.

## [1.6.0] - 2026-10-30

### Added
- Shared controls on `ScreenBase`, so every game's bottom controls look and
  size the same: `getGutter()`, `getControlsWidth()`, `buildActionBar()`,
  `buildNumberPad()`, `joinStatus()` (with `STATUS_SEP`, " · ") and
  `getBoardBudget()`, which says how much room the board has once the title bar
  and the controls are placed. See "Screen layout" in the README.
- `GridWidgetBase` takes `max_size`, the board side in pixels, overriding
  `size_ratio`, so a screen can give its board all the room it has.
- Menu labels shared across the fleet, with fr/es/de: "Language: %1",
  "Opponent: %1", "Players: %1", "Show solution", "Hide solution". The README's
  "Screen layout" section now describes the menu order every game follows.
- Round-over action bar: `ScreenBase:isRoundOver()`, `getRoundOverButtons()`
  and `refreshActionBar()`. Once a round is won or lost, the action bar shows
  "New game" in place of the game's actions, so the next round no longer has to
  be started from the title-bar menu. `buildActionBar` now returns a small
  wrapper (`self.action_bar`) whose `getButtonById` still works;
  `buildActionBar({})` is a bar that stays empty until the round is over, for
  games whose only control is a keyboard.
- `KeyboardWidget.build` takes `key_height`, so word games can give their
  keys a finger-sized height instead of the Button's natural ~6 mm.

### Changed
- The status line (`self.status_text`) wraps in landscape, where the controls
  are a narrow side panel, instead of being cut off with "…". It only breaks
  between " · " parts (a part too long for one line wraps between its words,
  never inside one). Portrait keeps a single line.
- `KeyboardWidget` follows KOReader's language when no `layout` is given:
  AZERTY in French, QWERTZ in German, QWERTY otherwise (`layoutForLanguage()`,
  plus `ROWS_QWERTZ`). It used to follow the game's word list, which defaults
  to English, so a French device showed QWERTY. Word games no longer pass a
  layout.

### Fixed
- `ScreenBase:onHint` saved with no data, which `PluginBase:saveState`
  stores as nil: every applied hint wiped the saved game. It now saves
  `serializeState()`, like `closeScreen`, and refreshes the action bar, since
  a hint can fill the last cell.
- `GridWidgetBase` number and note fonts were never fitted to the cell. The
  size search measured text with the cell width as the cut-off, so the width
  test always passed, and took `y_bottom - y_top` as the ink height, which is
  negative for digits -- so every size was accepted and the largest one won,
  then scaled up again by DPI. Digits now fit their cell on every screen.


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
