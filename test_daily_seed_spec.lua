-- Spec for daily_seed.lua. Self-contained: only requires files from this
-- directory, so it runs from game-common's own repo and from the monorepo alike.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. package.path

local DailySeed = require("daily_seed")

local function draws(n)
    local out = {}
    for i = 1, n do out[i] = math.random(1000000) end
    return table.concat(out, ",")
end

describe("DailySeed.run", function()

    it("draws the same sequence for the same key on the same day", function()
        local a, b
        DailySeed.run("nurikabe", function() a = draws(20) end)
        DailySeed.run("nurikabe", function() b = draws(20) end)
        assert.are.equal(a, b)
    end)

    it("draws a different sequence for another game", function()
        local a, b
        DailySeed.run("nurikabe", function() a = draws(20) end)
        DailySeed.run("tents", function() b = draws(20) end)
        assert.are_not.equal(a, b)
    end)

    it("ignores a generator reseeding from the clock", function()
        local a, b
        DailySeed.run("bridges", function() a = draws(20) end)
        DailySeed.run("bridges", function()
            math.randomseed(os.time() + math.random(1000))
            b = draws(20)
        end)
        local c
        DailySeed.run("bridges", function()
            math.random(1000)
            c = draws(20)
        end)
        -- The reseed is a no-op; only the one draw it made shifts the sequence.
        assert.are.equal(c, b)
        assert.are_not.equal(a, b)
    end)

    it("restores math.randomseed, even when the generator fails", function()
        local randomseed = math.randomseed
        assert.has_error(function()
            DailySeed.run("cave", function() error("boom") end)
        end)
        assert.are.equal(randomseed, math.randomseed)
        local seq
        DailySeed.run("cave", function() seq = draws(5) end)
        assert.are_not.equal(seq, draws(5))
    end)

end)
