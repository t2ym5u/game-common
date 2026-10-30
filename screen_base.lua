local Blitbuffer      = require("ffi/blitbuffer")
local ButtonDialog    = require("ui/widget/buttondialog")
local ButtonTable     = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device          = require("device")
local Font            = require("ui/font")
local Geom            = require("ui/geometry")
local InfoMessage     = require("ui/widget/infomessage")
local InputContainer  = require("ui/widget/container/inputcontainer")
local RenderText      = require("ui/rendertext")
local Size            = require("ui/size")
local TextBoxWidget   = require("ui/widget/textboxwidget")
local TextViewer      = require("ui/widget/textviewer")
local TextWidget      = require("ui/widget/textwidget")
local TitleBar        = require("ui/widget/titlebar")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local Widget          = require("ui/widget/widget")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _               = require("i18n")
local T               = require("ffi/util").template

local DeviceScreen = Device.screen

-- ---------------------------------------------------------------------------
-- ScreenBase — shared full-screen game UI
--
-- Subclasses must implement:
--   :buildLayout()       — build all widgets and assign self.layout
--   :updateStatus([msg]) — refresh the status bar text
--
-- Subclasses receive:
--   self.plugin      — the parent PluginBase instance
--   self.status_text — StatusLine for the status bar (place it in layout)
--   self.dimen       — full-screen Geom
--
-- Subclasses may call:
--   :isLandscape()
--   :showMessage(msg, timeout)
--   :closeScreen()
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- StatusLine — the status bar widget (self.status_text)
--
-- Same calls as the TextWidget it replaces (setText, setMaxWidth, getSize,
-- paintTo), but in landscape it wraps over several lines: the controls there
-- are a narrow side panel with height to spare, and a one-line TextWidget cut
-- every turn-based game's status off with "…". Portrait keeps one line, since
-- the board is sized around a one-line footer.
-- ---------------------------------------------------------------------------

local STATUS_SEP = " · "
local NBSP       = "\u{00A0}"

