-- Spec for module_guard.lua: a plugin never runs on shared modules older than
-- its own. Self-contained: builds a throwaway common/ directory of stand-in
-- modules, and checks the real game_common_version.lua against this directory.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local Guard = dofile(DIR .. "module_guard.lua")

local function write(path, src)
    local f = assert(io.open(path, "w"))
    f:write(src)
    f:close()
end

-- An i18n.lua of the shape every copy has: a local table S, extend() and
-- __call closing over it.
local function i18nSource(base)
    return ([[
local S = %s
local function extend(tbl) for k, v in pairs(tbl) do S[k] = v end end
return setmetatable({ lang = function() return "fr" end, extend = extend }, {
    __call = function(_, s) local e = S[s]; return e and e.fr or s end,
})]]):format(base)
end

local TMP = os.tmpname()
os.remove(TMP)
local COMMON = TMP .. "/common/"
assert(os.execute("mkdir -p '" .. COMMON .. "'"))
write(COMMON .. "game_common_version.lua", [[
return { lib = "game-common", version = "1.14.0",
         modules = { "alpha", "beta", "i18n" }, shared = { beta = true } }]])
write(COMMON .. "alpha.lua", 'return { copy = "own" }')
write(COMMON .. "beta.lua", 'return { copy = "own" }')
write(COMMON .. "i18n.lua", i18nSource('{ ["Games"] = { fr = "Jeux" } }'))

local NAMES = { "alpha", "beta", "i18n", Guard.REGISTRY }
local V = Guard.versionNumber("1.14.0")

