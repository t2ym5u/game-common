local Blitbuffer      = require("ffi/blitbuffer")
local ButtonDialog    = require("ui/widget/buttondialog")
local Device          = require("device")
local Font            = require("ui/font")
local Geom            = require("ui/geometry")
local InfoMessage     = require("ui/widget/infomessage")
local InputContainer  = require("ui/widget/container/inputcontainer")
local TextViewer      = require("ui/widget/textviewer")
local TextWidget      = require("ui/widget/textwidget")
local TitleBar        = require("ui/widget/titlebar")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
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
--   self.status_text — TextWidget for the status bar (place it in layout)
--   self.dimen       — full-screen Geom
--
-- Subclasses may call:
--   :isLandscape()
--   :showMessage(msg, timeout)
--   :closeScreen()
-- ---------------------------------------------------------------------------

local ScreenBase = InputContainer:extend{
    vertical_align = "center",
}

function ScreenBase:init()
    self.dimen         = Geom:new{ x = 0, y = 0, w = DeviceScreen:getWidth(), h = DeviceScreen:getHeight() }
    self.covers_fullscreen = true

    if Device:hasKeys() then
        self.key_events = { Close = { { Device.input.group.Back } } }
    end

    self.status_text = TextWidget:new{
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

function ScreenBase:updateStatus(msg)
    if not self.status_text then return end
    self.status_text:setText(msg or "")
    UIManager:setDirty(self, function() return "ui", self.dimen end)
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
    local same  = prev and prev.r == step.r and prev.c == step.c and prev.kind == step.kind
    local level = same and (prev.level + 1) or 1
    self.hint_cell = { r = step.r, c = step.c, kind = step.kind, level = level }

    if board.setSelection then board:setSelection(step.r, step.c) end

    if level == 1 then
        if self.board_widget then self.board_widget:refresh() end
        self:updateStatus(step.kind == "mistake"
            and T(_("R%1C%2 is wrong. Tap Hint again to clear it."), step.r, step.c)
            or  T(_("R%1C%2 can be worked out. Tap Hint again to fill it in."), step.r, step.c))
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
    if self.plugin and self.plugin.saveState then self.plugin:saveState() end
    self:updateStatus(step.kind == "mistake"
        and T(_("Cleared R%1C%2. Hints used: %3."), step.r, step.c, board:getHintsUsed())
        or  T(_("Filled in R%1C%2. Hints used: %3."), step.r, step.c, board:getHintsUsed()))
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
