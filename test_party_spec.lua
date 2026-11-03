-- Spec for party.lua's players and scores (the UI functions need KOReader).
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. package.path

package.loaded["i18n"] = function(s) return s end
package.loaded["ffi/util"] = { template = function(s, ...)
    local args = { ... }
    return (s:gsub("%%(%d)", function(n) return tostring(args[tonumber(n)]) end))
end }

local Party = require("party")

local function fakePlugin()
    local store = {}
    return {
        getSetting  = function(_self, k, d) if store[k] == nil then return d end return store[k] end,
        saveSetting = function(_self, k, v) store[k] = v end,
    }
end

describe("Party players", function()
    it("defaults, then remembers typed names per seat", function()
        local p = fakePlugin()
        assert.are.same({ "Player 1", "Player 2" }, Party.loadPlayers(p, 2))
        Party.savePlayers(p, { "Alice", "Bob", "Chloé" })
        Party.savePlayers(p, { "Anne" })
        assert.are.same({ "Anne", "Bob", "Chloé", "Player 4" }, Party.loadPlayers(p, 4))
    end)

    it("clamps the remembered player count", function()
        local p = fakePlugin()
        assert.are.equal(2, Party.loadCount(p))
        Party.saveCount(p, 99)
        assert.are.equal(Party.MAX_PLAYERS, Party.loadCount(p))
    end)

    it("cleans names on a UTF-8 boundary", function()
        assert.are.equal("Zoé", Party.cleanName("  Zoé\n"))
        assert.are.equal(16, select(2, Party.cleanName(string.rep("é", 20)):gsub("[^\128-\191]", "")))
    end)
end)

describe("Party teams", function()
    it("keeps team names and count apart from the players'", function()
        local p = fakePlugin()
        local T = { teams = true, max = 4 }
        Party.savePlayers(p, { "Alice" })
        Party.savePlayers(p, { "Les Renards" }, T)
        assert.are.same({ "Les Renards", "Team 2" }, Party.loadPlayers(p, 2, T))
        assert.are.same({ "Alice", "Player 2" }, Party.loadPlayers(p, 2))
        Party.saveCount(p, 6, T)
        assert.are.equal(4, Party.loadCount(p, T))
        assert.are.equal(2, Party.loadCount(p))
    end)
end)

describe("Party scores", function()
    it("awards, ranks with shared ranks, and finds the leaders", function()
        local s = Party.newScores({ "A", "B", "C" })
        Party.award(s, 2, 3); Party.award(s, 3, 3); Party.award(s, 1)
        Party.award(s, 9, 5) -- unknown seat: ignored
        local r = Party.ranking(s)
        assert.are.same({ 2, 3, 1 }, { r[1].index, r[2].index, r[3].index })
        assert.are.same({ 1, 1, 3 }, { r[1].rank, r[2].rank, r[3].rank })
        assert.are.same({ 2, 3 }, Party.leaders(s))
        assert.are.equal("A 1 · B 3 · C 3", Party.statusText(s))
        assert.are.equal("1. B — 3", Party.scoreLines(s)[1])
    end)

    it("copies and restores, rejecting broken tables", function()
        local s = Party.newScores({ "A", "B" }); Party.award(s, 1, 2); Party.nextRound(s)
        local c = Party.copyScores(s); Party.award(s, 1, 5)
        assert.are.equal(2, c.points[1]); assert.are.equal(1, c.round)
        assert.are.equal(c, Party.restoreScores(c))
        assert.is_nil(Party.restoreScores({ names = { "A" }, points = {} }))
        assert.is_nil(Party.restoreScores("x"))
    end)
end)