describe("module_guard", function()
    local saved_loaded, saved_preload, saved_path

    -- Other specs of a monorepo-wide run may leave stand-ins in package.loaded
    -- or package.preload under these names: start from neither.
    before_each(function()
        saved_loaded, saved_preload = {}, {}
        for _, n in ipairs(NAMES) do
            saved_loaded[n], saved_preload[n] = package.loaded[n], package.preload[n]
            package.loaded[n], package.preload[n] = nil, nil
        end
        saved_path = package.path
        package.path = COMMON .. "?.lua;" .. package.path
    end)

    after_each(function()
        for _, n in ipairs(NAMES) do
            package.loaded[n], package.preload[n] = saved_loaded[n], saved_preload[n]
        end
        package.path = saved_path
    end)

    local function guard() return Guard(COMMON, "game_common_version.lua") end
    local function registry() return package.loaded[Guard.REGISTRY] end

    describe("versionNumber", function()
        it("orders versions numerically, not as strings", function()
            assert.is_true(Guard.versionNumber("1.14.0") > Guard.versionNumber("1.9.9"))
            assert.is_true(Guard.versionNumber("2.0.0") > Guard.versionNumber("1.999.999"))
            assert.are.equal(Guard.versionNumber("1.14"), Guard.versionNumber("1.14.0"))
            assert.are.equal(0, Guard.versionNumber(nil))
            assert.are.equal(0, Guard.versionNumber("junk"))
        end)
    end)

    describe("enter()", function()
        it("drops a module an old plugin loaded, so require loads our own copy", function()
            local stale = { copy = "stale" }
            package.loaded.alpha = stale
            local g = guard()
            g.enter()
            assert.is_nil(package.loaded.alpha)
            assert.are.equal("own", require("alpha").copy)
            g.leave()
            local e = registry().alpha
            assert.are.same({ lib = "game-common", v = V, mod = package.loaded.alpha },
                { lib = e.lib, v = e.v, mod = e.mod })
        end)

        it("keeps a copy registered by a plugin of the same version or newer", function()
            local newer = { copy = "newer" }
            package.loaded.alpha = newer
            package.loaded[Guard.REGISTRY] = { alpha = { lib = "game-common", v = V + 1000, mod = newer } }
            guard().enter()
            assert.are.equal(newer, package.loaded.alpha)

            local same = { copy = "same" }
            package.loaded.alpha = same
            package.loaded[Guard.REGISTRY] = { alpha = { lib = "game-common", v = V, mod = same } }
            guard().enter()
            assert.are.equal(same, package.loaded.alpha)
        end)

        it("drops a copy registered by an older plugin", function()
            local older = { copy = "older" }
            package.loaded.alpha = older
            package.loaded[Guard.REGISTRY] = { alpha = { lib = "game-common", v = V - 1000, mod = older } }
            guard().enter()
            assert.is_nil(package.loaded.alpha)
            assert.is_nil(registry().alpha) -- nothing keeps the old copy alive
        end)

        it("does not trust a registry entry for another table than the one in the slot", function()
            package.loaded.alpha = { copy = "swapped in later" }
            package.loaded[Guard.REGISTRY] = { alpha = { lib = "game-common", v = V + 1000, mod = {} } }
            guard().enter()
            assert.is_nil(package.loaded.alpha)
        end)

        it("accepts the other library's copy only for the modules both ship", function()
            local beta, alpha = { copy = "sudoku" }, { copy = "sudoku" }
            package.loaded.beta, package.loaded.alpha = beta, alpha
            package.loaded[Guard.REGISTRY] = {
                beta  = { lib = "sudoku-common", v = 1, mod = beta },
                alpha = { lib = "sudoku-common", v = 1, mod = alpha },
            }
            guard().enter()
            assert.are.equal(beta, package.loaded.beta)
            assert.is_nil(package.loaded.alpha)
        end)

        it("leaves modules that are not loaded alone", function()
            guard().enter()
            assert.is_nil(package.loaded.alpha)
            assert.is_table(registry())
        end)
    end)

    describe("i18n", function()
        it("replaces an outdated copy and carries every string it held over", function()
            local old = load(i18nSource('{ ["Games"] = { fr = "Jeux (old)" } }'))()
            old.extend({ ["Hangman"] = { fr = "Pendu" } }) -- a plugin loaded earlier
            package.loaded.i18n = old
            local g = guard()
            g.enter()
            local now = package.loaded.i18n
            assert.is_not.equal(old, now)
            assert.are.equal("Pendu", now("Hangman"))
            assert.are.equal("Jeux", now("Games")) -- our own shared strings win
            assert.are.equal(now, registry().i18n.mod)
            g.leave()
            assert.are.equal(now, registry().i18n.mod)
        end)

        it("keeps a copy whose translation table cannot be found", function()
            local odd = setmetatable({ extend = print }, { __call = function(_, s) return s end })
            package.loaded.i18n = odd
            guard().enter()
            assert.are.equal(odd, package.loaded.i18n)
        end)

        it("keeps a registered copy of the same version, strings and all", function()
            local cur = load(i18nSource("{}"))()
            package.loaded.i18n = cur
            package.loaded[Guard.REGISTRY] = { i18n = { lib = "game-common", v = V, mod = cur } }
            guard().enter()
            assert.are.equal(cur, package.loaded.i18n)
        end)
    end)

    describe("leave()", function()
        it("registers only the modules loaded between enter() and leave()", function()
            local g = guard()
            g.enter()
            require("alpha")
            g.leave()
            require("beta") -- outside the bracket
            assert.is_table(registry().alpha)
            assert.is_nil(registry().beta)
        end)

        it("does not register a module kept from before enter()", function()
            local other = { copy = "sudoku" }
            package.loaded.beta = other
            package.loaded[Guard.REGISTRY] = { beta = { lib = "sudoku-common", v = 1, mod = other } }
            local g = guard()
            g.enter()
            g.leave()
            assert.are.equal("sudoku-common", registry().beta.lib)
        end)

        it("treats a nested bracket as part of the outer one", function()
            local g = guard()
            g.enter()
            require("alpha")
            g.enter() -- a lazyrequire() reached from inside another
            assert.is_not_nil(package.loaded.alpha) -- not dropped half-way
            g.leave()
            assert.is_nil(registry().alpha)
            require("beta")
            g.leave()
            assert.is_table(registry().alpha)
            assert.is_table(registry().beta)
        end)
    end)

    it("does nothing when the version file is missing", function()
        local g = Guard(COMMON, "no_such_version.lua")
        package.loaded.alpha = { copy = "stale" }
        g.enter()
        g.leave()
        assert.are.equal("stale", package.loaded.alpha.copy)
        assert.is_nil(registry())
    end)
end)

describe("game_common_version.lua", function()
    local info = dofile(DIR .. "game_common_version.lua")

    it("matches the top entry of CHANGELOG.md", function()
        local f = assert(io.open(DIR .. "CHANGELOG.md"))
        local top = f:read("*a"):match("\n## %[([%d.]+)%]")
        f:close()
        assert.are.equal(top, info.version)
    end)

    it("lists every module of this directory, and nothing else", function()
        local listed, seen = {}, {}
        for _, n in ipairs(info.modules) do listed[n] = true end
        local p = io.popen('ls "' .. DIR .. '"')
        for file in p:lines() do
            local n = file:match("^(.+)%.lua$")
            if n and not n:match("^test_") and n ~= "module_guard" and n ~= "game_common_version" then
                seen[n] = true
                assert.is_true(listed[n] == true, n .. ".lua is missing from game_common_version.lua")
            end
        end
        p:close()
        for n in pairs(listed) do
            assert.is_true(seen[n] == true, n .. " is listed but has no .lua file")
        end
    end)
end)
