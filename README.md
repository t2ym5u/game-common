# game-common

Shared library for all game plugins in this repository.

## Modules

| File | Purpose |
|---|---|
| `plugin_base.lua` | Base plugin class — settings, menu registration, screen lifecycle |
| `screen_base.lua` | Base full-screen widget — layout, status bar, close, portrait/landscape |
| `hint.lua` | Hint button machinery — `Hint.install(BoardClass, spec)` gives a board `findHint`/`applyHint`; `ScreenBase:onHint` drives the two-tap reveal |
| `grid_widget_base.lua` | Base grid board widget — sizing, fonts, tap + long-press, refresh |
| `grid_utils.lua` | Grid / table utilities — create, copy, shuffle, map, filter |
| `undo_stack.lua` | Generic undo stack with optional max size and serialization |
| `timer.lua` | Elapsed-time tracker with MM:SS formatting and persistence |
| `score_tracker.lua` | Current score + best score persistence via plugin settings |
| `menu_helper.lua` | Picker menu builder — difficulty, size, and generic option menus |
| `settings_dialog.lua` | Multi-section settings dialog (picker, toggle, action, info rows) |
| `i18n.lua` | Drop-in replacement for `gettext` — 350+ FR translations, falls back to KOReader gettext. Add `de`, `es`, … entries to extend. |
| `stats_exporter.lua` | Cross-plugin play tracker — records sessions, last_played, time_played per plugin. Read by Dashboard. |
| `daily_seed.lua` | Deterministic daily seed for puzzle-of-the-day modes. `DailySeed.today()` + `DailySeed.rng(seed)`. |

## How to use in a plugin

Each plugin's `main.lua` adds `game-common` to the Lua path via a `common/`
symlink that lives inside the plugin directory:

```
minesweeper.koplugin/
├── common/          ← symlink → ../../game-common
├── main.lua
├── screen.lua
├── board.lua
└── board_widget.lua
```

`main.lua` path setup (first lines):

```lua
local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. package.path
```

Create the symlink once per plugin during development:

```sh
cd minesweeper.koplugin
ln -s ../../game-common common
```

For device deployment the build/release script should copy the `game-common/`
directory into each plugin as `common/` instead of using a symlink.

## Inheritance diagram

```
PluginBase (plugin_base.lua)
└── MyGamePlugin (main.lua)

ScreenBase (screen_base.lua)
└── MyGameScreen (screen.lua)
    ├── uses MenuHelper      (menu_helper.lua)
    ├── uses SettingsDialog  (settings_dialog.lua)
    └── uses UndoStack       (undo_stack.lua)

GridWidgetBase (grid_widget_base.lua)
└── MyBoardWidget (board_widget.lua)

(standalone helpers)
  Timer          (timer.lua)
  ScoreTracker   (score_tracker.lua)
  grid_utils     (grid_utils.lua)
```

## Minimal plugin skeleton

See `_skeleton.koplugin/` for a ready-to-copy starting point.

## Hints

`ScreenBase:onHint()` is shared, but boards are not: some keep a grid of
digits, some booleans, some rectangles or bridges. So a board describes itself
once and gets the rest for free:

```lua
Hint.install(BinairoBoard, {
    isEmpty     = function(v) return v == nil end,   -- 0 is a real value here
    getUser     = function(b, r, c) return b.cells[r] and b.cells[r][c] end,
    getSolution = function(b, r, c) return b.solution[r][c] end,
    isGiven     = function(b, r, c) return b.given[r] and b.given[r][c] end,
    setCell     = function(b, r, c, v) return b:setCellValue(r, c, v) end,
})
```

Two things are worth getting right in a spec:

- **`isEmpty`** decides what counts as an untouched cell. The default (nil, 0
  or false) is wrong wherever one of those is a real value — binairo's 0, for
  instance — and would make the module offer to "fill" cells the player has
  already answered.
- **`equals`** decides what counts as a mistake. Where a board has optional
  annotations (a nonogram X, a light-up dot, a star-battle dot), compare only
  the state that decides the puzzle, or the player gets told their perfectly
  correct notes are errors.

There is no deductive solver behind this, unlike sudoku-common's: the cell
offered is chosen by a neighbour-count heuristic (cells next to filled ones
read as the ones a player could plausibly work out), and the reveal comes from
the stored solution. The choice is deliberately deterministic — `ScreenBase`
tells "show me where" from "now fill it" by checking whether the target moved,
so a randomised pick would reset to step one on every tap and never reveal.
