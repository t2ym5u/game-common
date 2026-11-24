-- Spec for screen_base.lua's StatusLine, with KOReader's widgets stubbed: in
-- portrait a status cut off with "…" opens in full when tapped.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

describe("StatusLine", function()
    local saved = {}
    local shown        -- widgets passed to UIManager:show
    local landscape

    -- Every other module is a stub: any field is another stub, and calling
    -- one returns its last argument, so Class:extend{} returns its table.
    local function stub()
        return setmetatable({}, {
            __index = function(t, k) local s = stub(); rawset(t, k, s); return s end,
            __call  = function(_, a, b) if b ~= nil then return b end return a end,
        })
    end

    local function stubSearcher(name)
        return function() return stub() end, name
    end

    local function class(base)
        base = base or {}
        base.__index = base
        function base:extend(t) t = t or {}; t.__index = t; return setmetatable(t, self) end
        function base:new(o)
            o = setmetatable(o or {}, self)
            if o._init then o:_init() end
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
            getWidth  = function() return landscape and 1024 or 758 end,
            getHeight = function() return landscape and 758 or 1024 end,
        }, hasKeys = function() return false end }
        package.loaded["ui/widget/container/inputcontainer"] = class()
        package.loaded["ui/widget/widget"] = class()
        package.loaded["ui/geometry"] = class()
        package.loaded["ui/gesturerange"] = class()
        package.loaded["ui/uimanager"] = setmetatable({
            show = function(_, w) shown[#shown + 1] = w end,
        }, { __index = function() return function() end end })
        package.loaded["ui/widget/infomessage"] = class()
        -- One character is 10 px wide; past max_width the text is cut off.
        local TextWidget = class()
        function TextWidget:getSize() return { w = math.min(#self.text * 10, self.max_width or math.huge), h = 46 } end
        function TextWidget:isTruncated() return self.max_width ~= nil and #self.text * 10 > self.max_width end
        function TextWidget:paintTo() end
        function TextWidget:free() end
        package.loaded["ui/widget/textwidget"] = TextWidget
        local TextBoxWidget = class()
        function TextBoxWidget:getSize() return { w = self.width, h = 78 } end
        function TextBoxWidget:paintTo() end
        function TextBoxWidget:free() end
        package.loaded["ui/widget/textboxwidget"] = TextBoxWidget
        package.loaded["ui/rendertext"] = { sizeUtf8Text = function(_, _, _, _, s) return { x = #s * 10 } end }

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

    before_each(function() shown, landscape = {}, false end)

    -- A status line of max_width 300 holding `text`, painted at (20, 900).
    local function line(text)
        local StatusLine = require("screen_base").StatusLine
        local s = StatusLine:new{ text = "", face = {} }
        s:setMaxWidth(300)
        s:setText(text)
        s:paintTo(nil, 20, 900)
        return s
    end

    it("opens a cut-off line in full when tapped", function()
        local text = "The tile at R3C4 is locked the wrong way. Tap Hint again to unlock it."
        local s = line(text)
        assert.is_true(s:isTruncated())
        assert.are.same({ x = 20, y = 900, w = 300, h = 46 },
            { x = s.dimen.x, y = s.dimen.y, w = s.dimen.w, h = s.dimen.h })
        assert.is_true(s:onTap())
        assert.are.equal(1, #shown)
        assert.are.equal(text, shown[1].text)
    end)

    it("lets a tap through when the line is whole", function()
        local s = line("Black to move.")
        assert.is_false(s:isTruncated())
        assert.is_nil(s:onTap())
        assert.are.equal(0, #shown)
    end)

    it("follows the text: a shorter one no longer opens", function()
        local s = line(("x"):rep(40))
        assert.is_true(s:isTruncated())
        s:setText("Solved!")
        assert.is_false(s:isTruncated())
        assert.is_nil(s:onTap())
    end)

    it("does nothing in landscape, where the line wraps", function()
        landscape = true
        local s = line(("word "):rep(30))
        assert.is_false(s:isTruncated())
        assert.is_nil(s:onTap())
    end)

    it("taps only inside the painted line", function()
        local s = line("x")
        local range = s.ges_events.Tap[1].range
        assert.are.equal(s.dimen, range())
    end)
end)
