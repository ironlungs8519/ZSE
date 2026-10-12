require 'ZSExpanded/ZSExpanded_Night'

local skinData = {}

local naturalSpawn = {}
local updateInterval = 200
local toxicRadius, toxicDamage, toxicCooldown = 5, 0.5, 120
local screamerRadius, screamerCooldown = 100, 300
local screamerVolume = 50
local exploderRadius, exploderDamagePlayers, exploderDamageZombies = 5, 3, 0.2
local exploderEmitFire, exploderFireEnergy, exploderFireDuration = false, 5.0, 300

local precipitationOnly = false

local nightOnly = false

local alienVoices = true

local function isSingleplayer()
    return not isClient() and not isServer()
end

local function pick(v, default)
    if v == nil then return default end
    return v
end

local isNight = ZSExpandedNight.isNight

local nightState = { night = false, quiet = false, intensity = 0, spawnMult = 1 }
local lastNightLogged = nil
local nightDebug = false

local function isPrecipitating()
    local ok, climate = pcall(getClimateManager)
    if not ok or not climate then return false end
    local rainOk, raining = pcall(function() return climate:isRaining() end)
    local snowOk, snowing = pcall(function() return climate:isSnowing() end)
    local fogOk, fog = pcall(function() return climate:getFogIntensity() end)
    return (rainOk and raining) or (snowOk and snowing) or (fogOk and fog and fog > 0)
end

local phunSprintersActive = nil
local function isPhunSprinters2Active()
    if phunSprintersActive == nil then
        local ok, mods = pcall(getActivatedMods)
        phunSprintersActive = ok and mods ~= nil and mods:contains("\\phunsprinters2") or false
    end
    return phunSprintersActive
end

local function markSprinterForPhunSprinters(zombie, md)
    if not isPhunSprinters2Active() then return end
    if md.brain then return end
    md.brain = "ZSExpanded"
end

local function isALifeActor(zombie, md)
    if ProjectALife == nil then return false end
    if md and (md.ProjectALifeOwned == true or md.ProjectALifeActor == true) then return true end
    local ok, flagged = pcall(function()
        return zombie:getVariableBoolean("ALife") or zombie:getVariableBoolean("ALifeActor")
    end)
    return ok and flagged == true
end

local function isMarkedSpecialZed(zombie, md)
    local ok, isBandit = pcall(function() return zombie:getVariableBoolean("Bandit") end)
    if ok and isBandit then return true end
    if isALifeActor(zombie, md) then return true end

    if md.brain ~= nil and md.brain ~= "ZSExpanded" then return true end
    if PZTheMutants
        and PZTheMutants.API
        and PZTheMutants.API.isMutant(zombie) then
        return true
    end
    return false
end

