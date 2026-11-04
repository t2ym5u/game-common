-- Spec for gen_progress.lua, with KOReader's widgets stubbed.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. package.path

local now_ms, shown = 0, {}
package.preload["ui/time"] = function()
    return { now = function() return now_ms end,
             since = function(t) return now_ms - t end,
             to_ms = function(d) return d end }
end
package.preload["ui/widget/progressbardialog"] = function()
    local D = {}
    D.__index = D
    function D:new(o) o = setmetatable(o, D); o.reported = {}; shown[#shown + 1] = o; return o end
    function D:show() self.visible = true end
    function D:reportProgress(f) self.reported[#self.reported + 1] = f end
    function D:close() self.closed = true end
    return D
end
package.preload["i18n"] = function() return function(s) return s end end

local GenProgress = require("gen_progress")

describe("GenProgress.run", function()
    before_each(function() now_ms, shown = 0, {} end)

    it("shows nothing for quick work and returns its results", function()
        local a, b = GenProgress.run(function(p) p(0.5); return 1, 2 end)
        assert.are.same({ 1, 2 }, { a, b })
        assert.are.equal(0, #shown)
    end)

    it("shows the dialog once the work has run past the delay, then closes it", function()
        GenProgress.run(function(p)
            p(0.1)
            now_ms = 250
            p(0.6); p(2)
        end)
        assert.are.equal(1, #shown)
        assert.are.same({ 0.6, 1 }, shown[1].reported)
        assert.is_true(shown[1].closed)
    end)

    it("closes the dialog and re-raises when the work fails", function()
        assert.has_error(function()
            GenProgress.run(function(p) now_ms = 300; p(0.2); error("boom", 0) end)
        end, "boom")
        assert.is_true(shown[1].closed)
    end)
end)
