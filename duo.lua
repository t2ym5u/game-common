-- duo.lua — games played with two readers that never talk to each other.
--
-- Each player holds a reader. One of them starts a game and reads its code
-- aloud (five digits); the other types it in. Both readers then build the
-- very same game from that code and each shows only its own player's part:
-- the map to the guide and the corridors to the explorer, one grid of the
-- spot-the-differences pair to each player, and so on. The players talk;
-- the readers only check what they are told.
--
-- So the draw must be the same on every reader, whatever KOReader or LuaJIT
-- version it runs: games draw from Duo.rng(), a Park-Miller generator in
-- plain arithmetic, never from math.random. Nor may a generator lean on
-- anything else that can differ between builds: table.sort with ties (it is
-- not stable), pairs() order, or the clock.
--
-- The code: four digits of payload and one check digit. The payload holds
-- the seed and the game's variant (its size or level), so the player who
-- joins does not have to pick the same settings: payload = seed * nvariants
-- + (variant - 1). The check digit catches any single wrong digit, so a typo
-- is refused instead of quietly dealing a different game.
--
-- Pure Lua except Duo.newGameDialog(), which loads KOReader's widgets when it
-- is called.

local Duo = {}

Duo.PAYLOAD = 10000      -- four digits
Duo.CHECK_WEIGHTS = { 1, 3, 7, 9 }

local M = 2147483647     -- 2^31 - 1
local A = 48271

-- ---------------------------------------------------------------------------
-- Random numbers, identical on every reader
-- ---------------------------------------------------------------------------

local Rng = {}
Rng.__index = Rng

-- Next raw value in 1 .. M - 1. A * state stays below 2^47, exact in a
-- double, so no integer extension is needed.
function Rng:next()
    self.state = (A * self.state) % M
    return self.state
end

-- random() -> [0, 1); random(m) -> 1..m; random(m, n) -> m..n, like
-- math.random.
function Rng:random(m, n)
    local x = (self:next() - 1) / (M - 1)
    if not m then return x end
    if not n then m, n = 1, m end
    return m + math.floor(x * (n - m + 1))
end

function Rng:shuffle(t)
    for i = #t, 2, -1 do
        local j = self:random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