-- Wrap only between status parts: spaces inside a part ("Black to move")
-- become non-breaking, so a line never ends in the middle of one. A part too
-- long for a line on its own ("Congratulations! Puzzle solved.") keeps its
-- spaces, or the only break left would be mid-word.
local function keepPartsWhole(text, face, max_width)
    local out = {}
    for part in (text .. STATUS_SEP):gmatch("(.-)" .. STATUS_SEP:gsub("%p", "%%%0")) do
        local w = RenderText:sizeUtf8Text(0, DeviceScreen:getWidth(), face, part, true, false).x
        out[#out + 1] = w <= max_width and part:gsub(" ", NBSP) or part
    end
    return table.concat(out, STATUS_SEP)
end

local StatusLine = Widget:extend{
    text      = "",
    face      = nil,
    max_width = nil,
}

function StatusLine:_widget()
    if not self._w then
        local wrap = self.max_width and DeviceScreen:getWidth() > DeviceScreen:getHeight()
        if wrap then
            self._w = TextBoxWidget:new{
                text      = keepPartsWhole(self.text, self.face, self.max_width),
                face      = self.face,
                width     = self.max_width,
                alignment = "center",
            }
        else
            self._w = TextWidget:new{
                text      = self.text,
                face      = self.face,
                max_width = self.max_width,
            }
        end
    end
    return self._w
end

function StatusLine:free()
    if self._w then self._w:free() end
    self._w = nil
end

function StatusLine:setText(text)
    if text == self.text then return end
    self.text = text
    self:free()
end

function StatusLine:setMaxWidth(max_width)
    if max_width == self.max_width then return end
    self.max_width = max_width
    self:free()
end

function StatusLine:getSize()
    return self:_widget():getSize()
end

function StatusLine:paintTo(bb, x, y)
    self:_widget():paintTo(bb, x, y)
end

-- ---------------------------------------------------------------------------
-- ActionBar -- the bottom ButtonTable, swappable in place
--
-- Once a round is over, the game's actions (Check, Hint, Undo...) have nothing
-- left to act on, and starting the next round used to mean opening the title-bar
-- menu. So the bar then shows the round-over buttons instead (one full-width
-- "New game" by default), kept at the bar's height so nothing else moves.
-- getButtonById still reaches the normal buttons while they are hidden.
-- ---------------------------------------------------------------------------

local ActionBar = WidgetContainer:extend{
    width      = nil,
    rows       = nil,
    round_over = false,
}

function ActionBar:init()
    -- A game with no bottom actions (a keyboard game) passes no rows: the bar
    -- is then empty during play and only appears once the round is over.
    if #self.rows == 0 then
        self.normal = Widget:new{ dimen = Geom:new{ w = self.width, h = 0 } }
    else
        self.normal = ButtonTable:new{ width = self.width, buttons = self.rows }
    end
    self.normal_h = self.normal:getSize().h
    self:setRoundOverButtons(self.over_row)
end

-- over_row: one row of ButtonTable button specs, or nil for the normal bar.
function ActionBar:setRoundOverButtons(over_row)
    self.round_over = over_row ~= nil
    if not over_row then
        self[1] = self.normal
        return
    end
    local bt = ButtonTable:new{ width = self.width, buttons = { over_row } }
    self[1] = CenterContainer:new{
        dimen = Geom:new{ w = self.width, h = math.max(self.normal_h, bt:getSize().h) },
        bt,
    }
end

function ActionBar:getButtonById(id)
    return self.normal.getButtonById and self.normal:getButtonById(id)
end

local ScreenBase = InputContainer:extend{
    vertical_align = "center",
}

function ScreenBase:init()
    self.dimen         = Geom:new{ x = 0, y = 0, w = DeviceScreen:getWidth(), h = DeviceScreen:getHeight() }
    self.covers_fullscreen = true

    if Device:hasKeys() then
        self.key_events = { Close = { { Device.input.group.Back } } }
    end

    self.status_text = StatusLine:new{
        text = "",
        face = Font:getFace("smallinfofont"),
    }

    self:buildLayout()

    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
end

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------

function ScreenBase:paintTo(bb, x, y)
    self.dimen.x = x
    self.dimen.y = y
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)

    if not self.layout then return end
    local content_size = self.layout:getSize()
    local offset_x = x + math.floor((self.dimen.w - content_size.w) / 2)
    local offset_y = y
    if self.vertical_align == "center" then
        offset_y = offset_y + math.max(0, math.floor((self.dimen.h - content_size.h) / 2))
    end
    self.layout:paintTo(bb, offset_x, offset_y)
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

function ScreenBase:isLandscape()
    return DeviceScreen:getWidth() > DeviceScreen:getHeight()
end

function ScreenBase:showMessage(msg, timeout)
    UIManager:show(InfoMessage:new{ text = msg, timeout = timeout or 3 })
end

function ScreenBase:closeScreen()
    if self.plugin then
        self.plugin:saveState(self.serializeState and self:serializeState() or nil)
        self.plugin:onScreenClosed()
    end
    UIManager:close(self)
    UIManager:setDirty(nil, "full")
end

-- ---------------------------------------------------------------------------
-- TitleBar helpers
-- ---------------------------------------------------------------------------

-- Build a standard TitleBar with a hamburger menu on the left and close on
-- the right.  options_fn is called each time the menu opens and must return
-- a list of { text, callback } items — texts are therefore always fresh.
function ScreenBase:buildTitleBar(title, options_fn)
    local self_ref = self
    return TitleBar:new{
        width                  = DeviceScreen:getWidth(),
        title                  = title,
        left_icon              = "appbar.menu",
        left_icon_tap_callback = function()
            local dlg
            local buttons = {}
            for _, item in ipairs(options_fn()) do
                local cb = item.callback
                buttons[#buttons + 1] = {{ text = item.text, callback = function()
                    UIManager:close(dlg)
                    cb()
                end }}
            end
            dlg = ButtonDialog:new{ title = title, buttons = buttons }
            UIManager:show(dlg)
        end,
        close_callback = function() self_ref:closeScreen() end,
        with_bottom_line = true,
    }
