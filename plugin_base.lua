local DataStorage     = require("datastorage")
local LuaSettings     = require("luasettings")
local UIManager       = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _               = require("i18n")
local StatsExporter   = require("stats_exporter")
local GamesMenu       = require("games_menu")
local T               = require("ffi/util").template

-- ---------------------------------------------------------------------------
-- PluginBase — shared plugin lifecycle for all game plugins
--
-- Subclasses must set:
--   name        (string)  — unique plugin id, used as settings file name
--   menu_text   (string)  — label shown in Tools → Games
--   menu_hint   (string)  — unused since 1.9.0 (every game is listed under
--                           Tools → Games, see games_menu.lua); kept so the
--                           subclasses that still set it need no change
--
-- `name` must match the plugin's directory basename: since KOReader 2026.03
-- (PR #15096) PluginLoader overwrites plugin_module.name with the directory
-- name unconditionally, so anything else here is silently discarded.
--
-- Subclasses must implement:
--   :createScreen()       — return a new ScreenBase subclass instance
--
-- Subclasses may set:
--   party_mode  (boolean) — the game also has a mode for several players
--                           around one reader. It is then listed twice under
--                           Tools → Games: as itself in its own category, and
--                           as "<menu_text> · multiplayer" under Party & quiz.
--                           :createScreen() reads self.launch_mode ("solo" or
--                           "party") to know which one was picked; a screen
--                           that lets the player switch mode sets
--                           plugin.launch_mode too, so "Recently played"
--                           follows the mode last played.
--   duo_mode    (boolean) — the game also has a mode for two players with a
--                           reader each (see duo.lua), listed a third time
--                           as "<menu_text> · two readers" under Two
--                           readers; launch_mode is then "duo".
--   duo_menu_text (string) — the label of that entry, when the two-reader
--                           game has a name of its own.
--
-- Subclasses may override:
--   :addToMainMenu(menu_items)  — for extra menu entries
-- ---------------------------------------------------------------------------

local PluginBase = WidgetContainer:extend{
    name        = "game",
    menu_text   = _("Game"),
    menu_hint   = "tools",
    party_mode  = false,
    duo_mode    = false,
    launch_mode = "solo",
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
-- Game language (games with content in several languages)
--
-- By default a game follows KOReader's interface language. A language picked
-- in the game's own menu (setLang) holds as long as KOReader's language stays
-- the one it was picked under ("lang_ko"); once KOReader changes language,
-- the game follows it again. A choice saved before 1.15.0 has no "lang_ko"
-- and is dropped: games either ignored KOReader altogether (seven word games
-- started in English whatever its language) or kept English for good after
-- it was tried once.
--
-- supported: the languages the game has content for (default fr, en); when
-- KOReader's language is not among them, `fallback` if given, else English
-- if supported, else the first one. key: the setting holding the choice
-- (default "lang"; a multiplayer mode with its own language passes its own,
-- e.g. "party_lang"); KOReader's language at that time is kept in key.."_ko".
-- ---------------------------------------------------------------------------

local function koreaderLang()
    return (G_reader_settings and G_reader_settings:readSetting("language") or "en"):sub(1, 2)
end

function PluginBase:getLang(supported, fallback, key)
    key = key or "lang"
    supported = supported or { "fr", "en" }
    local ok = {}
    for _i, l in ipairs(supported) do ok[l] = true end
    local ko = koreaderLang()
    local saved = self:getSetting(key)
    if saved and ok[saved] and self:getSetting(key .. "_ko") == ko then return saved end
    if ok[ko] then return ko end
    if fallback and ok[fallback] then return fallback end
    return ok.en and "en" or supported[1]
end

function PluginBase:setLang(lang, key)
    key = key or "lang"
    self:saveSetting(key, lang)
    self:saveSetting(key .. "_ko", koreaderLang())
end

-- ---------------------------------------------------------------------------
-- Menu registration
-- ---------------------------------------------------------------------------

-- Deliberately no Dispatcher:registerAction() here. Exposing each game as a
-- gesture action would put one entry per installed plugin into KOReader's
-- action picker -- around 60 of them on a full install -- which buries the
-- actions a reader actually reaches for. Games are launched from the Tools
-- menu instead — all of them from its one "Games" entry (games_menu.lua),
-- grouped by category, rather than one Tools entry each.

function PluginBase:init()
    self:ensureSettings()
    self.ui.menu:registerToMainMenu(self)
end

-- Timestamp field of the game_stats.lua row that each mode's menu entry
-- sorts "Recently played" by (last_played is kept for Dashboard).
local MODE_FIELD = { solo = "last_solo_played", party = "last_party_played", duo = "last_duo_played" }

function PluginBase:addToMainMenu(menu_items)
    local id = self:getPluginId()
    if not self.party_mode and not self.duo_mode then
        GamesMenu.add(menu_items, {
            id     = id,
            label  = self.menu_text,
            launch = function() self:showGame() end,
        })
        return
    end
    GamesMenu.add(menu_items, {
        id          = id,
        label       = self.menu_text,
        stats_field = MODE_FIELD.solo,
        launch      = function() self:showGame("solo") end,
    })
    if self.party_mode then
        GamesMenu.add(menu_items, {
            id          = id .. ":party",
            label       = T(_("%1 · multiplayer"), self.menu_text),
            category    = "party",
            stats_id    = id,
            stats_field = MODE_FIELD.party,
            launch      = function() self:showGame("party") end,
        })
    end
    if self.duo_mode then
        GamesMenu.add(menu_items, {
            id          = id .. ":duo",
            label       = self.duo_menu_text or T(_("%1 · two readers"), self.menu_text),
            category    = "duo",
            stats_id    = id,
            stats_field = MODE_FIELD.duo,
            launch      = function() self:showGame("duo") end,
        })
    end
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

-- mode: "solo" or "party", only meaningful when self.party_mode is set.
function PluginBase:showGame(mode)
    if self.screen then return end
    if mode then
        self.launch_mode = mode
    elseif self.launch_mode == "duo" then
        -- Callers that pass no mode (Dashboard's tiles) mean the game
        -- itself: the two-reader mode is only ever opened by its own entry.
        self.launch_mode = "solo"
    end
    self._session_start = os.time()
    self.screen = self:createScreen()
    UIManager:show(self.screen)
end

function PluginBase:onScreenClosed()
    local elapsed = self._session_start and (os.time() - self._session_start) or 0
    self._session_start = nil
    local id  = self:getPluginId()
    local cur = StatsExporter:get(id) or {}
    local rec = {
        sessions    = (cur.sessions or 0) + 1,
        last_played = os.time(),
        time_played = (cur.time_played or 0) + elapsed,
    }
    if self.party_mode or self.duo_mode then
        rec[MODE_FIELD[self.launch_mode] or MODE_FIELD.solo] = rec.last_played
    end
    StatsExporter:record(id, rec)
    self.screen = nil
end

-- Stub — subclasses must implement this and return a Screen instance.
function PluginBase:createScreen()
    error(self:getPluginId() .. ": createScreen() not implemented")
end

return PluginBase
