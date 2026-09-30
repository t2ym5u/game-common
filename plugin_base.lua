local DataStorage     = require("datastorage")
local LuaSettings     = require("luasettings")
local UIManager       = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _               = require("i18n")
local StatsExporter   = require("stats_exporter")

-- ---------------------------------------------------------------------------
-- PluginBase — shared plugin lifecycle for all game plugins
--
-- Subclasses must set:
--   name        (string)  — unique plugin id, used as settings file name
--   menu_text   (string)  — label shown in KOReader's Tools menu
--   menu_hint   (string)  — sorting_hint for the menu category
--
-- `name` must match the plugin's directory basename: since KOReader 2026.03
-- (PR #15096) PluginLoader overwrites plugin_module.name with the directory
-- name unconditionally, so anything else here is silently discarded.
--
-- Subclasses must implement:
--   :createScreen()       — return a new ScreenBase subclass instance
--
-- Subclasses may override:
--   :addToMainMenu(menu_items)  — for extra menu entries
-- ---------------------------------------------------------------------------

local PluginBase = WidgetContainer:extend{
    name        = "game",
    menu_text   = _("Game"),
    menu_hint   = "tools",
    is_doc_only = false,
}

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

-- Stable plugin id.
--
-- self.name is NOT stable: ReaderUI/FileManager:registerModule() rewrites it
-- to "reader"..name / "filemanager"..name right after the instance is built,
-- so anything reading self.name after :init() sees a different string
-- depending on where the game was launched from. Capture it once, at init
-- time, and key settings and stats on that instead.
function PluginBase:getPluginId()
    if not self.plugin_id then
        self.plugin_id = self.name
    end
    return self.plugin_id
end

function PluginBase:ensureSettings()
    if not self.settings_file then
        self.settings_file = DataStorage:getSettingsDir() .. "/" .. self:getPluginId() .. ".lua"
    end
    if not self.settings then
        self.settings = LuaSettings:open(self.settings_file)
    end
end

function PluginBase:saveState(data, key)
    self:ensureSettings()
    self.settings:saveSetting(key or "state", data)
    self.settings:flush()
end

function PluginBase:loadState(key)
    self:ensureSettings()
    return self.settings:readSetting(key or "state")
end

function PluginBase:saveSetting(key, value)
    self:ensureSettings()
    self.settings:saveSetting(key, value)
    self.settings:flush()
end

function PluginBase:getSetting(key, default)
    self:ensureSettings()
    local v = self.settings:readSetting(key)
    if v == nil then return default end
    return v
end

-- ---------------------------------------------------------------------------
-- Menu registration
-- ---------------------------------------------------------------------------

-- Deliberately no Dispatcher:registerAction() here. Exposing each game as a
-- gesture action would put one entry per installed plugin into KOReader's
-- action picker -- around 60 of them on a full install -- which buries the
-- actions a reader actually reaches for. Games are launched from the Tools
-- menu instead.

function PluginBase:init()
    self:ensureSettings()
    self.ui.menu:registerToMainMenu(self)
end

function PluginBase:addToMainMenu(menu_items)
    menu_items[self:getPluginId()] = {
        text         = self.menu_text,
        sorting_hint = self.menu_hint,
        callback     = function() self:showGame() end,
    }
end

-- ---------------------------------------------------------------------------
-- KOReader >= 2026.07 plugin management (PluginLoader, PR #15240)
--
-- :stopPlugin() is called before the plugin directory is deleted, and
-- :deletePluginSettings() when the user asks for the settings to go too.
-- PluginLoader removes self.settings_file itself, so all that is left here is
-- this plugin's row in the shared game_stats.lua -- otherwise a deleted game
-- keeps showing up in Dashboard's stats forever.
-- ---------------------------------------------------------------------------

function PluginBase:stopPlugin()
    if self.screen then
        UIManager:close(self.screen)
        self.screen = nil
    end
end

function PluginBase:deletePluginSettings()
    StatsExporter:remove(self:getPluginId())
end

-- ---------------------------------------------------------------------------
-- Screen lifecycle
-- ---------------------------------------------------------------------------

function PluginBase:showGame()
    if self.screen then return end
    self._session_start = os.time()
    self.screen = self:createScreen()
    UIManager:show(self.screen)
end

function PluginBase:onScreenClosed()
    local elapsed = self._session_start and (os.time() - self._session_start) or 0
    self._session_start = nil
    local id  = self:getPluginId()
    local cur = StatsExporter:get(id) or {}
    StatsExporter:record(id, {
        sessions    = (cur.sessions or 0) + 1,
        last_played = os.time(),
        time_played = (cur.time_played or 0) + elapsed,
    })
    self.screen = nil
end

-- Stub — subclasses must implement this and return a Screen instance.
function PluginBase:createScreen()
    error(self:getPluginId() .. ": createScreen() not implemented")
end

return PluginBase
