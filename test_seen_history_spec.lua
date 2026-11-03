-- Spec for seen_history.lua (pure Lua).
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. package.path

local SeenHistory = require("seen_history")

local function fakePlugin()
    local store = {}
    return {
        store = store,
        getSetting  = function(_self, k, d) if store[k] == nil then return d end return store[k] end,
        saveSetting = function(_self, k, v) store[k] = v end,
    }
end

local function pool(n, prefix)
    local t = {}
    for i = 1, n do t[i] = (prefix or "w") .. i end
    return t
end

describe("SeenHistory", function()
    it("never repeats until the pool is used up, then starts a new cycle", function()
        local p = fakePlugin()
        local seen = SeenHistory.open(p, "words")
        local words, got = pool(10), {}
        for _ = 1, 10 do
            local w = seen:pick(words)
            assert.is_nil(got[w], "repeated " .. tostring(w))
            got[w] = true
        end
        -- 11th draw: the pool was fully seen, a new cycle begins
        assert.is_truthy(seen:pick(words))
        assert.are.equal(1, seen:count())
    end)

    it("remembers across sessions (reopened from the settings)", function()
        local p = fakePlugin()
        local words = pool(6)
        local first = SeenHistory.open(p, "cards"):draw(words, 4)
        local again = SeenHistory.open(p, "cards"):draw(words, 2)
        local all = {}
        for _, w in ipairs(first) do all[w] = true end
        for _, w in ipairs(again) do
            assert.is_nil(all[w], "seen in the previous session: " .. w)
            all[w] = true
        end
    end)

    it("draws distinct items, unseen first then the least recently seen", function()
        local p = fakePlugin()
        local seen = SeenHistory.open(p, "q")
        local qs = pool(5)
        seen:mark({ "w1", "w2" })
        seen:mark("w3")
        local d = seen:draw(qs, 4)
        assert.are.equal(4, #d)
        local s = {}
        for _, q in ipairs(d) do s[q] = true end
        assert.is_true(s.w4 and s.w5 and s.w1 and s.w2, "w1/w2 are the oldest seen")
        assert.is_nil(s.w3)
    end)

    it("forgets only the exhausted pool's ids", function()
        local p = fakePlugin()
        local seen = SeenHistory.open(p, "mix")
        local a, b = pool(3, "a"), pool(3, "b")
        seen:draw(b, 2)
        seen:draw(a, 3)
        seen:draw(a, 1) -- a exhausted: only a's ids are forgotten
        assert.is_true(seen:has("b1") or seen:has("b2") or seen:has("b3"))
        assert.are.equal(3, seen:count())
    end)

    it("caps the stored history at max, oldest forgotten first", function()
        local p = fakePlugin()
        local seen = SeenHistory.open(p, "cap", { max = 3 })
        seen:mark({ "x1", "x2", "x3", "x4" })
        assert.is_false(seen:has("x1"))
        assert.is_true(seen:has("x4"))
        assert.are.same({ "x2", "x3", "x4" }, p.store.seen_cap)
    end)

    it("identifies table items by their fields or a custom id_of", function()
        local p = fakePlugin()
        local seen = SeenHistory.open(p, "t")
        seen:mark({ { word = "chat" }, { question = "Q?" } })
        assert.is_true(seen:has({ word = "chat" }))
        assert.is_true(seen:has("Q?"))
        local custom = SeenHistory.open(p, "c", { id_of = function(it) return it.k end })
        custom:mark({ { k = 7 } })
        assert.is_true(custom:has({ k = 7 }))
    end)

    it("ignores a corrupt saved value", function()
        local p = fakePlugin()
        p.store.seen_bad = "nope"
        assert.are.equal(0, SeenHistory.open(p, "bad"):count())
    end)
end)
