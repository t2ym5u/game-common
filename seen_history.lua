-- seen_history.lua — what the player has already been shown (words, cards,
-- questions, phrases…), remembered in the plugin's settings across sessions,
-- so draws prefer content not seen yet and only repeat once a pool is used
-- up. Replaces the per-plugin "recent" lists of undercover, passeword,
-- threerounds and wordpyramid with one shared implementation.
--
--   local SeenHistory = require("seen_history")
--   local seen = SeenHistory.open(plugin, "words_" .. lang)   -- one key per pool family
--   local word = seen:pick(pool)                -- one item, marked as seen
--   local deck = seen:draw(pool, 30)            -- 30 distinct items, marked
--
-- Items are identified by `id_of(item)`: by default the item itself when it
-- is a string or number, else item.id / item.word / item.text /
-- item.question / item.phrase / item.name. Ids are stored as strings, oldest
-- first, at most `max` of them (default 2000; the oldest are forgotten
-- first), under the setting "seen_<key>".
--
-- When every item of the pool being drawn from has been seen, only THAT
-- pool's ids are forgotten (in the order they were seen) — ids from other
-- pools sharing the key (another category, another difficulty) are kept.
--
-- `plugin` only needs getSetting(key, default) and saveSetting(key, value)
-- (PluginBase has both). Pure Lua otherwise.

local SeenHistory = {}
SeenHistory.__index = SeenHistory

SeenHistory.DEFAULT_MAX = 2000

local function default_id(item)
    local t = type(item)
    if t == "string" or t == "number" then return tostring(item) end
    if t == "table" then
        local v = item.id or item.word or item.text or item.question or item.phrase or item.name
        if v ~= nil then return tostring(v) end
    end
    return nil
end

-- opts.max: ids kept; opts.id_of: function(item) -> id (string or number)
function SeenHistory.open(plugin, key, opts)
    opts = opts or {}
    local self = setmetatable({
        plugin = plugin,
        key    = "seen_" .. key,
        max    = opts.max or SeenHistory.DEFAULT_MAX,
        id_of  = opts.id_of or default_id,
        list   = {},
        set    = {},
    }, SeenHistory)
    local saved = plugin and plugin:getSetting(self.key, nil)
    if type(saved) == "table" then
        for _i, id in ipairs(saved) do
            id = tostring(id)
            if not self.set[id] then
                self.list[#self.list + 1] = id
                self.set[id] = true
            end
        end
    end
    self:_trim()
    return self
end

function SeenHistory:_trim()
    local extra = #self.list - self.max
    if extra <= 0 then return end
    local kept = {}
    for i = extra + 1, #self.list do kept[#kept + 1] = self.list[i] end
    for i = 1, extra do self.set[self.list[i]] = nil end
    self.list = kept
end

function SeenHistory:save()
    if self.plugin then self.plugin:saveSetting(self.key, self.list) end
end

function SeenHistory:count()
    return #self.list
end

function SeenHistory:has(item_or_id)
    local id = type(item_or_id) == "table" and self.id_of(item_or_id) or item_or_id
    return id ~= nil and self.set[tostring(id)] == true
end

-- Marks ids as seen (moved to the most recent end). No save (see mark()).
function SeenHistory:_markIds(ids)
    local fresh, order = {}, {}
    for _i, id in ipairs(ids) do
        if not fresh[id] then
            fresh[id] = true
            order[#order + 1] = id
        end
    end
    local kept = {}
    for _i, id in ipairs(self.list) do
        if not fresh[id] then kept[#kept + 1] = id end
    end
    for _i, id in ipairs(order) do
        kept[#kept + 1] = id
        self.set[id] = true
    end
    self.list = kept
    self:_trim()
end

-- Marks one item (or a list of items) as seen, and saves.
function SeenHistory:mark(items)
    if type(items) ~= "table" or items[1] == nil and self.id_of(items) then items = { items } end
    local ids = {}
    for _i, item in ipairs(items) do
        local id = self.id_of(item)
        if id ~= nil then ids[#ids + 1] = tostring(id) end
    end
    self:_markIds(ids)
    self:save()
end

-- Forgets the ids of `pool` only.
function SeenHistory:forgetPool(pool)
    local drop = {}
    for _i, item in ipairs(pool) do
        local id = self.id_of(item)
        if id ~= nil then drop[tostring(id)] = true end
    end
    local kept = {}
    for _i, id in ipairs(self.list) do
        if drop[id] then self.set[id] = nil else kept[#kept + 1] = id end
    end
    self.list = kept
end

function SeenHistory:reset()
    self.list, self.set = {}, {}
    self:save()
end

-- Position of each id in the history (1 = oldest), for "least recently
-- seen first" ordering.
function SeenHistory:_ages()
    local age = {}
    for i, id in ipairs(self.list) do age[id] = i end
    return age
end

local function shuffle(t, rng)
    for i = #t, 2, -1 do
        local j = rng(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

-- Up to n distinct items of `pool`: unseen ones first (in random order),
-- then — once the unseen ones run out — the least recently seen. All drawn
-- items are marked as seen and the history saved. A pool fully seen before
-- the draw starts over (its ids forgotten), so the next cycle is random again.
function SeenHistory:draw(pool, n, rng)
    rng = rng or math.random
    if #pool == 0 or n <= 0 then return {} end
    local unseen, seen_items = {}, {}
    for i, item in ipairs(pool) do
        local id = self.id_of(item)
        if id ~= nil and self.set[tostring(id)] then
            seen_items[#seen_items + 1] = i
        else
            unseen[#unseen + 1] = i
        end
    end
    if #unseen == 0 then
        self:forgetPool(pool)
        unseen, seen_items = {}, {}
        for i = 1, #pool do unseen[i] = i end
    end
    shuffle(unseen, rng)
    local out, used = {}, {}
    for _i, idx in ipairs(unseen) do
        if #out >= n then break end
        out[#out + 1] = pool[idx]
        used[idx] = true
    end
    if #out < n and #seen_items > 0 then
        local age = self:_ages()
        table.sort(seen_items, function(a, b)
            local ia = age[tostring(self.id_of(pool[a]))] or 0
            local ib = age[tostring(self.id_of(pool[b]))] or 0
            if ia ~= ib then return ia < ib end
            return a < b
        end)
        for _i, idx in ipairs(seen_items) do
            if #out >= n then break end
            if not used[idx] then out[#out + 1] = pool[idx] end
        end
    end
    local ids = {}
    for _i, item in ipairs(out) do
        local id = self.id_of(item)
        if id ~= nil then ids[#ids + 1] = tostring(id) end
    end
    self:_markIds(ids)
    self:save()
    return out
end

-- One item of `pool` (see draw()), and its index in `pool`.
function SeenHistory:pick(pool, rng)
    local item = self:draw(pool, 1, rng)[1]
    if item == nil then return nil end
    for i, v in ipairs(pool) do
        if v == item then return item, i end
    end
    return item
end

return SeenHistory
