-- Spec for timer.lua. Self-contained: only requires files from this directory,
-- so it runs from game-common's own repo and from the monorepo alike.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. package.path

local Timer = require("timer")

describe("Timer", function()

    local real_time = os.time
    local now
    before_each(function()
        now = 1000
        os.time = function() return now end -- luacheck: ignore
    end)
    after_each(function() os.time = real_time end) -- luacheck: ignore

    it("keeps running after serialize()", function()
        local t = Timer:new()
        t:start()
        now = now + 30
        local data = t:serialize()
        assert.are.equal(30, data.elapsed)
        assert.is_true(data.was_running)
        assert.is_true(t:isRunning())
        now = now + 15
        assert.are.equal(45, t:getElapsed())
    end)

    it("resumes from a save", function()
        local t = Timer:new()
        t:start()
        now = now + 20
        local data = t:serialize()
        local u = Timer:new()
        now = now + 500 -- time spent with the game closed does not count
        u:load(data)
        now = now + 5
        assert.are.equal(25, u:getElapsed())
    end)

    it("stays stopped when saved stopped", function()
        local t = Timer:new()
        t:start()
        now = now + 10
        t:stop()
        local u = Timer:new()
        u:load(t:serialize())
        now = now + 10
        assert.is_false(u:isRunning())
        assert.are.equal(10, u:getElapsed())
    end)

end)
