-- PluginBase:getLang/setLang: a game follows KOReader's language unless the
-- player picked another one in the game while KOReader had its current
-- language. Up to 1.14.0 games read a plain "lang" setting, which some
-- defaulted to "en" and which kept a language tried once for good.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

local function stub(name, value)
    package.preload[name] = function() return value end
end
stub("datastorage", { getSettingsDir = function() return "/tmp" end })
stub("luasettings", { open = function() return {} end })
stub("ui/uimanager", {})
stub("ui/widget/container/widgetcontainer", {
    extend = function(self, o) o = o or {}; o.__index = o; return setmetatable(o, { __index = self }) end,
})
stub("i18n", setmetatable({ lang = function() return "en" end }, { __call = function(_, s) return s end }))
stub("stats_exporter", {})
stub("games_menu", {})
stub("ffi/util", { template = function(s) return s end })

local PluginBase = dofile(DIR .. "plugin_base.lua")

-- A plugin whose settings live in a plain table.
local function newPlugin(settings)
    local store = settings or {}
    local p = setmetatable({}, { __index = PluginBase })
    p.ensureSettings = function() end
    p.settings = {
        readSetting = function(_, k) return store[k] end,
        saveSetting = function(_, k, v) store[k] = v end,
        flush = function() end,
    }
    return p, store
end

local function koreader(lang)
    _G.G_reader_settings = { readSetting = function(_, k) if k == "language" then return lang end end }
end

describe("PluginBase game language", function()
    after_each(function() _G.G_reader_settings = nil end)

    it("follows KOReader's language by default", function()
        koreader("fr")
        assert.are.equal("fr", (newPlugin()):getLang())
        koreader("en_GB")
        assert.are.equal("en", (newPlugin()):getLang())
    end)

    it("keeps a choice made in the game while KOReader's language is the same", function()
        koreader("fr")
        local p = newPlugin()
        p:setLang("en")
        assert.are.equal("en", p:getLang())
    end)

    it("follows KOReader again once its language changes", function()
        koreader("fr")
        local p = newPlugin()
        p:setLang("en")
        koreader("de")
        assert.are.equal("en", p:getLang({ "fr", "en" }))   -- de not offered: English
        koreader("fr")
        assert.are.equal("en", p:getLang())                 -- back to fr: the choice holds again
        koreader("en")
        p:setLang("fr")
        koreader("fr")
        assert.are.equal("fr", p:getLang())
    end)

    it("drops a choice saved before 1.15.0 (no lang_ko)", function()
        koreader("fr")
        local p = newPlugin({ lang = "en" })
        assert.are.equal("fr", p:getLang())
    end)

    it("ignores a saved language the game does not offer", function()
        koreader("fr")
        local p = newPlugin({ lang = "es", lang_ko = "fr" })
        assert.are.equal("fr", p:getLang({ "fr", "en" }))
    end)

    it("uses the fallback, then English, then the first offered language", function()
        koreader("de")
        assert.are.equal("fr", (newPlugin()):getLang({ "fr", "en" }, "fr"))
        assert.are.equal("en", (newPlugin()):getLang({ "fr", "en" }))
        assert.are.equal("fr", (newPlugin()):getLang({ "fr" }))
    end)

    it("keeps a separate choice under another key (a multiplayer mode)", function()
        koreader("fr")
        local p, store = newPlugin()
        p:setLang("en", "party_lang")
        assert.are.equal("en", p:getLang(nil, nil, "party_lang"))
        assert.are.equal("fr", p:getLang())
        assert.are.equal("fr", store.party_lang_ko)
        assert.is_nil(store.lang)
    end)

    it("works without G_reader_settings (English)", function()
        _G.G_reader_settings = nil
        assert.are.equal("en", (newPlugin()):getLang())
    end)
end)
