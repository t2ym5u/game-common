-- ---------------------------------------------------------------------------
-- hint.lua — shared machinery behind the Hint button.
--
-- These puzzles have no deductive solver (unlike sudoku-common's, which can
-- name the technique that cracks a cell), so a hint here is a *reveal*, and
-- the module is honest about that: it points at one cell and, on a second tap,
-- fills it in from the stored solution.
--
-- What it will not do is hand out a reveal while the board already contains a
-- mistake. A player who has gone wrong needs to know that before they build
-- more work on top of it, so a contradicting entry always takes priority over
-- filling a fresh cell.
--
-- Boards differ far more than they look: some keep a grid of digits, some a
-- grid of booleans, some rectangles or bridges. So this module does not try to
-- read a board directly — each board describes itself once via a spec table,
-- and gets findHint() for free. See gridHint() below.
-- ---------------------------------------------------------------------------

local Hint = {}

local function defaultIsEmpty(v)
    return v == nil or v == 0 or v == false
end

-- Cells that already have a neighbour filled in are the ones a player can
-- most plausibly work out for themselves, so revealing one of those feels
-- like a nudge rather than a random gift. This is a presentation heuristic,
-- not a claim that the cell is deducible -- without a solver we cannot know.
local function neighbourWeight(board, spec, r, c, rows, cols)
    local filled = 0
    for dr = -1, 1 do
        for dc = -1, 1 do
            if dr ~= 0 or dc ~= 0 then
                local nr, nc = r + dr, c + dc
                if nr >= 1 and nr <= rows and nc >= 1 and nc <= cols then
                    local v = spec.getUser(board, nr, nc)
                    if not spec.isEmpty(v) or (spec.isGiven and spec.isGiven(board, nr, nc)) then
                        filled = filled + 1
                    end
                end
            end
        end
    end
    return filled
end

-- spec (every callback takes the board as its first argument):
--   rows, cols            -- grid extent (default board.rows/cols, else board.n)
--   getUser(board,r,c)    -- what the player currently has there
--   getSolution(board,r,c)
--   isGiven(board,r,c)    -- optional: cells the player may not edit
--   setCell(board,r,c,v)  -- writes v; must go through the board's own undo
--   clearCell(board,r,c)  -- optional: empties a cell, when setCell cannot
--   blank                 -- optional: the value meaning "empty" (default nil)
--   isEmpty(v)            -- optional: default nil / 0 / false
--   equals(a,b)           -- optional: default ==
--
-- Returns a step, or nil plus a reason:
--   { kind = "mistake", r, c, value }  -- value is what belongs there
--   { kind = "fill",    r, c, value }
--   nil, "complete"                    -- nothing left that differs
function Hint.gridHint(board, spec)
    -- Most boards are square and carry `n`; minesweeper's presets are
    -- rectangular and carry rows/cols instead, so honour those too.
    local rows    = spec.rows or board.rows or board.n
    local cols    = spec.cols or board.cols or board.n
    local isEmpty = spec.isEmpty or defaultIsEmpty
    local equals  = spec.equals or function(a, b) return a == b end
    spec.isEmpty  = isEmpty

    local mistakes, blanks = {}, {}
    for r = 1, rows do
        for c = 1, cols do
            if not (spec.isGiven and spec.isGiven(board, r, c)) then
                local user = spec.getUser(board, r, c)
                local sol  = spec.getSolution(board, r, c)
                if isEmpty(user) then
                    if not isEmpty(sol) then
                        blanks[#blanks + 1] = { r = r, c = c, value = sol }
                    end
                elseif not equals(user, sol) then
                    mistakes[#mistakes + 1] = { r = r, c = c, value = sol }
                end
            end
        end
    end

    if #mistakes > 0 then
        local pick = mistakes[1]
        return { kind = "mistake", r = pick.r, c = pick.c, value = pick.value }
    end
    if #blanks == 0 then return nil, "complete" end

    -- Deliberately deterministic: the same board must always yield the same
    -- hint. ScreenBase:onHint decides whether a tap is "show me where" or
    -- "now fill it" by checking whether the target moved, so a randomised
    -- pick would reset that to step one on every tap and the reveal would
    -- never arrive. Reading order breaks ties. Applying a hint changes the
    -- board, so successive hints move on their own.
    local best, best_weight = nil, -1
    for _, cell in ipairs(blanks) do
        local w = neighbourWeight(board, spec, cell.r, cell.c, rows, cols)
        if w > best_weight then best, best_weight = cell, w end
    end
    return { kind = "fill", r = best.r, c = best.c, value = best.value }
end

-- Gives a board class findHint() and applyHint(), so a plugin only has to say
-- how its own grid is stored. Everything above stays out of the boards.
function Hint.install(class, spec)
    function class:findHint()
        return Hint.gridHint(self, spec)
    end

    -- A "mistake" step clears the offending cell rather than overwriting it:
    -- the point is to hand the player back the cell they got wrong, not to
    -- solve it for them. "fill" writes the value in.
    function class:applyHint(step)
        if not step then return false end
        if step.kind == "mistake" then
            -- Several boards refuse setCell(r, c, <blank>) outright -- hidato
            -- and numbrix reject anything below 1 -- and expose a clearCell
            -- instead. Use it when the spec names one; otherwise spec.blank is
            -- whatever "empty" means here (nil for a sparse grid, 0 for
            -- digits, false for shading), defaulting to nil.
            if spec.clearCell then
                return spec.clearCell(self, step.r, step.c) ~= false
            end
            return spec.setCell(self, step.r, step.c, spec.blank) ~= false
        end
        return spec.setCell(self, step.r, step.c, step.value) ~= false
    end

    function class:getHintsUsed()
        return self.hints_used or 0
    end

    function class:noteHintUsed()
        self.hints_used = (self.hints_used or 0) + 1
    end
end

return Hint
