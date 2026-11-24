-- PluginBase writes its settings file a few seconds after a change, once for
-- any number of changes, and at once on FlushSettings (suspend, power-off,
-- closing) and when the game closes or is uninstalled. Up to 1.19.1 every
-- move wrote the whole file with an fsync.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

local queue = {}
local UIManager = {
    scheduleIn = function(_, _, fn) queue[#queue + 1] = fn end,
    unschedule = function(_, fn)
        for i = #queue, 1, -1 do if queue[i] == fn then table.remove(queue, i) end end
    end,
    close = function() end,
}
local function stub(name, value)
    package.preload[name] = function() return value end
end
stub("datastorage", { getSettingsDir = function() return "/tmp" end })
stub("luasettings", { open = function() return {} end })
stub("ui/uimanager", UIManager)
stub("ui/widget/container/widgetcontainer", {
    extend = function(self, o) o = o or {}; o.__index = o; return setmetatable(o, { __index = self }) end,
})
stub("i18n", setmetatable({ lang = function() return "en" end }, { __call = function(_, s) return s end }))
stub("stats_exporter", {})
stub("games_menu", {})
stub("ffi/util", { template = function(s) return s end })

local PluginBase = dofile(DIR .. "plugin_base.lua")

-- A plugin whose settings live in a table, counting file writes.
local function newPlugin()
    local p = setmetatable({}, { __index = PluginBase })
    local store, writes = {}, { n = 0 }
    p.ensureSettings = function() end
    p.settings = {
        readSetting = function(_, k) return store[k] end,
        saveSetting = function(_, k, v) store[k] = v end,
        flush = function() writes.n = writes.n + 1 end,
    }
    return p, store, writes
end

local function runDue()
    local due = queue
    queue = {}
    for _, fn in ipairs(due) do fn() end
end

describe("PluginBase settings writes", function()
    before_each(function() queue = {} end)

    it("keeps changes in memory at once and writes them once, later", function()
        local p, store, writes = newPlugin()
        p:saveState({ move = 1 })
        p:saveState({ move = 2 })
        p:saveSetting("difficulty", "hard")
        assert.are.same({ move = 2 }, store.state)
        assert.are.equal("hard", p:getSetting("difficulty"))
        assert.are.equal(0, writes.n)
        assert.are.equal(1, #queue)          -- one write scheduled, not three
        runDue()
        assert.are.equal(1, writes.n)
    end)

    it("writes at once on FlushSettings, and lets the event go on", function()
        local p, _, writes = newPlugin()
        p:saveState({ move = 1 })
        assert.is_nil(p:onFlushSettings())   -- nil: other modules get it too
        assert.are.equal(1, writes.n)
        assert.are.equal(0, #queue)          -- the delayed write is dropped
        runDue()
        assert.are.equal(1, writes.n)
    end)

    it("writes nothing when nothing changed", function()
        local p, _, writes = newPlugin()
        p:flushSettings()
        p:onFlushSettings()
        assert.are.equal(0, writes.n)
    end)

    it("writes before an uninstall, so nothing recreates the file after", function()
        local p, _, writes = newPlugin()
        p:saveSetting("difficulty", "easy")
        p:stopPlugin()
        assert.are.equal(1, writes.n)
        assert.are.equal(0, #queue)
    end)

    it("schedules a new write for a change made after one", function()
        local p, _, writes = newPlugin()
        p:saveState({ move = 1 })
        runDue()
        p:saveState({ move = 2 })
        assert.are.equal(1, #queue)
        runDue()
        assert.are.equal(2, writes.n)
    end)
end)
