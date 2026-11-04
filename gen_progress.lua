-- ---------------------------------------------------------------------------
-- gen_progress.lua — "Generating puzzle…" progress bar around a blocking
-- computation (puzzle generation, a long hint search).
--
--   local GenProgress = require("gen_progress")
--   GenProgress.run(function(on_progress)
--       board:generate(on_progress)       -- calls on_progress(0..1) as it goes
--   end)
--   GenProgress.run(fn, { title = _("Searching…") })
--
-- fn(on_progress) runs synchronously; the work calls on_progress(fraction)
-- (0..1) from time to time. The ProgressbarDialog only appears once the work
-- has already run past SHOW_DELAY_MS, so a quick generation never flashes a
-- dialog on e-ink. ProgressbarDialog:reportProgress forces its own repaint
-- (UIManager:forceRePaint), which is what lets it update while the work
-- holds the UI thread. Calling on_progress often is cheap: before the delay
-- it only reads the clock, after it the dialog throttles its own repaints.
--
-- The clock here only decides whether to show the dialog: the work never
-- sees it, so a seed still builds the same puzzle on every device (the Daily
-- Challenge, run through DailySeed.run, relies on that).
--
-- Promoted from the copies vendored in tracks, heyawake and mosaic (same
-- API), and the same pattern as sudoku-common/base_screen.lua's
-- generateWithProgress.
-- ---------------------------------------------------------------------------

local ProgressbarDialog = require("ui/widget/progressbardialog")
local time              = require("ui/time")
local _                 = require("i18n")
local unpack            = unpack or table.unpack -- luacheck: ignore

local GenProgress = {
    SHOW_DELAY_MS = 200,
}

-- opts.title: dialog title (default "Generating puzzle…").
-- Returns whatever fn returns; errors are re-raised after the dialog closes.
function GenProgress.run(fn, opts)
    opts = opts or {}
    local start = time.now()
    local dialog
    local res = { n = 0 }
    local function keep(ok, ...)
        res = { n = select("#", ...), ok = ok, ... }
    end
    keep(pcall(fn, function(fraction)
        if not dialog then
            if time.to_ms(time.since(start)) < GenProgress.SHOW_DELAY_MS then return end
            dialog = ProgressbarDialog:new{
                title                = opts.title or _("Generating puzzle…"),
                progress_max         = 1,
                refresh_time_seconds = 0.15,
                dismissable          = false,
            }
            dialog:show()
        end
        dialog:reportProgress(math.max(0, math.min(1, fraction or 0)))
    end))
    if dialog then dialog:close() end
    if not res.ok then error(res[1], 0) end
    return unpack(res, 1, res.n)
end

return GenProgress
