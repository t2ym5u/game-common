-- GridWidgetBase:refresh(parent): UIManager only repaints top-level widgets,
-- so a board that marks itself dirty refreshes its old pixels. Given the
-- screen, it marks the screen and refreshes the board's rectangle only.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

describe("GridWidgetBase:refresh", function()
    local saved = {}
    local dirty   -- { widget, region } per UIManager:setDirty call

    -- Every other module is a stub: any field is another stub, and calling
    -- one returns its last argument (Geom:new{...} returns its table).
    local function stub()
        return setmetatable({}, {
            __index = function(t, k) local s = stub(); rawset(t, k, s); return s end,
            __call  = function(_, a, b) if b ~= nil then return b end return a end,
        })
    end

    local function stubSearcher(name)
        return function() return stub() end, name
    end

    local GridWidgetBase

    setup(function()
        saved.loaded = {}
        for k, v in pairs(package.loaded) do saved.loaded[k] = v end
        package.loaded["device"] = stub()
        package.loaded["ui/widget/container/inputcontainer"] = {
            extend = function(base, t) return setmetatable(t or {}, { __index = base }) end,
        }
        package.loaded["ui/uimanager"] = {
            setDirty = function(_, w, fn) dirty[#dirty + 1] = { w, select(2, fn()) } end,
        }
        local searchers = package.searchers or package.loaders
        searchers[#searchers + 1] = stubSearcher
        GridWidgetBase = dofile(DIR .. "grid_widget_base.lua").GridWidgetBase
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
    end)

    local function board()
        return setmetatable({ paint_rect = { x = 10, y = 20, w = 300, h = 300 } },
            { __index = GridWidgetBase })
    end

    before_each(function() dirty = {} end)

    it("marks the screen dirty and refreshes the board's rectangle", function()
        local b, screen = board(), {}
        b:refresh(screen)
        assert.are.equal(1, #dirty)
        assert.are.equal(screen, dirty[1][1])
        assert.are.same({ x = 10, y = 20, w = 300, h = 300 }, dirty[1][2])
    end)

    it("still marks the board itself without a screen", function()
        local b = board()
        b:refresh()
        assert.are.equal(b, dirty[1][1])
    end)
end)
