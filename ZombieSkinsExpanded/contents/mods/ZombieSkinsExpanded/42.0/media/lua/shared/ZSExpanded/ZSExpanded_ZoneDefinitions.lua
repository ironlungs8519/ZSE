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

-- Devuelve v si esta definido, o el default. El idiom "v ~= nil and v or default" es
-- INCORRECTO para booleanos: cuando v es false devuelve el default, por lo que el toggle
-- "XEnable = false" del sandbox se ignoraba y el zombie especial spawneaba igual.
local function pick(v, default)
    if v == nil then return default end
    return v
end

-- Singleplayer = ni cliente ni servidor de red.
local function isSingleplayer()
    return not isClient() and not isServer()
end

-- Comprueba si esta lloviendo, nevando, o con niebla ahora mismo. Usado para
-- SandboxVars.ZSExpanded.PrecipitationOnly (MP/dedicado). El equivalente
-- en SP vive en ZSExpanded_Client.lua, junto a la auto-asignacion. La niebla
-- no tiene su propio isFoggy(); tratamos cualquier getFogIntensity() > 0 como
-- niebla, igual que hace el propio juego con isRaining()/isSnowing().
local function isPrecipitating()
    local ok, climate = pcall(getClimateManager)
    if not ok or not climate then return false end
    local rainOk, raining = pcall(function() return climate:isRaining() end)
    local snowOk, snowing = pcall(function() return climate:isSnowing() end)
    local fogOk, fog = pcall(function() return climate:getFogIntensity() end)
    return (rainOk and raining) or (snowOk and snowing) or (fogOk and fog and fog > 0)
end

local function rebuildZoneEntries()
    -- En SINGLEPLAYER no usamos la distribucion vanilla: el sandbox del mundo se aplica
    -- despues del arranque, asi que el juego "fotografia" la distribucion con los defaults
    -- (todo activado) y no respeta la config. En SP las skins se asignan en el cliente
    -- (ZSExpanded_Client.lua) tirando el dado en vivo. Aqui, en SP, dejamos la tabla sin
    -- nuestras skins (y quitamos cualquiera que hubieramos metido).
    local sp = isSingleplayer()

    local vars = SandboxVars and SandboxVars.ZSExpanded

    -- Remove previously inserted entries
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

    local precipitationOnly = vars and vars.PrecipitationOnly or false
    if precipitationOnly and not isPrecipitating() then return end

    -- Night-only: NightOnly = all skins, <Skin>NightOnly = one skin. Independent of PrecipitationOnly.
    -- The window and the per-night spawn multiplier come from ZSExpanded_Night.lua.
    local nightState = ZSExpandedNight.state()
    local night = nightState.night
    if (vars and vars.NightOnly or false) and not night then return end

    -- MP/dedicado: aqui el sandbox esta listo pronto y la distribucion respeta la config.
    for _, def in ipairs(skinDefs) do
        local enabled = pick(vars and vars[def.enable], true)
        local nightKey = (def.enable:gsub("Enable$", "NightOnly"))
        if pick(vars and vars[nightKey], false) and not night then enabled = false end
        if enabled then
            local chance = pick(vars and vars[def.chance], def.default) * nightState.spawnMult
            local entry = { name = def.name, chance = chance }
            table.insert(ZombiesZoneDefinition.Default, entry)
            table.insert(insertedEntries, entry)
        end
    end
end

-- The engine only re-reads ZombiesZoneDefinition after some Lua file has been run, so when the table changes
-- (server only) we re-run an empty file. The first pass at boot needs no reload.
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