local function buildSkinData()
    local vars = SandboxVars.ZSExpanded
    if not vars then return end

    toxicRadius      = pick(vars.ToxicRadius, 5)
    toxicDamage      = pick(vars.ToxicDamage, 0.5)
    toxicCooldown    = pick(vars.ToxicCooldown, 120)
    screamerRadius   = pick(vars.ScreamerRadius, 100)
    screamerVolume   = pick(vars.ScreamerVolume, 50)
    screamerCooldown = pick(vars.ScreamerCooldown, 300)
    exploderRadius        = pick(vars.ExploderRadius, 5)
    exploderDamagePlayers = pick(vars.ExploderDamagePlayers, 3)
    exploderDamageZombies = pick(vars.ExploderDamageZombies, 0.2)
    exploderEmitFire      = pick(vars.ExploderEmitFire, false)
    exploderFireEnergy    = pick(vars.ExploderFireEnergy, 5.0)
    exploderFireDuration  = pick(vars.ExploderFireDuration, 300)
    precipitationOnly       = pick(vars.PrecipitationOnly, false)
    nightOnly               = ZSExpandedNight.nightOnly()
    alienVoices             = pick(vars.AlienVoices, true)
    nightDebug              = pick(vars.NightDebug, false)

    nightState = ZSExpandedNight.state()
    if nightDebug and nightState.night then
        local idx = ZSExpandedNight.nightIndex()
        if idx ~= lastNightLogged then
            lastNightLogged = idx
            print(string.format("[ZSExpanded] night %d: quiet=%s intensity=%.2f spawnMult=%.2f",
                idx, tostring(nightState.quiet), nightState.intensity, nightState.spawnMult))
            print("[ZSExpanded] moon phase: " .. tostring(ZSExpandedNight.moonPhase()) .. " (4 = full)")
        end
    end

    local function d(healthKey, runnerKey, climberKey, wallBreakerKey, toxicKey, screamerKey, exploderKey, defaultHealth, defaultWallBreaker, defaultToxic, defaultScreamer, defaultExploder, noKnockdownKey, defaultNoKnockdown)
        return {
            health        = pick(vars[healthKey], defaultHealth),
            isRunner      = pick(vars[runnerKey], false),
            isClimber     = pick(vars[climberKey], false),
            isWallBreaker = pick(vars[wallBreakerKey], defaultWallBreaker or false),
            isToxic       = pick(vars[toxicKey], defaultToxic or false),
            isScreamer    = pick(vars[screamerKey], defaultScreamer or false),
            isExploder    = pick(vars[exploderKey], defaultExploder or false),

            noKnockdown   = pick(vars[noKnockdownKey], defaultNoKnockdown or false),
        }
    end

    skinData = {
        ["AAVolatile_Costume"]     = d("VolatileHealth", "VolatileIsRunner", "VolatileIsClimber", "VolatileIsWallBreaker", "VolatileIsToxic", "VolatileIsScreamer", "VolatileIsExploder", 5, false, false, true, false, "VolatileNoKnockdown", true),
        ["AARadiationZed_Costume"] = d("RadiationZedHealth", "RadiationZedIsRunner", "RadiationZedIsClimber", "RadiationZedIsWallBreaker", "RadiationZedIsToxic", "RadiationZedIsScreamer", "RadiationZedIsExploder", 5, false, true, false, false, "RadiationZedNoKnockdown", true),
        ["AARunnerZed_Costume"]    = d("RunnerZedHealth", "RunnerZedIsRunner", "RunnerZedIsClimber", "RunnerZedIsWallBreaker", "RunnerZedIsToxic", "RunnerZedIsScreamer", "RunnerZedIsExploder", 5, false, false, false, false, "RunnerZedNoKnockdown", true),
        ["AATankyZed_Costume"]     = d("TankyZedHealth", "TankyZedIsRunner", "TankyZedIsClimber", "TankyZedIsWallBreaker", "TankyZedIsToxic", "TankyZedIsScreamer", "TankyZedIsExploder", 15, false, false, false, false, "TankyZedNoKnockdown", true),
        ["AAWoodZed_Costume"]      = d("WoodZedHealth", "WoodZedIsRunner", "WoodZedIsClimber", "WoodZedIsWallBreaker", "WoodZedIsToxic", "WoodZedIsScreamer", "WoodZedIsExploder", 5, false, false, false, false, "WoodZedNoKnockdown", true),
        ["AADemolisher01_Costume"] = d("Demolisher01Health", "Demolisher01IsRunner", "Demolisher01IsClimber", "Demolisher01IsWallBreaker", "Demolisher01IsToxic", "Demolisher01IsScreamer", "Demolisher01IsExploder", 30, true, false, false, false, "Demolisher01NoKnockdown", true),
        ["AARevenant01_Costume"]   = d("Revenant01Health", "Revenant01IsRunner", "Revenant01IsClimber", "Revenant01IsWallBreaker", "Revenant01IsToxic", "Revenant01IsScreamer", "Revenant01IsExploder", 5, false, false, false, false, "Revenant01NoKnockdown", true),
        ["AAGoon01_Costume"]       = d("Goon01Health", "Goon01IsRunner", "Goon01IsClimber", "Goon01IsWallBreaker", "Goon01IsToxic", "Goon01IsScreamer", "Goon01IsExploder", 15, true, false, false, false, "Goon01NoKnockdown", true),
        ["AABoomer01_Costume"]     = d("Boomer01Health", "Boomer01IsRunner", "Boomer01IsClimber", "Boomer01IsWallBreaker", "Boomer01IsToxic", "Boomer01IsScreamer", "Boomer01IsExploder", 15, false, false, false, true, "Boomer01NoKnockdown", true),
        ["AACharge01_Costume"]     = d("Charge01Health", "Charge01IsRunner", "Charge01IsClimber", "Charge01IsWallBreaker", "Charge01IsToxic", "Charge01IsScreamer", "Charge01IsExploder", 15, false, false, false, false, "Charge01NoKnockdown", true),
        ["AAOgre01_Costume"]       = d("Ogre01Health", "Ogre01IsRunner", "Ogre01IsClimber", "Ogre01IsWallBreaker", "Ogre01IsToxic", "Ogre01IsScreamer", "Ogre01IsExploder", 5, false, false, false, true, "Ogre01NoKnockdown", true),
        ["AASummoner01_Costume"]   = d("Summoner01Health", "Summoner01IsRunner", "Summoner01IsClimber", "Summoner01IsWallBreaker", "Summoner01IsToxic", "Summoner01IsScreamer", "Summoner01IsExploder", 5, false, false, false, false, "Summoner01NoKnockdown", true),
        ["AAToad01_Costume"]       = d("Toad01Health", "Toad01IsRunner", "Toad01IsClimber", "Toad01IsWallBreaker", "Toad01IsToxic", "Toad01IsScreamer", "Toad01IsExploder", 5, false, true, false, false, "Toad01NoKnockdown", true),
        ["AACloaker01_Costume"]    = d("Cloaker01Health", "Cloaker01IsRunner", "Cloaker01IsClimber", "Cloaker01IsWallBreaker", "Cloaker01IsToxic", "Cloaker01IsScreamer", "Cloaker01IsExploder", 5, false, false, true, false, "Cloaker01NoKnockdown", true),
        ["AAExperiment1_Costume"]  = d("Experiment1Health", "Experiment1IsRunner", "Experiment1IsClimber", "Experiment1IsWallBreaker", "Experiment1IsToxic", "Experiment1IsScreamer", "Experiment1IsExploder", 5, false, false, false, false, "Experiment1NoKnockdown", true),
        ["AAExperiment2_Costume"]  = d("Experiment2Health", "Experiment2IsRunner", "Experiment2IsClimber", "Experiment2IsWallBreaker", "Experiment2IsToxic", "Experiment2IsScreamer", "Experiment2IsExploder", 5, false, false, false, false, "Experiment2NoKnockdown", true),
        ["AAExperiment3_Costume"]  = d("Experiment3Health", "Experiment3IsRunner", "Experiment3IsClimber", "Experiment3IsWallBreaker", "Experiment3IsToxic", "Experiment3IsScreamer", "Experiment3IsExploder", 5, false, false, false, false, "Experiment3NoKnockdown", true),
        ["AAExperiment4_Costume"]  = d("Experiment4Health", "Experiment4IsRunner", "Experiment4IsClimber", "Experiment4IsWallBreaker", "Experiment4IsToxic", "Experiment4IsScreamer", "Experiment4IsExploder", 5, false, false, false, false, "Experiment4NoKnockdown", true),
        ["AAExperiment5_Costume"]  = d("Experiment5Health", "Experiment5IsRunner", "Experiment5IsClimber", "Experiment5IsWallBreaker", "Experiment5IsToxic", "Experiment5IsScreamer", "Experiment5IsExploder", 5, false, false, false, false, "Experiment5NoKnockdown", true),
        ["AAExperiment6_Costume"]  = d("Experiment6Health", "Experiment6IsRunner", "Experiment6IsClimber", "Experiment6IsWallBreaker", "Experiment6IsToxic", "Experiment6IsScreamer", "Experiment6IsExploder", 5, false, false, false, false, "Experiment6NoKnockdown", true),
        ["AAExperiment7_Costume"]  = d("Experiment7Health", "Experiment7IsRunner", "Experiment7IsClimber", "Experiment7IsWallBreaker", "Experiment7IsToxic", "Experiment7IsScreamer", "Experiment7IsExploder", 5, false, false, false, false, "Experiment7NoKnockdown", true),
        ["AAGrey01_Costume"] = d("Grey01Health", "Grey01IsRunner", "Grey01IsClimber", "Grey01IsWallBreaker", "Grey01IsToxic", "Grey01IsScreamer", "Grey01IsExploder", 10, false, false, true, false, "Grey01NoKnockdown", true),
        ["AASkinnyBob01_Costume"] = d("SkinnyBob01Health", "SkinnyBob01IsRunner", "SkinnyBob01IsClimber", "SkinnyBob01IsWallBreaker", "SkinnyBob01IsToxic", "SkinnyBob01IsScreamer", "SkinnyBob01IsExploder", 5, false, false, true, false, "SkinnyBob01NoKnockdown", true),
    }

    naturalSpawn = {}
    for outfitName in pairs(skinData) do
        local base = tostring(outfitName):gsub("^AA", "")
        base = base:gsub("_Costume$", "")
        local en = vars[base .. "Enable"]
        local ch = vars[base .. "SpawnChance"]
        if en ~= false and ch and ch > 0 then
            naturalSpawn[#naturalSpawn + 1] = { outfit = outfitName, chance = ch, nightOnly = pick(vars[base .. "NightOnly"], false) }
        end
    end
end

local function forEachLocalPlayer(callback)
    for i = 0, 3 do
        local p = getSpecificPlayer(i)
        if p and not p:isDead() then callback(p) end
    end
end

local function damagePlayer(player, dmg)
    local bd = player:getBodyDamage()
    if not bd then return end
    local parts = bd:getBodyParts()
    for i = 0, parts:size() - 1 do
        local bp = parts:get(i)
        if bp then
            bp:AddDamage(dmg)
            syncBodyPart(bp, 0xFFFFFFFFFFF)
        end
    end
end

local function playExplosionSoundAt(x, y, z)
    local sq = getCell():getGridSquare(x, y, z)
    if sq then
        getSoundManager():PlayWorldSound("IZ_ZExplode", sq, 0, 20, 1.0, true)
    end
end

local SCREAM_VOICES = {
    grey   = { prefix = "ZSE_GreyVoice",   count = 12 },
    skinny = { prefix = "ZSE_SkinnyVoice", count = 12 },
}

local VOICE_BY_OUTFIT = {
    ["AAGrey01_Costume"]       = "grey",
    ["AASkinnyBob01_Costume"]  = "skinny",
}

local function screamSoundName(voice)
    local set = type(voice) == "string" and SCREAM_VOICES[voice] or nil
    if set then
        local n = ZombRand(set.count) + 1
        return set.prefix .. (n < 10 and ("0" .. tostring(n)) or tostring(n))
    end
    return "screamer" .. tostring(ZombRand(2) + 1)
end

local function playScreamSoundAt(x, y, z, voice)
    local sq = getCell():getGridSquare(x, y, z)
    if sq then
        getSoundManager():PlayWorldSound(screamSoundName(voice), sq, 0, 30, 1.0, false)
    end
end

local function delaySeconds(func, seconds)
    local target = getTimestampMs() + seconds * 1000
    local function onTick()
        if getTimestampMs() < target then return end
        Events.OnTick.Remove(onTick)
        func()
    end
    Events.OnTick.Add(onTick)
end

local function explodePlayerDamage(cx, cy, cz)
    forEachLocalPlayer(function(player)
        if math.floor(player:getZ() + 0.5) == math.floor(cz + 0.5) then
            local dx, dy = player:getX() - cx, player:getY() - cy
            if math.sqrt(dx * dx + dy * dy) <= exploderRadius then
                damagePlayer(player, exploderDamagePlayers)
            end
        end
    end)
end

local function explodeWorldDamage(cx, cy, cz, includeFire)
    local r = exploderRadius
    for x = cx - r, cx + r do
        for y = cy - r, cy + r do
            local dx, dy = x - cx, y - cy
            if math.sqrt(dx * dx + dy * dy) <= r then
                local osq = getCell():getGridSquare(x, y, cz)
                if osq then
                    local mObjs = osq:getMovingObjects()
                    for k = mObjs:size() - 1, 0, -1 do
                        local o = mObjs:get(k)

                        if o and instanceof(o, "IsoZombie") and not o:isDead()
                            and not isALifeActor(o, o:getModData()) then
                            o:setHealth(o:getHealth() - exploderDamageZombies)
                            if o:getHealth() <= 0 then
                                local attacker = getCell():getFakeZombieForHit()
                                if o.becomeCorpse then
                                    o:changeState(ZombieOnGroundState.instance())
                                    o:setAttackedBy(attacker)
                                    o:becomeCorpse()
                                else

                                    local ok, err = pcall(function() o:Kill(attacker) end)
                                    if not ok then print("[ZSExpanded] blast could not kill zombie: " .. tostring(err)) end
                                end
                            else
                                o:knockDown(true)
                            end
                        end
                    end
                end
            end
        end
    end
    if includeFire and exploderEmitFire then
        local sq = getCell():getGridSquare(cx, cy, cz)
        if sq then
            IsoFireManager.StartFire(getCell(), sq, true, exploderFireEnergy, exploderFireDuration)
        end
    end
end

local function triggerClimb(zombie)
    zombie:setVariable("hitreaction", "ZombieClimbWallReactionStart")
    zombie:setVariable("ZombieClimbWallChanceNumber", ZombRand(0, 100))
end

local function climbWallFunction(zombie)
    if zombie:isOnFloor() or zombie:isStaggerBack() then return end

    local sq = zombie:getCurrentSquare()
    if not sq then return end
    local z = sq:getZ()

    local squareAbove = getCell():getGridSquare(sq:getX(), sq:getY(), z + 1)
    if squareAbove ~= nil and squareAbove:getFloor() ~= nil then return end

    local fd = zombie:getForwardDirection()
    local nx = sq:getX() + math.floor(fd:getX() + 0.5)
    local ny = sq:getY() + math.floor(fd:getY() + 0.5)
    local squareAheadAbove = getCell():getGridSquare(nx, ny, z + 1)
    if squareAheadAbove ~= nil and squareAheadAbove:getFloor() ~= nil then return end

    if zombie:isCollidedThisFrame() and not zombie:getVariableBoolean("ZombieClimbWallStarted") then
        triggerClimb(zombie)
    end

    if zombie:getVariableBoolean("ZombieClimbWallStarted") and not zombie:isDead() and not zombie:isOnFloor() then
        local chance = zombie:getVariableFloat("ZombieClimbWallChanceNumber", 0)
        if chance > 40 then
            if not zombie:isVariable("hitreaction", "ZombieClimbWallReactionFail") then
                zombie:setVariable("hitreaction", "ZombieClimbWallReactionFail")
            end
        elseif chance > 0 then
            if zombie:isCollidable() then zombie:setCollidable(false) end
            if not zombie:isVariable("hitreaction", "ZombieClimbWallReactionSuccess") then
                zombie:setVariable("hitreaction", "ZombieClimbWallReactionSuccess")
            end
        else
            if not zombie:isVariable("hitreaction", "ZombieClimbWallReactionFail") then
                zombie:setVariable("hitreaction", "ZombieClimbWallReactionFail")
            end
        end
    end
end

local function isBreakable(o)
    return o and (instanceof(o, "IsoThumpable") or instanceof(o, "IsoBarricade")
        or instanceof(o, "IsoWindow") or instanceof(o, "IsoDoor"))
end

local function clearConstructionsFromList(sq, objs)
    if not objs then return end
    for i = objs:size() - 1, 0, -1 do
        local o = objs:get(i)
        if isBreakable(o) then
            sq:transmitRemoveItemFromSquare(o)
        end
    end
end

local function clearConstructionsOnSquare(sq)
    if not sq then return end
    clearConstructionsFromList(sq, sq:getObjects())
    clearConstructionsFromList(sq, sq:getSpecialObjects())
end

local function wallBreakFunction(zombie)
    local md = zombie:getModData()
    local now = getTimestampMs()
    if md.IZSkins_wallNext and now < md.IZSkins_wallNext then return end
    md.IZSkins_wallNext = now + 1000

    local sq = zombie:getCurrentSquare()
    if not sq then return end

    local fd = zombie:getForwardDirection()
    local nx = sq:getX() + math.floor(fd:getX() + 0.5)
    local ny = sq:getY() + math.floor(fd:getY() + 0.5)
    local ahead = getCell():getGridSquare(nx, ny, sq:getZ())

    clearConstructionsOnSquare(sq)
    clearConstructionsOnSquare(ahead)
end

local function isWearingHazmat(player)
    local worn = player:getWornItems()
    for i = 0, worn:size() - 1 do
        local item = worn:getItemByIndex(i)
        if item and string.find(string.lower(item:getType()), "hazmat") then
            return true
        end
    end
    return false
end

local function toxicFunction(zombie)
    local md = zombie:getModData()
    md.IZSkins_toxicTicks = (md.IZSkins_toxicTicks or 0) + 1
    if md.IZSkins_toxicTicks < toxicCooldown then return end
    md.IZSkins_toxicTicks = 0

    forEachLocalPlayer(function(player)
        if not isWearingHazmat(player) and zombie:DistTo(player) <= toxicRadius then
            if isSingleplayer() then
                damagePlayer(player, toxicDamage)
            else

                sendClientCommand(player, "ZSExpanded", "ToxicDamage", { dmg = toxicDamage })
            end
        end
    end)
end

local function screamerFunction(zombie)
    local md = zombie:getModData()
    md.IZSkins_screamerTicks = (md.IZSkins_screamerTicks or 0) + 1
    if md.IZSkins_screamerTicks < screamerCooldown then return end
    md.IZSkins_screamerTicks = 0

    local x, y, z = zombie:getX(), zombie:getY(), zombie:getZ()
    local voice = alienVoices and VOICE_BY_OUTFIT[zombie:getOutfitName()] or nil
    if isSingleplayer() then
        addSound(zombie, x, y, z, screamerRadius, screamerVolume)
        playScreamSoundAt(x, y, z, voice)
    else

        sendClientCommand(getPlayer(), "ZSExpanded", "Scream", { x = x, y = y, z = z, voice = voice })
    end
end

local function triggerExplosion(cx, cy, cz)
    if isSingleplayer() then

        playExplosionSoundAt(cx, cy, cz)
        delaySeconds(function()
            explodePlayerDamage(cx, cy, cz)
            explodeWorldDamage(cx, cy, cz, true)
        end, 2)
    else

        sendClientCommand(getPlayer(), "ZSExpanded", "Explode", {
            x = cx, y = cy, z = cz,
            radius = exploderRadius, dmg = exploderDamagePlayers,
            emitFire = exploderEmitFire, fireEnergy = exploderFireEnergy, fireDuration = exploderFireDuration,
        })
    end
end

local function clearBodyVisuals(zombie)
    local ok, hadAny = pcall(function()
        local visuals = zombie:getHumanVisual():getBodyVisuals()
        if visuals and visuals:size() > 0 then
            visuals:clear()
            return true
        end
        return false
    end)
    if ok and hadAny then
        pcall(function() zombie:resetModelNextFrame() end)
    end
end

local function removeLightItems(zombie)
    local inv = zombie:getInventory()
    local items = inv:getItems()
    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if string.find(item:getType(), "_Costume_Light") then
            inv:Remove(item)
        end
    end
end

local function debugLog(msg)
    if nightDebug then print("[ZSExpanded] " .. msg) end
end

local MAX_SAFE_HEALTH = 30

local function applyHealth(zombie, md, data)
    local health = math.min(data.health, MAX_SAFE_HEALTH)
    local ok, id = pcall(function() return zombie:getPersistentOutfitID() end)
    local key = tostring(zombie:getOutfitName()) .. ":" .. tostring(health) .. ":" .. tostring(ok and id or "")
    if md.IZSkins_hpKey == key then return end
    md.IZSkins_hpKey = key
    zombie:setHealth(health)

    debugLog(string.format("health set on %s: wanted %s, engine reads %s", tostring(zombie:getOutfitName()),
        tostring(health), tostring(zombie:getHealth())))
end

local function onZombieUpdate(zombie)
    if not zombie or zombie:isDead() then return end

    local md = zombie:getModData()

    if isALifeActor(zombie, md) then
        if md.IZSkins_isExploder then md.IZSkins_isExploder = nil end
        return
    end

    if isMarkedSpecialZed(zombie, md) then return end

    local firstSight = not md.IZSkins_stripped
    if firstSight then
        removeLightItems(zombie)
        md.IZSkins_stripped = true
    end

    local outfit = zombie:getOutfitName()
    if not outfit then return end
    local data = skinData[outfit]

    local isExploderNow = (data and data.isExploder) or false
    if isExploderNow and not md.IZSkins_isExploder then
        md.IZSkins_isExploder = true
    elseif not isExploderNow and md.IZSkins_isExploder then
        md.IZSkins_isExploder = nil
    end

    if firstSight and not data and isSingleplayer() and #naturalSpawn > 0
        and (not precipitationOnly or isPrecipitating())
        and (not nightOnly or isNight()) then

        local night = isNight()
        local roll = ZombRand(10000) / 100
        local cumulative = 0
        for _, s in ipairs(naturalSpawn) do
            if night or not s.nightOnly then
                cumulative = cumulative + s.chance * nightState.spawnMult
                if roll < cumulative then
                    pcall(function()
                        zombie:dressInNamedOutfit(s.outfit)
                        zombie:resetModelNextFrame()
                    end)
                    break
                end
            end
        end
        return
    end

    if not data then return end

    if data.isClimber then
        climbWallFunction(zombie)
    end

    if data.isWallBreaker then
        wallBreakFunction(zombie)
    end

    if data.isToxic then
        toxicFunction(zombie)
    end

    if data.isScreamer then
        screamerFunction(zombie)
    end

    md.IZSkins_ticks = (md.IZSkins_ticks or 0) + 1

    if md.IZSkins_ticks == 1 or md.IZSkins_ticks >= updateInterval then
        clearBodyVisuals(zombie)
        applyHealth(zombie, md, data)

        if nightDebug and (md.IZSkins_dbgN or 0) < 6 then
            md.IZSkins_dbgN = (md.IZSkins_dbgN or 0) + 1
            debugLog(string.format("%s health now %s (update %d)", tostring(outfit), tostring(zombie:getHealth()),
                md.IZSkins_ticks))
        end
    end

    if md.IZSkins_ticks >= updateInterval then
        if data.isRunner then
            zombie:setWalkType("sprint4")
            markSprinterForPhunSprinters(zombie, md)
        end
        md.IZSkins_ticks = 0
    end
end

local function onHitZombie(zombie, wielder, bodyPart, weapon)
    if not zombie then return end
    local md = zombie:getModData()
    if isMarkedSpecialZed(zombie, md) then return end
    local outfit = zombie:getOutfitName()
    if not outfit then return end
    local data = skinData[outfit]
    if not data then return end

    if data.isClimber then
        zombie:setCollidable(true)
        zombie:setVariable("ZombieClimbWallStarted", false)
        if zombie:isVariable("hitreaction", "ZombieClimbWallReactionSuccess") or zombie:isVariable("hitreaction", "ZombieClimbWallReactionFail") then
            zombie:setVariable("hitreaction", nil)
        end
    end

    if data.noKnockdown and wielder and instanceof(wielder, "IsoPlayer") and wielder:isDoShove() then
        wielder:setCriticalHit(false)
    end
end

local function onZombieDead(zombie)
    if not zombie then return end
    local md = zombie:getModData()
    if nightDebug and md.IZSkins_hpKey then
        local okFire, fire = pcall(function() return zombie:isOnFire() end)
        debugLog(string.format("%s died: health %s, on fire %s", tostring(zombie:getOutfitName()),
            tostring(zombie:getHealth()), tostring(okFire and fire)))
    end

    if isALifeActor(zombie, md) then return end
    if not md.IZSkins_isExploder then return end
    local sq = zombie:getSquare()
    if not sq then return end
    triggerExplosion(sq:getX(), sq:getY(), sq:getZ())
end

local function onServerCommand(module, command, args)
    if module ~= "ZSExpanded" then return end
    if command == "Scream" then
        addSound(nil, args.x, args.y, args.z, screamerRadius, screamerVolume)
        playScreamSoundAt(args.x, args.y, args.z, args.voice)
    elseif command == "Explode" then

        playExplosionSoundAt(args.x, args.y, args.z)
        delaySeconds(function()
            explodeWorldDamage(args.x, args.y, args.z, false)
        end, 2)
    end
end

Events.OnGameStart.Add(buildSkinData)
Events.EveryOneMinute.Add(buildSkinData)
Events.OnZombieUpdate.Add(onZombieUpdate)
Events.OnHitZombie.Add(onHitZombie)
Events.OnZombieDead.Add(onZombieDead)
Events.OnServerCommand.Add(onServerCommand)
