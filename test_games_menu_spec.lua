-- Spec for games_menu.lua. Self-contained: only requires files from this
-- directory, with stand-ins for the two KOReader modules i18n.lua and
-- stats_exporter.lua would pull in.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. package.path

package.loaded["gettext"] = function(s) return s end
package.loaded["stats_exporter"] = { readAll = function() return {} end }

local GamesMenu = require("games_menu")

local function game(id, label)
    return { id = id, label = label or id, launch = function() end }
end

local function texts(items)
    local out = {}
    for i, it in ipairs(items) do out[i] = it.text end
    return out
end

describe("GamesMenu.add", function()

    it("creates one Tools entry and lists every game in it", function()
        local menu_items = {}
        GamesMenu.add(menu_items, game("sudoku"))
        GamesMenu.add(menu_items, game("2048"))
        assert.are.equal("tools", menu_items.games.sorting_hint)
        assert.are.equal(2, #menu_items.games.games_list)
        assert.is_nil(menu_items.sudoku)
        assert.is_nil(menu_items["2048"])
    end)

    it("replaces a game added twice instead of listing it twice", function()
        local menu_items = {}
        local first, second = game("hex"), game("hex")
        GamesMenu.add(menu_items, first)
        GamesMenu.add(menu_items, second)
        assert.are.equal(1, #menu_items.games.games_list)
        assert.are.equal(second, menu_items.games.games_list[1])
    end)

    it("keeps each menu_items table's games to itself", function()
        local a, b = {}, {}
        GamesMenu.add(a, game("hex"))
        GamesMenu.add(b, game("go"))
        assert.are.equal("hex", a.games.games_list[1].id)
        assert.are.equal(1, #b.games.games_list)
    end)
end)

describe("GamesMenu.sections", function()

    it("groups by category in display order, alphabetical inside", function()
        local secs = GamesMenu.sections({
            game("wordle", "Wordle"), game("sudoku", "Sudoku"), game("hex", "Hex"),
            game("anagram", "Anagram"), game("not-a-game", "Zzz"), game("go", "Go"),
        })
        local cats = {}
        for i, s in ipairs(secs) do cats[i] = s.category end
        assert.are.same({ "sudoku", "words", "board", "other" }, cats)
        assert.are.same({ "Anagram", "Wordle" }, texts({
            { text = secs[2].games[1].label }, { text = secs[2].games[2].label } }))
        assert.are.same({ "go", "hex" }, { secs[3].games[1].id, secs[3].games[2].id })
    end)

    it("sorts labels without regard to case", function()
        local secs = GamesMenu.sections({ game("hex", "hex"), game("go", "Go") })
        assert.are.equal("go", secs[1].games[1].id)
    end)
end)

describe("GamesMenu.sortKey", function()

    it("sorts accented labels with their plain letter", function()
        local secs = GamesMenu.sections({
            game("chess", "Échecs"), game("go", "Go"), game("hex", "Dames"),
        })
        assert.are.same({ "hex", "chess", "go" },
            { secs[1].games[1].id, secs[1].games[2].id, secs[1].games[3].id })
        assert.are.equal("l'ane rouge", GamesMenu.sortKey("L'Âne rouge"))
    end)
end)

describe("GamesMenu.recent", function()

    it("keeps the n most recently played, newest first", function()
        local list = { game("a"), game("b"), game("c"), game("d") }
        local stats = {
            a = { last_played = 100 }, b = { last_played = 300 },
            c = { last_played = 200 }, d = { sessions = 2 },
        }
        local r = GamesMenu.recent(list, stats, 2)
        assert.are.same({ "b", "c" }, { r[1].id, r[2].id })
    end)

    it("ignores games that are not installed", function()
        local r = GamesMenu.recent({ game("a") }, { zz = { last_played = 999 } }, 5)
        assert.are.equal(0, #r)
    end)
end)

describe("GamesMenu.subItems", function()

    it("lists recent games first, then one submenu per category", function()
        local list = { game("sudoku", "Sudoku"), game("hex", "Hex"), game("go", "Go") }
        local items = GamesMenu.subItems(list, { hex = { last_played = 5 } })
        assert.are.same({ "Recently played", "Sudoku (1)", "Board games (2)" }, texts(items))
        assert.are.same({ "Hex" }, texts(items[1].sub_item_table))
        assert.are.same({ "Go", "Hex" }, texts(items[3].sub_item_table))
    end)

    it("lists the games themselves when they share one category", function()
        local items = GamesMenu.subItems({ game("hex", "Hex"), game("go", "Go") }, {})
        assert.are.same({ "Go", "Hex" }, texts(items))
        assert.is_function(items[1].callback)
    end)
end)

describe("GamesMenu entries of a game with a multiplayer mode", function()

    it("files an entry under its own category when it gives one", function()
        local list = { game("anagram", "Anagram"),
                       { id = "anagram:party", label = "Anagram · multiplayer",
                         category = "party", launch = function() end } }
        local cats = {}
        for _i, sec in ipairs(GamesMenu.sections(list)) do
            cats[sec.category] = sec.games[1].id
        end
        assert.are.equal("anagram:party", cats.party)
        assert.are.equal("anagram", cats.words)
    end)

    it("sorts Recently played by each entry's own stats field", function()
        local solo  = { id = "anagram", label = "Anagram", stats_field = "last_solo_played",
                        launch = function() end }
        local party = { id = "anagram:party", label = "Anagram · multiplayer",
                        stats_id = "anagram", stats_field = "last_party_played",
                        launch = function() end }
        local stats = { anagram = { last_played = 30, last_solo_played = 10, last_party_played = 30 } }
        local recent = GamesMenu.recent({ solo, party }, stats, 5)
        assert.are.equal(party, recent[1])
        assert.are.equal(solo, recent[2])
        -- A row from before the modes existed only has last_played.
        local old = GamesMenu.recent({ solo, party }, { anagram = { last_played = 5 } }, 5)
        assert.are.equal(0, #old)
    end)
end)
