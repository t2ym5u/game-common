-- Spec for hint.lua. Self-contained: only requires files from this directory,
-- so it runs from game-common's own repo and from the monorepo alike.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. package.path

local Hint = require("hint")

-- Smallest board the module can drive: a digit grid where 0 means empty.
local function makeBoard(user, solution, given)
    return { n = #solution, user = user, solution = solution, given = given }
end

local SPEC = {
    getUser     = function(b, r, c) return b.user[r][c] end,
    getSolution = function(b, r, c) return b.solution[r][c] end,
    isGiven     = function(b, r, c) return b.given and b.given[r][c] == true end,
    setCell     = function(b, r, c, v) b.user[r][c] = v; return true end,
    blank       = 0,
}

describe("Hint.gridHint", function()

    it("offers an empty cell, carrying the value that belongs there", function()
        local b = makeBoard({ {1, 0}, {0, 0} }, { {1, 2}, {2, 1} })
        local step = Hint.gridHint(b, SPEC)
        assert.are.equal("fill", step.kind)
        assert.are.equal(b.solution[step.r][step.c], step.value)
        assert.are.equal(0, b.user[step.r][step.c])
    end)

    it("reports a contradicting entry before any empty cell", function()
        -- R2C2 is wrong; plenty of blanks remain, but the mistake comes first.
        local b = makeBoard({ {0, 0}, {0, 9} }, { {1, 2}, {2, 1} })
        local step = Hint.gridHint(b, SPEC)
        assert.are.equal("mistake", step.kind)
        assert.are.equal(2, step.r)
        assert.are.equal(2, step.c)
    end)

    it("never touches a given cell, right or wrong", function()
        local b = makeBoard({ {9, 0}, {0, 0} }, { {1, 2}, {2, 1} }, { {true, false}, {false, false} })
        local step = Hint.gridHint(b, SPEC)
        assert.are.equal("fill", step.kind)
        assert.is_false(step.r == 1 and step.c == 1)
    end)

    it("says the grid is complete once nothing differs", function()
        local b = makeBoard({ {1, 2}, {2, 1} }, { {1, 2}, {2, 1} })
        local step, reason = Hint.gridHint(b, SPEC)
        assert.is_nil(step)
        assert.are.equal("complete", reason)
    end)

    it("is deterministic -- the same board always yields the same target", function()
        -- ScreenBase:onHint tells "show me where" from "now fill it" by seeing
        -- whether the target moved, so a wandering pick would never reveal.
        local b = makeBoard({ {0, 0, 0}, {0, 0, 0}, {0, 0, 0} },
                            { {1, 2, 3}, {2, 3, 1}, {3, 1, 2} })
        local first = Hint.gridHint(b, SPEC)
        for _ = 1, 20 do
            local again = Hint.gridHint(b, SPEC)
            assert.are.equal(first.r, again.r)
            assert.are.equal(first.c, again.c)
        end
    end)

    it("prefers a cell with filled neighbours over an isolated one", function()
        -- R1C1's neighbours are all empty; R3C3 sits against three filled
        -- cells, so it is the one a player could plausibly work out.
        local b = makeBoard({ {0, 0, 0, 0},
                              {0, 0, 0, 0},
                              {0, 0, 0, 1},
                              {0, 0, 1, 1} },
                            { {1, 2, 3, 4},
                              {2, 3, 4, 1},
                              {3, 4, 1, 1},
                              {4, 1, 1, 1} })
        local step = Hint.gridHint(b, SPEC)
        assert.are.equal(3, step.r)
        assert.are.equal(3, step.c)
    end)

    it("honours a custom notion of empty", function()
        -- 0 is a real value here (binairo), so only nil means empty.
        local b = { n = 2, user = { {0, nil}, {nil, nil} }, solution = { {0, 1}, {1, 0} } }
        local step = Hint.gridHint(b, {
            isEmpty     = function(v) return v == nil end,
            getUser     = function(bb, r, c) return bb.user[r][c] end,
            getSolution = function(bb, r, c) return bb.solution[r][c] end,
            setCell     = function(bb, r, c, v) bb.user[r][c] = v; return true end,
        })
        -- R1C1 holds a correct 0: it must count as filled, not as a blank.
        assert.are.equal("fill", step.kind)
        assert.is_false(step.r == 1 and step.c == 1)
    end)

    it("honours a custom equality, so optional annotations are not mistakes", function()
        -- Nonogram: 1 filled, -1 a crossed-out cell, 0 untouched. Crossing out
        -- a cell the solution leaves blank is correct play, not an error.
        local b = { n = 2, user = { {-1, 0}, {0, 0} }, solution = { {false, true}, {true, false} } }
        local spec = {
            getUser     = function(bb, r, c) return bb.user[r][c] end,
            getSolution = function(bb, r, c) return bb.solution[r][c] and 1 or 0 end,
            isEmpty     = function(v) return v == 0 end,
            equals      = function(u, s) return (u == 1) == (s == 1) end,
            setCell     = function(bb, r, c, v) bb.user[r][c] = v; return true end,
            blank       = 0,
        }
        local step = Hint.gridHint(b, spec)
        assert.are.equal("fill", step.kind)
        assert.are.equal(1, step.value)
    end)
end)

describe("Hint.install", function()
    local Board = {}
    Board.__index = Board
    Hint.install(Board, SPEC)

    local function newBoard(user, solution)
        return setmetatable({ n = #solution, user = user, solution = solution }, Board)
    end

    it("gives the class findHint, applyHint and a hint counter", function()
        local b = newBoard({ {0, 0}, {0, 0} }, { {1, 2}, {2, 1} })
        assert.are.equal(0, b:getHintsUsed())
        local step = b:findHint()
        assert.is_true(b:applyHint(step))
        assert.are.equal(step.value, b.user[step.r][step.c])
        b:noteHintUsed()
        assert.are.equal(1, b:getHintsUsed())
    end)

    it("empties a wrong cell rather than solving it for the player", function()
        local b = newBoard({ {9, 0}, {0, 0} }, { {1, 2}, {2, 1} })
        local step = b:findHint()
        assert.are.equal("mistake", step.kind)
        assert.is_true(b:applyHint(step))
        assert.are.equal(0, b.user[1][1])
    end)

    it("uses clearCell when the board has one", function()
        local cleared = false
        local C = {}
        C.__index = C
        Hint.install(C, {
            getUser     = function(b, r, c) return b.user[r][c] end,
            getSolution = function(b, r, c) return b.solution[r][c] end,
            setCell     = function() error("setCell must not be used to clear here") end,
            clearCell   = function(b, r, c) cleared = true; b.user[r][c] = 0; return true end,
        })
        local b = setmetatable({ n = 2, user = { {9, 0}, {0, 0} },
                                 solution = { {1, 2}, {2, 1} } }, C)
        assert.is_true(b:applyHint(b:findHint()))
        assert.is_true(cleared)
    end)

    it("walks a whole grid to completion, one hint at a time", function()
        local b = newBoard({ {0, 0, 0}, {0, 0, 0}, {0, 0, 0} },
                           { {1, 2, 3}, {2, 3, 1}, {3, 1, 2} })
        local applied = 0
        while true do
            local step = b:findHint()
            if not step then break end
            assert.is_true(b:applyHint(step))
            applied = applied + 1
            assert.is_true(applied <= 9, "more hints than cells")
        end
        assert.are.equal(9, applied)
        for r = 1, 3 do
            for c = 1, 3 do assert.are.equal(b.solution[r][c], b.user[r][c]) end
        end
    end)
end)
