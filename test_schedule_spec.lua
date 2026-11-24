-- Spec for ScreenBase:schedule / :cancelScheduled, with KOReader stubbed: a
-- deferred action never runs on a closed screen, nor on a game that "New
-- game" has replaced (Othello's AI once could move twice that way).
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

describe("ScreenBase:schedule", function()
    local saved = {}
    local queue, shown_set

    local function stub()
        return setmetatable({}, {
            __index = function(t, k) local s = stub(); rawset(t, k, s); return s end,
            __call  = function(_, a, b) if b ~= nil then return b end return a end,
        })
    end
    local function stubSearcher(name) return function() return stub() end, name end
    local function class(base)
        base = base or {}
        base.__index = base
        function base:extend(t) t = t or {}; t.__index = t; return setmetatable(t, self) end
        function base:new(o)
            o = setmetatable(o or {}, self)
            if o.init then o:init() end
            return o
        end
        return base
    end

    setup(function()
        saved.path = package.path
        package.path = DIR .. "?.lua;" .. package.path
        saved.loaded = {}
        for k, v in pairs(package.loaded) do saved.loaded[k] = v end
        package.loaded["screen_base"] = nil
        package.loaded["device"] = { screen = {
            getWidth = function() return 758 end, getHeight = function() return 1024 end,
        }, hasKeys = function() return false end }
        package.loaded["ui/widget/container/inputcontainer"] = class()
        package.loaded["ui/widget/widget"] = class()
        package.loaded["ui/geometry"] = class()
        package.loaded["ui/gesturerange"] = class()
        package.loaded["ui/uimanager"] = setmetatable({
            scheduleIn = function(_, _, fn) queue[#queue + 1] = fn end,
            unschedule = function(_, fn)
                for i = #queue, 1, -1 do if queue[i] == fn then table.remove(queue, i) end end
            end,
            isWidgetShown = function(_, w) return shown_set[w] == true end,
            close = function(_, w) shown_set[w] = nil end,
        }, { __index = function() return function() end end })
        local searchers = package.searchers or package.loaders
        searchers[#searchers + 1] = stubSearcher
    end)

    teardown(function()
        local searchers = package.searchers or package.loaders
        for i = #searchers, 1, -1 do
            if searchers[i] == stubSearcher then table.remove(searchers, i) end
        end
        for k in pairs(package.loaded) do
            if saved.loaded[k] == nil then package.loaded[k] = nil end
        end
        for k, v in pairs(saved.loaded) do package.loaded[k] = v end
        package.path = saved.path
    end)

    before_each(function() queue, shown_set = {}, {} end)

    -- Run what is due, as UIManager would (callbacks may schedule more).
    local function runDue()
        local due = queue
        queue = {}
        for _, fn in ipairs(due) do fn() end
    end

    -- A bare screen, shown; no init (no layout to build).
    local function screen()
        local ScreenBase = require("screen_base")
        local s = setmetatable({}, { __index = ScreenBase })
        shown_set[s] = true
        return s
    end

    it("runs the action while the screen is shown", function()
        local s, ran = screen(), 0
        s:schedule(0.1, function() ran = ran + 1 end)
        runDue()
        assert.are.equal(1, ran)
    end)

    it("drops it once the screen is closed", function()
        local s, ran = screen(), 0
        s:schedule(0.5, function() ran = ran + 1 end)
        s:closeScreen()
        assert.are.equal(0, #queue)     -- unscheduled, not just ignored
        runDue()
        assert.are.equal(0, ran)
    end)

    it("drops it when the screen left by another way than closeScreen", function()
        local s, ran = screen(), 0
        s:schedule(0.5, function() ran = ran + 1 end)
        shown_set[s] = nil
        runDue()
        assert.are.equal(0, ran)
    end)

    it("drops what was pending at cancelScheduled, keeps what comes after", function()
        local s, log = screen(), {}
        s:schedule(0.5, function() log[#log + 1] = "old game" end)
        s:cancelScheduled()                 -- New game
        s:schedule(0.1, function() log[#log + 1] = "new game" end)
        runDue()
        assert.are.same({ "new game" }, log)
    end)

    it("lets an action schedule the next one", function()
        local s, ran = screen(), 0
        local function tick()
            ran = ran + 1
            if ran < 3 then s:schedule(1, tick) end
        end
        s:schedule(1, tick)
        runDue(); runDue(); runDue(); runDue()
        assert.are.equal(3, ran)
    end)

    it("returns the scheduled function, which unschedule accepts", function()
        local s, ran = screen(), 0
        local action = s:schedule(1, function() ran = ran + 1 end)
        require("ui/uimanager"):unschedule(action)
        runDue()
        assert.are.equal(0, ran)
    end)
end)
