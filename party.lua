-- party.lua — the shared pieces of a game's "· multiplayer" mode: several
-- players around one reader laid on the table (see PluginBase.party_mode).
--
-- Players : names typed once, remembered in the plugin's settings.
-- Scores  : pure data (a plain table, safe to put in serializeState()).
-- UI      : "Who found it?" (one button per player) and a scoreboard.
--
-- The KOReader widgets are required inside the UI functions only, so the
-- players/scores part loads under busted without KOReader.
--
--   local Party = require("party")
--   local names  = Party.loadPlayers(plugin, 3)
--   local scores = Party.newScores(names)
--   Party.askWhoFound(names, { on_pick = function(i)
--       if i then Party.award(scores, i, 1) end
--   end })
--   Party.showScoreboard(scores, { final = true })

local _ = require("i18n")
local T = require("ffi/util").template

local Party = {}

Party.MIN_PLAYERS = 2
Party.MAX_PLAYERS = 8
local MAX_NAME_LEN = 16

-- ---------------------------------------------------------------------------
-- Players (or teams)
--
-- Every function below takes an optional last argument `opts`:
--   opts.teams = true  -- the seats are teams: "Team %1", "Team names", and
--                         their own remembered names/count, apart from the
--                         players'
--   opts.min, opts.max -- seat count bounds for loadCount/pickCount
--                         (default MIN_PLAYERS..MAX_PLAYERS)
-- ---------------------------------------------------------------------------

local function kind(opts)
    if opts and opts.teams then
        return { names_key = "party_teams", count_key = "party_team_count",
                 default = _("Team %1"), rename = _("Name of team %1"),
                 list = _("Team names"), count = _("Number of teams") }
    end
    return { names_key = "party_players", count_key = "party_count",
             default = _("Player %1"), rename = _("Name of player %1"),
             list = _("Player names"), count = _("Number of players") }
end

local function bounds(opts)
    return (opts and opts.min) or Party.MIN_PLAYERS, (opts and opts.max) or Party.MAX_PLAYERS
end

function Party.defaultName(i, opts)
    return T(kind(opts).default, i)
end

-- The first n names: the remembered ones, then "Player k" defaults.
function Party.loadPlayers(plugin, n, opts)
    local saved = plugin:getSetting(kind(opts).names_key, {}) or {}
    local out = {}
    for i = 1, n do
        local s = saved[i]
        out[i] = (type(s) == "string" and s ~= "") and s or Party.defaultName(i, opts)
    end
    return out
end

-- How many seats the last party had (default: the lower bound).
function Party.loadCount(plugin, opts)
    local lo, hi = bounds(opts)
    local n = tonumber(plugin:getSetting(kind(opts).count_key, lo)) or lo
    return math.max(lo, math.min(hi, n))
end

function Party.saveCount(plugin, n, opts)
    plugin:saveSetting(kind(opts).count_key, n)
end

-- Remember names[i] for seat i, keeping the names of seats beyond #names.
function Party.savePlayers(plugin, names, opts)
    local key = kind(opts).names_key
    local saved = plugin:getSetting(key, {}) or {}
    for i, s in ipairs(names) do saved[i] = s end
    plugin:saveSetting(key, saved)
end

