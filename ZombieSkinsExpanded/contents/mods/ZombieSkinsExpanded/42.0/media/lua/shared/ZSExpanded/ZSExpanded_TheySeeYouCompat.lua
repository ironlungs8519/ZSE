local WRAPPED = "__ZSExpandedWrapped"

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

local function tryInstall()
    if not installed then installed = install() end
end

tryInstall()
Events.OnGameBoot.Add(tryInstall)
Events.OnGameStart.Add(tryInstall)
Events.EveryOneMinute.Add(tryInstall)