function Rng:pick(t)
    return t[self:random(#t)]
end

-- A function(m) -> 1..m, the shape some generators take as `rnd`.
function Rng:fn()
    return function(m, n) return self:random(m, n) end
end

-- Mixes a string into a number below M, so two games (or two parts of one
-- game) built from the same code do not share a sequence.
local function hash(s)
    local h = 7
    for i = 1, #s do h = (h * 131 + s:byte(i)) % M end
    return h
end

-- seed: any integer; salt: optional string (the game's id, a stream name).
function Duo.rng(seed, salt)
    local s = ((seed or 0) * 7919 + hash(salt or "")) % M
    if s == 0 then s = 1 end
    local r = setmetatable({ state = s }, Rng)
    -- The first values of a Park-Miller sequence follow the seed closely.
    for _i = 1, 8 do r:next() end
    return r
end

-- ---------------------------------------------------------------------------
-- Codes
-- ---------------------------------------------------------------------------

local function checkDigit(digits)
    local sum = 0
    for i = 1, 4 do sum = sum + Duo.CHECK_WEIGHTS[i] * digits[i] end
    return sum % 10
end

-- Seeds available for each variant.
function Duo.seedCount(nvariants)
    return math.floor(Duo.PAYLOAD / (nvariants or 1))
end

-- The code for (seed, variant): a five-digit string.
function Duo.encode(seed, variant, nvariants)
    nvariants = nvariants or 1
    variant = variant or 1
    local payload = (seed % Duo.seedCount(nvariants)) * nvariants + (variant - 1)
    local s = string.format("%04d", payload)
    local digits = {}
    for i = 1, 4 do digits[i] = tonumber(s:sub(i, i)) end
    return s .. checkDigit(digits)
end

-- A fresh code. rnd: optional function(m) -> 1..m (default math.random,
-- since the code itself is the one thing that must differ between games).
function Duo.newCode(variant, nvariants, rnd)
    rnd = rnd or math.random
    local seed = rnd(Duo.seedCount(nvariants or 1)) - 1
    return Duo.encode(seed, variant, nvariants), seed
end

-- Reads a typed code: spaces and dashes are ignored. Returns seed, variant
-- or nil when it is not a valid code for this game.
function Duo.decode(text, nvariants)
    nvariants = nvariants or 1
    local s = tostring(text or ""):gsub("[%s%-]", "")
    if not s:match("^%d%d%d%d%d$") then return nil end
    local digits = {}
    for i = 1, 5 do digits[i] = tonumber(s:sub(i, i)) end
    if checkDigit(digits) ~= digits[5] then return nil end
    local payload = tonumber(s:sub(1, 4))
    local variant = payload % nvariants + 1
    local seed = math.floor(payload / nvariants)
    if seed >= Duo.seedCount(nvariants) then return nil end
    return seed, variant
end

-- "48213" -> "482 13", easier to read aloud.
function Duo.format(code)
    code = tostring(code or "")
    if #code ~= 5 then return code end
    return code:sub(1, 3) .. " " .. code:sub(4, 5)
end

-- ---------------------------------------------------------------------------
-- The "New game" dialog
-- ---------------------------------------------------------------------------

-- opts:
--   title      the game's name
--   nvariants  how many variants the code carries (default 1)
--   variant    the variant this reader would start (its current settings)
--   variant_text(variant) -> label shown with the code, optional
--   roles      optional list of { id =, text = }: each player picks one
--              (the two readers must pick different ones)
--   on_start(game) with game = { code, seed, variant, role, created }
function Duo.newGameDialog(opts)
    local ButtonDialog = require("ui/widget/buttondialog")
    local InfoMessage  = require("ui/widget/infomessage")
    local InputDialog  = require("ui/widget/inputdialog")
    local UIManager    = require("ui/uimanager")
    local _            = require("i18n")
    local T            = require("ffi/util").template

    local nvariants = opts.nvariants or 1

    local function start(code, seed, variant, created)
        local game = { code = code, seed = seed, variant = variant, created = created }
        local lead = T(_("Game code: %1"), Duo.format(code))
        if created then
            lead = lead .. "\n" .. _("Read it to the other player, who chooses Join a game.")
        end
        if opts.variant_text then
            lead = lead .. "\n" .. opts.variant_text(variant)
        end
        if not opts.roles then
            local dlg
            dlg = ButtonDialog:new{
                title = lead,
                buttons = { { {
                    text = _("Start playing"),
                    callback = function()
                        UIManager:close(dlg)
                        opts.on_start(game)
                    end,
                } } },
            }
            UIManager:show(dlg)
            return
        end
        local dlg
        local buttons = {}
        for _i, role in ipairs(opts.roles) do
            local id = role.id
            buttons[#buttons + 1] = { {
                text = role.text,
                callback = function()
                    UIManager:close(dlg)
                    game.role = id
                    opts.on_start(game)
                end,
            } }
        end
        dlg = ButtonDialog:new{
            title = lead .. "\n\n" .. _("Choose your role (the other player takes the other one):"),
            buttons = buttons,
        }
        UIManager:show(dlg)
    end

    local function join()
        local input
        input = InputDialog:new{
            title      = _("Join a game"),
            description = _("Type the code shown on the other player's reader."),
            input_type = "number",
            input_hint = "000 00",
            buttons = { {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function() UIManager:close(input) end,
                },
                {
                    text = _("Join"),
                    is_enter_default = true,
                    callback = function()
                        local text = input:getInputText()
                        local seed, variant = Duo.decode(text, nvariants)
                        if not seed then
                            UIManager:show(InfoMessage:new{
                                text = _("This code is not valid. Check it with the other player."),
                                timeout = 3,
                            })
                            return
                        end
                        UIManager:close(input)
                        start(text:gsub("[%s%-]", ""), seed, variant, false)
                    end,
                },
            } },
        }
        UIManager:show(input)
        input:onShowKeyboard()
    end

    local menu
    menu = ButtonDialog:new{
        title = opts.title,
        buttons = {
            { {
                text = _("Start a game (show the code)"),
                callback = function()
                    UIManager:close(menu)
                    local variant = opts.variant or 1
                    local code, seed = Duo.newCode(variant, nvariants)
                    start(code, seed, variant, true)
                end,
            } },
            { {
                text = _("Join a game (type the code)"),
                callback = function()
                    UIManager:close(menu)
                    join()
                end,
            } },
        },
    }
    UIManager:show(menu)
end

return Duo