-- Trim, drop control characters, cut at MAX_NAME_LEN characters (on a UTF-8
-- character boundary).
function Party.cleanName(s)
    s = (s or ""):gsub("[\r\n\t]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    local count, cut = 0, #s
    for pos in s:gmatch("()[^\128-\191]") do
        count = count + 1
        if count > MAX_NAME_LEN then cut = pos - 1; break end
    end
    return s:sub(1, cut)
end

-- Rename seat i with an InputDialog prefilled with its current name.
-- on_done(changed) runs once the dialog is closed.
function Party.renamePlayer(plugin, names, i, on_done, opts)
    local InputDialog = require("ui/widget/inputdialog")
    local UIManager   = require("ui/uimanager")
    local dialog
    dialog = InputDialog:new{
        title = T(kind(opts).rename, i),
        input = names[i],
        buttons = { {
            { text = _("Cancel"), id = "close", callback = function()
                UIManager:close(dialog)
                if on_done then on_done(false) end
            end },
            { text = _("OK"), is_enter_default = true, callback = function()
                local s = Party.cleanName(dialog:getInputText())
                UIManager:close(dialog)
                if s == "" then s = Party.defaultName(i, opts) end
                names[i] = s
                Party.savePlayers(plugin, names, opts)
                if on_done then on_done(true) end
            end },
        } },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

-- The list of seats; picking one renames it, then the list comes back.
-- `names` is edited in place; on_change() runs after every rename.
function Party.editPlayers(plugin, names, on_change, parent, opts)
    local MenuHelper = require("menu_helper")
    local items = {}
    for i, s in ipairs(names) do items[#items + 1] = { id = i, text = s } end
    MenuHelper.openPickerMenu{
        title     = kind(opts).list,
        items     = items,
        parent    = parent,
        on_select = function(i)
            Party.renamePlayer(plugin, names, i, function(changed)
                if changed and on_change then on_change() end
                Party.editPlayers(plugin, names, on_change, parent, opts)
            end, opts)
        end,
    }
end

-- Picker for the number of seats; on_pick(n) after it was saved.
function Party.pickCount(plugin, on_pick, parent, opts)
    local MenuHelper = require("menu_helper")
    local lo, hi = bounds(opts)
    local items = {}
    for n = lo, hi do
        items[#items + 1] = { id = n, text = tostring(n) }
    end
    MenuHelper.openPickerMenu{
        title      = kind(opts).count,
        items      = items,
        current_id = Party.loadCount(plugin, opts),
        parent     = parent,
        on_select  = function(n)
            Party.saveCount(plugin, n, opts)
            if on_pick then on_pick(n) end
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Scores (pure)
-- ---------------------------------------------------------------------------

-- { names = {...}, points = {0, 0, ...}, round = 0 }
function Party.newScores(names)
    local scores = { names = {}, points = {}, round = 0 }
    for i, s in ipairs(names) do
        scores.names[i] = s
        scores.points[i] = 0
    end
    return scores
end

-- Adds pts (default 1, may be negative) to player i.
function Party.award(scores, i, pts)
    if scores.points[i] then
        scores.points[i] = scores.points[i] + (pts or 1)
    end
end

function Party.nextRound(scores)
    scores.round = (scores.round or 0) + 1
    return scores.round
end

-- Players by points, best first: { { index, name, points, rank }, ... }.
-- Ties share a rank ("1, 1, 3") and keep seat order.
function Party.ranking(scores)
    local list = {}
    for i, s in ipairs(scores.names) do
        list[i] = { index = i, name = s, points = scores.points[i] or 0 }
    end
    table.sort(list, function(a, b)
        if a.points ~= b.points then return a.points > b.points end
        return a.index < b.index
    end)
    for k, e in ipairs(list) do
        if k > 1 and e.points == list[k - 1].points then
            e.rank = list[k - 1].rank
        else
            e.rank = k
        end
    end
    return list
end

-- Indices of the players with the most points (several on a tie).
function Party.leaders(scores)
    local out, best = {}, nil
    for _i, e in ipairs(Party.ranking(scores)) do
        if best == nil then best = e.points end
        if e.points == best then out[#out + 1] = e.index end
    end
    return out
end

-- "Alice 12 · Bob 9 · …", short enough for a status line (seat order).
function Party.statusText(scores)
    local parts = {}
    for i, s in ipairs(scores.names) do
        parts[i] = s .. " " .. (scores.points[i] or 0)
    end
    return table.concat(parts, " · ")
end

-- One line per player, best first: "1. Alice — 12".
function Party.scoreLines(scores)
    local lines = {}
    for k, e in ipairs(Party.ranking(scores)) do
        lines[k] = T(_("%1. %2 — %3"), e.rank, e.name, e.points)
    end
    return lines
end

-- A copy safe from later changes (for serializeState()).
function Party.copyScores(scores)
    local c = Party.newScores(scores.names)
    for i, p in ipairs(scores.points) do c.points[i] = p end
    c.round = scores.round
    return c
end

-- Validates a restored table; returns it, or nil when it is unusable.
function Party.restoreScores(t)
    if type(t) ~= "table" or type(t.names) ~= "table" or type(t.points) ~= "table" then
        return nil
    end
    if #t.names < 1 or #t.names ~= #t.points then return nil end
    for i = 1, #t.names do
        if type(t.names[i]) ~= "string" or type(t.points[i]) ~= "number" then return nil end
    end
    t.round = tonumber(t.round) or 0
    return t
end

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------

-- "Who found it?": one big button per player, two per row, plus "Nobody"
-- unless opts.allow_none == false. opts.on_pick(i), i = nil for nobody.
-- opts.title defaults to "Who found it?".
function Party.askWhoFound(names, opts)
    opts = opts or {}
    local ButtonDialog = require("ui/widget/buttondialog")
    local UIManager    = require("ui/uimanager")
    local dialog
    local function pick(i)
        UIManager:close(dialog)
        if opts.on_pick then opts.on_pick(i) end
    end
    local rows, row = {}, {}
    for i, s in ipairs(names) do
        row[#row + 1] = { text = s, callback = function() pick(i) end }
        if #row == 2 then rows[#rows + 1] = row; row = {} end
    end
    if #row > 0 then rows[#rows + 1] = row end
    if opts.allow_none ~= false then
        rows[#rows + 1] = { { text = _("Nobody"), callback = function() pick(nil) end } }
    end
    dialog = ButtonDialog:new{
        title        = opts.title or _("Who found it?"),
        title_align  = "center",
        buttons      = rows,
        dismissable  = opts.dismissable == true,
    }
    UIManager:show(dialog)
    return dialog
end

-- The scores, best first, in a dialog. opts.final adds the winner line;
-- opts.on_close runs when it is dismissed.
function Party.showScoreboard(scores, opts)
    opts = opts or {}
    local InfoMessage = require("ui/widget/infomessage")
    local UIManager   = require("ui/uimanager")
    local lines = Party.scoreLines(scores)
    local head
    if opts.final then
        local leaders = Party.leaders(scores)
        if #leaders == 1 then
            head = T(_("%1 wins!"), scores.names[leaders[1]])
        else
            head = _("It's a tie!")
        end
    else
        head = opts.title or _("Scores")
    end
    UIManager:show(InfoMessage:new{
        text       = head .. "\n\n" .. table.concat(lines, "\n"),
        show_icon  = false,
        dismiss_callback = opts.on_close,
    })
end

return Party