end

-- Build a full-screen landscape layout with title_bar pinned to top and
-- content centred vertically in the remaining space.
function ScreenBase:buildLandscapeLayout(title_bar, content)
    local sh       = self.dimen.h
    local tb_h     = title_bar:getSize().h
    local avail_h  = sh - tb_h
    local cont_h   = content:getSize().h
    local top_span = math.max(0, math.floor((avail_h - cont_h) / 2))
    local bot_span = math.max(0, avail_h - top_span - cont_h)
    self.layout = VerticalGroup:new{
        title_bar,
        VerticalSpan:new{ width = top_span },
        content,
        VerticalSpan:new{ width = bot_span },
    }
    self[1] = self.layout
end

-- ---------------------------------------------------------------------------
-- Fixed portrait layout helper
-- ---------------------------------------------------------------------------

-- Build a full-screen portrait layout with header pinned to top and footer
-- pinned to bottom. Content is centred in the space between them.
-- Call this from buildLayout() instead of building self.layout manually.
--   header  — top button row widget (required)
--   content — middle game area widget (required)
--   footer  — bottom button/input widget, or nil
function ScreenBase:buildPortraitLayout(header, content, footer)
    local sh       = self.dimen.h
    local header_h = header  and header:getSize().h  or 0
    local content_h= content and content:getSize().h or 0
    local footer_h = footer  and footer:getSize().h  or 0
    local remaining = math.max(0, sh - header_h - content_h - footer_h)
    local top_gap   = math.floor(remaining / 2)
    local bot_gap   = remaining - top_gap
    local items = { align = "center" }
    if header  then items[#items+1] = header  end
    items[#items+1] = VerticalSpan:new{ width = top_gap }
    if content then items[#items+1] = content end
    items[#items+1] = VerticalSpan:new{ width = bot_gap }
    if footer  then items[#items+1] = footer  end
    self.layout = VerticalGroup:new(items)
    self[1] = self.layout
end

-- ---------------------------------------------------------------------------
-- Status bar
-- ---------------------------------------------------------------------------

-- Changing the status text changes its width, and VerticalGroup caches both
-- its own size and each child's offset the first time it is measured. Without
-- invalidating that, a status line longer than the one present when the layout
-- was built keeps the *old* centring and runs off the right edge -- visible on
-- any screen whose status grows during play.
local function resetLayoutTree(widget, depth)
    if type(widget) ~= "table" or (depth or 0) > 6 then return end
    if widget.resetLayout then widget:resetLayout() end
    for i = 1, #widget do resetLayoutTree(widget[i], (depth or 0) + 1) end
end

function ScreenBase:updateStatus(msg)
    if not self.status_text then return end
    self.status_text:setText(msg or "")
    if self.layout then resetLayoutTree(self.layout, 0) end
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

-- ---------------------------------------------------------------------------
-- Shared controls
--
-- Every game builds its bottom controls through these, so the action bar, the
-- number pad and the status line look and size the same across the fleet:
-- full-width rows of equal buttons (no shrink_unneeded_width, which centred a
-- cramped cluster of labels and left each game with a different footprint),
-- and status parts joined with one separator.
-- ---------------------------------------------------------------------------

-- Outer gutter between the screen edge and the board or the controls.
function ScreenBase:getGutter()
    return Size.padding.large
end

-- Width of the controls column: the screen minus its gutters in portrait, a
-- side panel next to the board in landscape.
function ScreenBase:getControlsWidth()
    local sw = self.dimen.w
    if self:isLandscape() then
        return math.floor(sw * 0.36)
    end
    return sw - 2 * self:getGutter()
end

-- rows: either one row ({ btn, btn, ... }) or a list of rows. Each btn is a
-- ButtonTable button spec ({ text, callback, id, enabled, ... }). `{}` builds
-- a bar that stays empty until the round is over.
-- The bar is remembered as self.action_bar (the last one built), which is the
-- one refreshActionBar() swaps when the round ends.
function ScreenBase:buildActionBar(rows, width)
    if rows[1] and rows[1].text then rows = { rows } end
    local bar = ActionBar:new{
        width    = width or self:getControlsWidth(),
        rows     = rows,
        over_row = self:isRoundOver() and self:getRoundOverButtons() or nil,
    }
    self.action_bar = bar
    return bar
end

-- Round-over hooks. A game overrides isRoundOver() (won, lost, solved...) and
-- calls refreshActionBar() after anything that can end or restart a round; the
-- bar then offers the next round in place of the game's actions. A game whose
-- next round isn't onNewGame (a next word, a next level) overrides
-- getRoundOverButtons().
function ScreenBase:isRoundOver()
    return false
end

function ScreenBase:getRoundOverButtons()
    return { { text = _("New game"), callback = function() self:onNewGame() end } }
end

function ScreenBase:refreshActionBar()
    local bar = self.action_bar
    if not bar then return end
    local over = self:isRoundOver() and true or false
    if over == bar.round_over then return end
    local old_h = bar:getSize().h
    bar:setRoundOverButtons(over and self:getRoundOverButtons() or nil)
    -- Only an empty bar changes height; the board then has to be resized.
    if bar:getSize().h ~= old_h then
        self:buildLayout()
    end
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

-- keys: list of ButtonTable button specs, one per value. Up to nine keys fit
-- on one row; more are split over two even rows (0-9 becomes 5 + 5).
function ScreenBase:buildNumberPad(keys, width)
    local per_row = #keys <= 9 and #keys or math.ceil(#keys / 2)
    local rows, row = {}, {}
    for i, key in ipairs(keys) do
        row[#row + 1] = key
        if #row == per_row or i == #keys then
            rows[#rows + 1] = row
            row = {}
        end
    end
    return ButtonTable:new{
        width   = width or self:getControlsWidth(),
        buttons = rows,
    }
end

-- The one status separator. nil and "" parts are dropped, so callers can
-- pass optional parts inline: self:joinStatus(size, diff, extra_or_nil).
ScreenBase.STATUS_SEP = STATUS_SEP

function ScreenBase:joinStatus(...)
    local parts = {}
    for i = 1, select("#", ...) do
        local p = select(i, ...)
        if p ~= nil and p ~= "" then parts[#parts + 1] = tostring(p) end
    end
    return table.concat(parts, ScreenBase.STATUS_SEP)
end

-- Room left for the board (including its frame) once the title bar and the
-- controls are placed. `controls` is the widget that will sit under the board
-- in portrait (status + pads + action bar), or beside it in landscape.
-- Returns w, h.
function ScreenBase:getBoardBudget(title_bar, controls)
    local g  = self:getGutter()
    local sw, sh = self.dimen.w, self.dimen.h
    local avail_h = sh - (title_bar and title_bar:getSize().h or 0)
    if self:isLandscape() then
        return sw - self:getControlsWidth() - 3 * g, avail_h - 2 * g
    end
    return sw - 2 * g, avail_h - (controls and controls:getSize().h or 0) - 3 * g
end

-- ---------------------------------------------------------------------------
-- Key events
-- ---------------------------------------------------------------------------

function ScreenBase:onClose()
    self:closeScreen()
end

-- ---------------------------------------------------------------------------
-- Standard close-button config (for use in ButtonTable rows)
-- ---------------------------------------------------------------------------

function ScreenBase:makeCloseButtonConfig()
    return {
        text     = _("Close"),
        callback = function() self:closeScreen() end,
    }
end

-- ---------------------------------------------------------------------------
-- Hint button
--
-- Two taps, not one: the first says which cell is about to give, the second
-- acts on it. That gap is the whole point -- a player who is told where to
-- look usually finds the rest themselves, and only pays for the full reveal
-- if they want it.
--
-- Works on any board that has been through Hint.install() (see
-- common/hint.lua); screens whose board has not get a plain message instead of
-- a broken button.
-- ---------------------------------------------------------------------------

-- How a hint reads. Level 1 points at what is about to give, level 2 says
-- what was done. Cell puzzles get this default; anything whose unit is not a
-- cell overrides it in its own screen.lua.
function ScreenBase:describeHintStep(step, level)
    if level == 1 then
        return step.kind == "mistake"
            and T(_("R%1C%2 is wrong. Tap Hint again to clear it."), step.r, step.c)
            or  T(_("R%1C%2 can be worked out. Tap Hint again to fill it in."), step.r, step.c)
    end
    return step.kind == "mistake"
        and T(_("Cleared R%1C%2."), step.r, step.c)
        or  T(_("Filled in R%1C%2."), step.r, step.c)
end

function ScreenBase:onHint()
    local board = self.board
    if not board or not board.findHint then
        self:updateStatus(_("Hints are not available here."))
        return
    end
    if board.isShowingSolution and board:isShowingSolution() then
        self:updateStatus(_("Hide the solution to keep playing."))
        return
    end

    local step, reason = board:findHint()
    if not step then
        self.hint_cell = nil
        self:updateStatus(reason == "complete"
            and _("Nothing left to fill in.")
            or  _("No hint is available here."))
        return
    end

    -- The level is derived by comparing the target rather than stored, so it
    -- cannot go stale: solve that cell yourself and the next hint starts over.
    local prev  = self.hint_cell
    -- An edge puzzle can offer two different moves at the same r,c (the
    -- horizontal one and the vertical one), so the optional `tag` separates
    -- them; cell puzzles leave it nil and compare on r,c alone.
    local same  = prev and prev.r == step.r and prev.c == step.c
                  and prev.kind == step.kind and prev.tag == step.tag
    local level = same and (prev.level + 1) or 1
    self.hint_cell = { r = step.r, c = step.c, kind = step.kind, tag = step.tag, level = level }

    if board.setSelection then board:setSelection(step.r, step.c) end

    if level == 1 then
        if self.board_widget then self.board_widget:refresh() end
        -- Puzzles whose unit is not a cell -- an edge, a bridge, a rectangle,
        -- a loop segment -- override describeHintStep, since "R3C4" would say
        -- the wrong thing there. Wording lives in the screen, not the board:
        -- a board that formats UI strings drags KOReader's ffi/util into
        -- every headless unit test that touches it.
        self:updateStatus(self:describeHintStep(step, 1))
        return
    end

    if not board:applyHint(step) then
        self.hint_cell = nil
        self:updateStatus(_("No hint is available here."))
        return
    end
    board:noteHintUsed()
    self.hint_cell = nil
    if self.board_widget then self.board_widget:refresh() end
    -- Pass the game's state like closeScreen does: PluginBase:saveState(nil)
    -- would store nil and wipe the save after every hint.
    if self.plugin and self.plugin.saveState then
        self.plugin:saveState(self.serializeState and self:serializeState() or nil)
    end
    -- The hint may have filled the last cell: then the game's own status
    -- (its congratulations) says more than "Filled in R6C5".
    if self:isRoundOver() then
        self:updateStatus()
    else
        self:updateStatus(T(_("%1 Hints used: %2."),
            self:describeHintStep(step, 2), board:getHintsUsed()))
    end
    self:refreshActionBar()
end

-- ---------------------------------------------------------------------------
-- Rules dialog (for use in ButtonTable rows)
-- ---------------------------------------------------------------------------

function ScreenBase:showRules(text)
    UIManager:show(TextViewer:new{
        title  = _("Rules"),
        text   = text,
        width  = math.floor(DeviceScreen:getWidth() * 0.9),
        height = math.floor(DeviceScreen:getHeight() * 0.9),
    })
end

function ScreenBase:makeRulesButtonConfig(en_text, fr_text)
    return {
        text     = _("Rules"),
        callback = function()
            self:showRules((_.lang() == "fr" and fr_text) or en_text)
        end,
    }
end

return ScreenBase
