-- ---------------------------------------------------------------------------
-- keyboard_widget — shared on-screen letter keyboard
--
-- Bordered, evenly spaced keys shaped like a physical keyboard (QWERTY,
-- AZERTY or QWERTZ, following KOReader's language by default), with optional ⌫ (pinned at the end of the top row) and ↵
-- (pinned at the end of the home row, next to L/M) special keys, and
-- optional per-key background coloring (e.g. Wordle's
-- correct/present/absent feedback).
-- ---------------------------------------------------------------------------

local Button          = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local Geom            = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local Size            = require("ui/size")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")

local KeyboardWidget = {}

local ROWS_QWERTY = {
    {"Q","W","E","R","T","Y","U","I","O","P"},
    {"A","S","D","F","G","H","J","K","L"},
    {"Z","X","C","V","B","N","M"},
}
local ROWS_AZERTY = {
    {"A","Z","E","R","T","Y","U","I","O","P"},
    {"Q","S","D","F","G","H","J","K","L","M"},
    {"W","X","C","V","B","N"},
}

local ROWS_QWERTZ = {
    {"Q","W","E","R","T","Z","U","I","O","P"},
    {"A","S","D","F","G","H","J","K","L"},
    {"Y","X","C","V","B","N","M"},
}

KeyboardWidget.ROWS_QWERTY = ROWS_QWERTY
KeyboardWidget.ROWS_AZERTY = ROWS_AZERTY
KeyboardWidget.ROWS_QWERTZ = ROWS_QWERTZ

local ROWS_BY_LAYOUT = {
    qwerty = ROWS_QWERTY,
    azerty = ROWS_AZERTY,
    qwertz = ROWS_QWERTZ,
}

-- The layout follows the language KOReader's own UI is set to, not the
-- language of a game's word list: the player's hands know the keyboard of
-- their device, and someone on a French device playing English words still
-- looks for A at top left.
local LAYOUT_BY_LANGUAGE = {
    fr = "azerty",
    de = "qwertz",
}

function KeyboardWidget.layoutForLanguage(lang)
    if not lang then
        lang = G_reader_settings and G_reader_settings:readSetting("language") or "en"
    end
    return LAYOUT_BY_LANGUAGE[lang:sub(1, 2)] or "qwerty"
end

-- Special keys (⌫/↵) are rendered wider than a letter key.
local SPECIAL_UNITS = 1.4

local function isSpecial(k)
    return k == "⌫" or k == "↵"
end

-- opts:
--   width      (required) total keyboard width in px
--   layout     "qwerty", "azerty" or "qwertz"; default: from KOReader's
--              language (layoutForLanguage)
--   backspace  true to append ⌫ at the end of the top row
--   enter      true to append ↵ at the end of the home row (next to L/M)
--   onKey      function(key_string) -- called on any key tap, incl. ⌫/↵
--   keyColor   optional function(key_string) -> Blitbuffer color or nil;
--              only consulted for plain letter keys (not ⌫/↵)
--   key_height optional key height in px (default: the Button's natural
--              height, ~6 mm -- short of a finger; screens pass
--              Screen:scaleBySize(52), close to KOReader's own keyboard)
function KeyboardWidget.build(opts)
    local width     = opts.width
    local base_rows = ROWS_BY_LAYOUT[opts.layout or KeyboardWidget.layoutForLanguage()]
                      or ROWS_QWERTY
    local onKey     = opts.onKey
    local keyColor  = opts.keyColor

    local rows = {}
    for i, row in ipairs(base_rows) do
        local r = {}
        for _, k in ipairs(row) do r[#r + 1] = k end
        rows[i] = r
    end
    if opts.backspace then table.insert(rows[1], "⌫") end
    if opts.enter     then table.insert(rows[2], "↵") end

    -- Find the key width that lets every row fit within `width`, so all
    -- letter keys stay the same size across rows regardless of how many
    -- keys (and how many wide special keys) a given row has.
    local gap = Size.span.horizontal_small
    local key_w
    for _, row in ipairs(rows) do
        local units = 0
        for _, k in ipairs(row) do
            units = units + (isSpecial(k) and SPECIAL_UNITS or 1)
        end
        local avail = width - gap * (#row - 1)
        local w = math.floor(avail / units)
        if not key_w or w < key_w then key_w = w end
    end
    local special_w = math.floor(key_w * SPECIAL_UNITS)

    local vgroup = VerticalGroup:new{ align = "center" }
    for i, row in ipairs(rows) do
        if i > 1 then
            table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_default })
        end

        local items = {}
        for j, k in ipairs(row) do
            local special = isSpecial(k)
            local bg = (not special and keyColor) and keyColor(k) or nil
            table.insert(items, Button:new{
                text       = k,
                width      = special and special_w or key_w,
                height     = opts.key_height,
                bordersize = Size.border.button,
                radius     = Size.radius.button,
                margin     = 0,
                padding    = Size.padding.button,
                background = bg,
                callback   = function() onKey(k) end,
            })
            if j < #row then
                table.insert(items, HorizontalSpan:new{ width = gap })
            end
        end
        local hgroup = HorizontalGroup:new(items)
        table.insert(vgroup, CenterContainer:new{
            dimen = Geom:new{ w = width, h = hgroup:getSize().h },
            hgroup,
        })
    end
    return vgroup
end

return KeyboardWidget
