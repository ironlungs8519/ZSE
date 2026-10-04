-- They See You counts zombies as sprinters through SMBTheySEEYouCore.isSprinter. We wrap it so a ZSE skin with
-- Screamer on is not counted (it already screams with our own scream). Does nothing if They See You is absent
-- or renames this function.

local WRAPPED = "__ZSExpandedWrapped"

-- outfit name -> sandbox key, e.g. "AAGrey01_Costume" -> "Grey01IsScreamer" (false = not one of ours)
local keyCache = {}
local function screamerKeyFor(outfit)
    local key = keyCache[outfit]
    if key == nil then
        local base = string.match(outfit, "^AA(.+)_Costume$")
        key = base and (base .. "IsScreamer") or false
        keyCache[outfit] = key
    end
    return key
end

-- Read at call time, so changing the setting mid-game takes effect immediately.
local function isZSEScreamer(zombie)
    local vars = SandboxVars and SandboxVars.ZSExpanded
    if not vars or vars.TheySeeYouSkipScreamers == false then return false end
    local outfit = zombie:getOutfitName()
    if not outfit then return false end
    local key = screamerKeyFor(outfit)
    return key ~= false and vars[key] == true
end

local installed = false
local function install()
    local core = SMBTheySEEYouCore
    if type(core) ~= "table" or type(core.isSprinter) ~= "function" then return false end
    if core[WRAPPED] then return true end

    local original = core.isSprinter
    core.isSprinter = function(zombie, ...)
        if zombie then
            local ok, skip = pcall(isZSEScreamer, zombie)
            if ok and skip then return false end
        end
        return original(zombie, ...)
    end
    core[WRAPPED] = true
    return true
end

-- Load order between the mods is not guaranteed: try now, at boot and game start, then once a minute until installed.
local function tryInstall()
    if not installed then installed = install() end
end

tryInstall()
Events.OnGameBoot.Add(tryInstall)
Events.OnGameStart.Add(tryInstall)
Events.EveryOneMinute.Add(tryInstall)
