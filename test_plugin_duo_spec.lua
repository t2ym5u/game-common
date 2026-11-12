-- PluginBase.duo_mode: a game with a two-reader mode gets a third Tools ->
-- Games entry under "duo", and that mode is never reopened by a caller that
-- asks for no mode (Dashboard's tiles).
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

local added = {}
local shown = {}
local function stub(name, value)
    package.preload[name] = function() return value end
end
stub("datastorage", { getSettingsDir = function() return "/tmp" end })
stub("luasettings", { open = function() return {} end })
stub("ui/uimanager", { show = function(_, w) shown[#shown + 1] = w end })
stub("ui/widget/container/widgetcontainer", {
    extend = function(self, o) o = o or {}; o.__index = o; return setmetatable(o, { __index = self }) end,
})
stub("i18n", setmetatable({ lang = function() return "en" end }, { __call = function(_, s) return s end }))
stub("stats_exporter", {})
stub("games_menu", { add = function(_, entry) added[#added + 1] = entry end })
stub("ffi/util", { template = function(s, a) return (s:gsub("%%1", a)) end })

package.loaded.plugin_base = nil
local PluginBase = dofile(DIR .. "plugin_base.lua")

local function newPlugin(fields)
    local p = setmetatable(fields or {}, { __index = PluginBase })
    p.name = p.name or "game"
    p.menu_text = p.menu_text or "Game"
    p.createScreen = function(self) return { mode = self.launch_mode } end
    return p
end

describe("PluginBase two-reader mode", function()
    before_each(function()
        for k in pairs(added) do added[k] = nil end
        for k in pairs(shown) do shown[k] = nil end
    end)

    it("adds a duo entry, named after the game unless it has a name of its own", function()
        newPlugin{ duo_mode = true }:addToMainMenu({})
        assert.are.equal(2, #added)
        assert.are.equal("game:duo", added[2].id)
        assert.are.equal("duo", added[2].category)
        assert.are.equal("Game · two readers", added[2].label)
        assert.are.equal("last_duo_played", added[2].stats_field)
        for k in pairs(added) do added[k] = nil end
        newPlugin{ duo_mode = true, duo_menu_text = "Double Agents" }:addToMainMenu({})
        assert.are.equal("Double Agents", added[2].label)
    end)

    it("lists party and duo entries side by side", function()
        newPlugin{ duo_mode = true, party_mode = true }:addToMainMenu({})
        assert.are.equal(3, #added)
        assert.are.equal("game:party", added[2].id)
        assert.are.equal("game:duo", added[3].id)
    end)

    it("opens the game itself when no mode is asked after a duo game", function()
        local p = newPlugin{ duo_mode = true }
        p:showGame("duo")
        assert.are.equal("duo", shown[1].mode)
        p.screen = nil
        p:showGame()
        assert.are.equal("solo", shown[2].mode)
    end)
end)
