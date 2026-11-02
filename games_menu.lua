-- games_menu.lua — the single "Games" entry of KOReader's Tools menu.
--
-- With a hundred games each adding its own Tools entry, that menu ran to ten
-- pages. Instead every game hands itself to GamesMenu.add() from its
-- addToMainMenu(): the first one creates `menu_items.games`, the others join
-- its list, and the submenu is built when it is opened — recently played
-- games, then one submenu per category (game_categories.lua).
--
-- The list lives in the menu item, not in this module: menu_items is rebuilt
-- for every FileManager and ReaderUI, each with fresh plugin instances, so a
-- module-level registry would go on launching the instances of a closed UI.
--
-- Whichever plugin's common/ copy wins the shared `require("games_menu")`
-- slot builds the entry for everyone; a game from an older release (no
-- games_menu at all) still adds its own Tools entry beside it.

local Categories = require("game_categories")
local _          = require("i18n")

local GamesMenu = {}

-- Games under "Recently played".
GamesMenu.RECENT = 5

-- Sort key: lower case with the accents of Latin letters dropped, so that
-- "Échecs" sorts among the e's rather than after z.
local FOLD = {}
for plain, accented in pairs({
    a = "àáâãäåÀÁÂÃÄÅ", c = "çÇ", e = "èéêëÈÉÊË", i = "ìíîïÌÍÎÏ", n = "ñÑ",
    o = "òóôõöÒÓÔÕÖ", u = "ùúûüÙÚÛÜ", y = "ýÿÝ",
}) do
    for ch in accented:gmatch("[\xC0-\xDF][\x80-\xBF]") do FOLD[ch] = plain end
end

function GamesMenu.sortKey(label)
    return (label:gsub("[\xC0-\xDF][\x80-\xBF]", FOLD)):lower()
end

local function byLabel(a, b)
    local la, lb = GamesMenu.sortKey(a.label), GamesMenu.sortKey(b.label)
    if la ~= lb then return la < lb end
    return a.id < b.id
end

-- Adds one game to the Games entry of `menu_items`, creating the entry on
-- first use. entry = { id = plugin id, label = menu text, launch = function }.
function GamesMenu.add(menu_items, entry)
    local item = menu_items.games
    if not item then
        local list = {}
        item = {
            text                = _("Games"),
            sorting_hint        = "tools",
            games_list          = list,
            sub_item_table_func = function() return GamesMenu.subItems(list) end,
        }
        menu_items.games = item
    end
    local list = item.games_list
    for i, g in ipairs(list) do
        if g.id == entry.id then
            list[i] = entry
            return
        end
    end
    list[#list + 1] = entry
end

-- The games of `list` by category: { { category =, games = {...} }, ... } in
-- Categories.ORDER, each sorted by label, empty categories left out.
function GamesMenu.sections(list)
    local buckets = {}
    for _i, g in ipairs(list) do
        local cat = Categories.of(g.id)
        buckets[cat] = buckets[cat] or {}
        table.insert(buckets[cat], g)
    end
    local cats = {}
    for cat in pairs(buckets) do cats[#cats + 1] = cat end
    table.sort(cats, function(a, b)
        local ra, rb = Categories.rank(a), Categories.rank(b)
        if ra ~= rb then return ra < rb end
        return a < b
    end)
    local sections = {}
    for _i, cat in ipairs(cats) do
        table.sort(buckets[cat], byLabel)
        sections[#sections + 1] = { category = cat, games = buckets[cat] }
    end
    return sections
end

-- Up to `n` games of `list` that `stats` (StatsExporter:readAll()) has seen
-- played, most recent first.
function GamesMenu.recent(list, stats, n)
    local played = {}
    for _i, g in ipairs(list) do
        local rec = stats and stats[g.id]
        local ts = type(rec) == "table" and tonumber(rec.last_played) or nil
        if ts and ts > 0 then played[#played + 1] = { game = g, ts = ts } end
    end
    table.sort(played, function(a, b)
        if a.ts ~= b.ts then return a.ts > b.ts end
        return byLabel(a.game, b.game)
    end)
    local out = {}
    for i = 1, math.min(n, #played) do out[i] = played[i].game end
    return out
end

local function gameItems(games)
    local items = {}
    for i, g in ipairs(games) do
        items[i] = { text = g.label, callback = g.launch }
    end
    return items
end

local function readStats()
    local ok, StatsExporter = pcall(require, "stats_exporter")
    if not ok or type(StatsExporter) ~= "table" then return {} end
    local ok2, all = pcall(StatsExporter.readAll, StatsExporter)
    return ok2 and type(all) == "table" and all or {}
end

-- The submenu: "Recently played", then a submenu per category — or the games
-- themselves when they all sit in one category.
function GamesMenu.subItems(list, stats)
    local items = {}
    local recent = GamesMenu.recent(list, stats or readStats(), GamesMenu.RECENT)
    if #recent > 0 then
        items[#items + 1] = {
            text           = _("Recently played"),
            sub_item_table = gameItems(recent),
            separator      = true,
        }
    end
    local sections = GamesMenu.sections(list)
    if #sections == 1 then
        for _i, it in ipairs(gameItems(sections[1].games)) do items[#items + 1] = it end
        return items
    end
    for _i, sec in ipairs(sections) do
        local label = Categories.LABELS[sec.category] or Categories.LABELS.other
        items[#items + 1] = {
            text           = _(label) .. " (" .. #sec.games .. ")",
            sub_item_table = gameItems(sec.games),
        }
    end
    return items
end

return GamesMenu
