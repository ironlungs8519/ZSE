require 'NPCs/ZombiesZoneDefinition'
require 'ZSExpanded/ZSExpanded_Night'

ZombiesZoneDefinition.Default = ZombiesZoneDefinition.Default or {}

local skinDefs = {
    { enable = "VolatileEnable",     chance = "VolatileSpawnChance",     name = "AAVolatile_Costume",     default = 1 },
    { enable = "RadiationZedEnable", chance = "RadiationZedSpawnChance", name = "AARadiationZed_Costume", default = 1 },
    { enable = "RunnerZedEnable",    chance = "RunnerZedSpawnChance",    name = "AARunnerZed_Costume",    default = 1 },
    { enable = "TankyZedEnable",     chance = "TankyZedSpawnChance",     name = "AATankyZed_Costume",     default = 1 },
    { enable = "WoodZedEnable",      chance = "WoodZedSpawnChance",      name = "AAWoodZed_Costume",      default = 1 },
    { enable = "Demolisher01Enable", chance = "Demolisher01SpawnChance", name = "AADemolisher01_Costume", default = 1 },
    { enable = "Revenant01Enable",   chance = "Revenant01SpawnChance",   name = "AARevenant01_Costume",   default = 1 },
    { enable = "Goon01Enable",       chance = "Goon01SpawnChance",       name = "AAGoon01_Costume",       default = 1 },
    { enable = "Boomer01Enable",     chance = "Boomer01SpawnChance",     name = "AABoomer01_Costume",     default = 1 },
    { enable = "Charge01Enable",     chance = "Charge01SpawnChance",     name = "AACharge01_Costume",     default = 1 },
    { enable = "Ogre01Enable",       chance = "Ogre01SpawnChance",       name = "AAOgre01_Costume",       default = 1 },
    { enable = "Summoner01Enable",   chance = "Summoner01SpawnChance",   name = "AASummoner01_Costume",   default = 1 },
    { enable = "Toad01Enable",       chance = "Toad01SpawnChance",       name = "AAToad01_Costume",       default = 1 },
    { enable = "Cloaker01Enable",    chance = "Cloaker01SpawnChance",    name = "AACloaker01_Costume",    default = 1 },
    { enable = "Experiment1Enable",  chance = "Experiment1SpawnChance",  name = "AAExperiment1_Costume",  default = 1 },
    { enable = "Experiment2Enable",  chance = "Experiment2SpawnChance",  name = "AAExperiment2_Costume",  default = 1 },
    { enable = "Experiment3Enable",  chance = "Experiment3SpawnChance",  name = "AAExperiment3_Costume",  default = 1 },
    { enable = "Experiment4Enable",  chance = "Experiment4SpawnChance",  name = "AAExperiment4_Costume",  default = 1 },
    { enable = "Experiment5Enable",  chance = "Experiment5SpawnChance",  name = "AAExperiment5_Costume",  default = 1 },
    { enable = "Experiment6Enable",  chance = "Experiment6SpawnChance",  name = "AAExperiment6_Costume",  default = 1 },
    { enable = "Experiment7Enable",  chance = "Experiment7SpawnChance",  name = "AAExperiment7_Costume",  default = 1 },
    { enable = "Grey01Enable", chance = "Grey01SpawnChance", name = "AAGrey01_Costume", default = 0.02 },
    { enable = "SkinnyBob01Enable", chance = "SkinnyBob01SpawnChance", name = "AASkinnyBob01_Costume", default = 0.02 },
}

local insertedEntries = {}

local function pick(v, default)
    if v == nil then return default end
    return v
end

local function isSingleplayer()
    return not isClient() and not isServer()
end

local function isPrecipitating()
    local ok, climate = pcall(getClimateManager)
    if not ok or not climate then return false end
    local rainOk, raining = pcall(function() return climate:isRaining() end)
    local snowOk, snowing = pcall(function() return climate:isSnowing() end)
    local fogOk, fog = pcall(function() return climate:getFogIntensity() end)
    return (rainOk and raining) or (snowOk and snowing) or (fogOk and fog and fog > 0)
end

function ZSExpandedEligibleSkins()
    local vars = SandboxVars and SandboxVars.ZSExpanded
    local list = {}

    if (vars and vars.PrecipitationOnly or false) and not isPrecipitating() then return list end

    local night = ZSExpandedNight.isNight()
    if ZSExpandedNight.nightOnly() and not night then return list end

    for _, def in ipairs(skinDefs) do
        local enabled = pick(vars and vars[def.enable], true)
        local nightKey = (def.enable:gsub("Enable$", "NightOnly"))
        if pick(vars and vars[nightKey], false) and not night then enabled = false end
        if enabled then
            list[#list + 1] = { name = def.name, chance = pick(vars and vars[def.chance], def.default) }
        end
    end
    return list
end

local function rebuildZoneEntries()

    local sp = isSingleplayer()

    for _, entry in ipairs(insertedEntries) do
        for i = #ZombiesZoneDefinition.Default, 1, -1 do
            if ZombiesZoneDefinition.Default[i] == entry then
                table.remove(ZombiesZoneDefinition.Default, i)
                break
            end
        end
    end
    insertedEntries = {}

    if sp then return end

    local nightState = ZSExpandedNight.state()

    for _, skin in ipairs(ZSExpandedEligibleSkins()) do
        local entry = { name = skin.name, chance = skin.chance * nightState.spawnMult }
        table.insert(ZombiesZoneDefinition.Default, entry)
        table.insert(insertedEntries, entry)
    end
end

local REFRESH_FILE = "media/lua/shared/ZSExpanded/ZSExpanded_noop.lua"
local applied = nil

local function signatureOf(entries)
    local parts = {}
    for _, e in ipairs(entries) do
        parts[#parts + 1] = tostring(e.name) .. "=" .. tostring(e.chance)
    end
    return table.concat(parts, ",")
end

local function updateZoneDefinitions()
    rebuildZoneEntries()

    local sig = signatureOf(insertedEntries)
    if sig == applied then return end
    local firstPass = (applied == nil)
    applied = sig

    if not firstPass and isServer() then
        pcall(function() reloadLuaFile(REFRESH_FILE) end)
    end
end

Events.OnGameBoot.Add(updateZoneDefinitions)
Events.EveryOneMinute.Add(updateZoneDefinitions)
