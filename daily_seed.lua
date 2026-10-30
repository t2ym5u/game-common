-- daily_seed.lua — deterministic daily seed for puzzle-of-the-day modes
--
-- Usage:
--   local DailySeed = require("daily_seed")
--   local seed = DailySeed.today()       -- integer, constant within a day
--   local rng  = DailySeed.rng(seed)     -- function() → [0, 1)
--   local n    = math.floor(rng() * 10)  -- random 0–9
--   DailySeed.run("nurikabe", function() board:generate() end)

local DailySeed = {}

-- Returns an integer that is constant within a calendar day (year * 1000 + day_of_year).
function DailySeed.today()
    local d = os.date("*t")
    return d.year * 1000 + d.yday
end

-- Park-Miller LCG seeded with `seed`.  Works in plain Lua 5.1 / LuaJIT.
-- Returns a stateful closure: call it repeatedly for the next value in [0, 1).
function DailySeed.rng(seed)
    local M = 2147483647  -- 2^31 − 1 (Mersenne prime)
    local A = 16807
    local state = seed % M
    if state == 0 then state = 1 end
    return function()
        state = (A * state) % M
        return (state - 1) / (M - 1)
    end
end

-- Run fn() with math.random seeded from today and `key`, so a generator that
-- draws from math.random builds the same puzzle on every device all day long
-- (LuaJIT's PRNG is the same on every platform). `key` keeps two games from
-- sharing a sequence. Some generators reseed from the clock themselves; that
-- would throw the daily seed away, so math.randomseed is a no-op meanwhile.
-- Afterwards the clock seeds math.random again, so the next "New game" is not
-- today's puzzle a second time.
function DailySeed.run(key, fn)
    local h = 0
    for i = 1, #key do
        h = (h * 31 + key:byte(i)) % 1000003
    end
    local randomseed = math.randomseed
    randomseed(DailySeed.today() * 1000003 + h)
    math.randomseed = function() end
    local ok, err = pcall(fn)
    math.randomseed = randomseed
    randomseed(os.time())
    if not ok then error(err, 0) end
end

return DailySeed
