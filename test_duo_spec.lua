package.path = "./?.lua;" .. package.path
local Duo = require("duo")

describe("Duo.rng", function()
    it("gives the same sequence for the same seed and salt", function()
        local a, b = Duo.rng(42, "game"), Duo.rng(42, "game")
        for _i = 1, 100 do assert.equals(a:next(), b:next()) end
    end)

    it("gives different sequences for another seed or salt", function()
        local a, b, c = Duo.rng(42, "game"), Duo.rng(43, "game"), Duo.rng(42, "other")
        local same_b, same_c = 0, 0
        for _i = 1, 50 do
            local x = a:next()
            if x == b:next() then same_b = same_b + 1 end
            if x == c:next() then same_c = same_c + 1 end
        end
        assert.equals(0, same_b)
        assert.equals(0, same_c)
    end)

    -- Pinned values: both readers must draw exactly these, whatever they run.
    -- Plain double arithmetic, so Lua 5.x (busted) and LuaJIT agree.
    it("draws the pinned sequence", function()
        local r = Duo.rng(1234, "duo")
        local got = {}
        for i = 1, 5 do got[i] = r:random(1000) end
        local again = Duo.rng(1234, "duo")
        for i = 1, 5 do assert.equals(got[i], again:random(1000)) end
        assert.same({ 50, 496, 36, 494, 542 }, got)
    end)

    it("keeps random(m, n) in range and covers it", function()
        local r = Duo.rng(7)
        local seen = {}
        for _i = 1, 2000 do
            local x = r:random(3, 8)
            assert.is_true(x >= 3 and x <= 8)
            seen[x] = true
        end
        for x = 3, 8 do assert.is_true(seen[x]) end
        local f = r:random()
        assert.is_true(f >= 0 and f < 1)
    end)

    it("shuffles into a permutation", function()
        local t = {}
        for i = 1, 20 do t[i] = i end
        Duo.rng(5):shuffle(t)
        local seen = {}
        for _i, v in ipairs(t) do seen[v] = true end
        for i = 1, 20 do assert.is_true(seen[i]) end
    end)
end)

describe("Duo codes", function()
    it("round-trips every variant", function()
        for nv = 1, 6 do
            for v = 1, nv do
                for _i, seed in ipairs({ 0, 1, 17, Duo.seedCount(nv) - 1 }) do
                    local code = Duo.encode(seed, v, nv)
                    assert.equals(5, #code)
                    local s2, v2 = Duo.decode(code, nv)
                    assert.equals(seed, s2)
                    assert.equals(v, v2)
                end
            end
        end
    end)

    it("refuses any single wrong digit", function()
        local code = Duo.encode(1234, 2, 3)
        for i = 1, 5 do
            local d = tonumber(code:sub(i, i))
            for e = 0, 9 do
                if e ~= d then
                    local bad = code:sub(1, i - 1) .. e .. code:sub(i + 1)
                    assert.is_nil(Duo.decode(bad, 3), bad)
                end
            end
        end
    end)

    it("ignores spaces and dashes, refuses junk", function()
        local code = Duo.encode(55, 1, 1)
        assert.equals(55, (Duo.decode(Duo.format(code), 1)))
        assert.equals(55, (Duo.decode(code:sub(1, 3) .. "-" .. code:sub(4), 1)))
        assert.is_nil(Duo.decode("", 1))
        assert.is_nil(Duo.decode("1234", 1))
        assert.is_nil(Duo.decode("123456", 1))
        assert.is_nil(Duo.decode("12a45", 1))
    end)

    it("draws fresh codes that decode to their variant", function()
        local r = Duo.rng(9)
        for _i = 1, 50 do
            local code, seed = Duo.newCode(3, 4, r:fn())
            local s, v = Duo.decode(code, 4)
            assert.equals(seed, s)
            assert.equals(3, v)
        end
    end)
end)
