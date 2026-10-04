-- Civil Defense Sirens (jbCivilDefenseSirens) hook: when a siren that attracts zombies starts up, a few of our
-- skins come out near each player who can hear it. Nothing here is configurable on purpose, and nothing happens
-- unless that mod is installed. The siren mod has no events to listen to, so we watch its siren objects instead.

if isClient() then return end

local MIN_ZOMBIES, MAX_ZOMBIES = 3, 5   -- per player per siren event
local MIN_DIST, MAX_DIST = 30, 50       -- tiles from the player, so they arrive from out of sight
local COOLDOWN_HOURS = 1                -- game hours before the same player is called out for again
local MAX_STAGGER_MS = 12000            -- zombies appear spread over this long, like they are coming out

local wasActive = {}   -- siren key -> was running at the last check
local primed = false   -- the first check only records state, so loading a save mid-siren spawns nothing
local lastCall = {}    -- player key -> world age hours of their last call-out
local queue = {}       -- { at = ms, fn = function }

local function sirenSystem()
    return SSirenSystem and SSirenSystem.instance or nil
end

local function forEachPlayer(fn)
    if isServer() then
        local players = getOnlinePlayers()
        if not players then return end
        for i = 0, players:size() - 1 do fn(players:get(i)) end
    else
        for i = 0, 3 do
            local p = getSpecificPlayer(i)
            if p then fn(p) end
        end
    end
end

local function playerKey(player)
    local ok, name = pcall(function() return player:getUsername() end)
    if ok and name and name ~= "" then return name end
    return tostring(player:getPlayerNum())
end

-- The siren mod's own rule for hearing: inside the loudness profile's audible range, or anywhere when "global
-- audible" is on. Deaf players never hear it; hard of hearing halves the range, as its wake-up logic does.
local function hasTrait(player, name)
    local ok, has = pcall(function() return player:hasTrait(CharacterTrait[name]) end)
    return ok and has == true
end

local function hearsSiren(player, siren)
    if player:isDead() then return false end
    if hasTrait(player, "DEAF") then return false end
    if CivilDefenseSiren.isGlobalAudible() then return true end
    local range = CivilDefenseSiren.getAudibleRadius()
    if hasTrait(player, "HARD_OF_HEARING") then range = range * 0.5 end
    local dx, dy = player:getX() - siren.x, player:getY() - siren.y
    return dx * dx + dy * dy <= range * range
end

-- Test sirens run with a zombie attraction radius of 0, and so can a server that turned attraction off. Those
-- are not a call to anyone.
local function attractsZombies(siren)
    local radius = siren.radius
    if radius == nil then radius = CivilDefenseSiren.getSoundRadius() end
    return radius > 0
end

local function pickOutfit()
    local skins = ZSExpandedEligibleSkins()
    local total = 0
    for _, s in ipairs(skins) do total = total + math.max(s.chance, 0) end
    if total <= 0 then return nil end
    local roll = ZombRand(10000) / 10000 * total
    for _, s in ipairs(skins) do
        roll = roll - math.max(s.chance, 0)
        if roll < 0 then return s.name end
    end
    return skins[#skins].name
end

-- A free ground square 30-50 tiles from the player and at least 30 from every other player. Buildings come
-- first (they "come out" of somewhere), then open ground.
local function farFromEveryone(x, y)
    local far = true
    forEachPlayer(function(p)
        local dx, dy = p:getX() - x, p:getY() - y
        if dx * dx + dy * dy < MIN_DIST * MIN_DIST then far = false end
    end)
    return far
end

local function findSpawnSquare(player)
    local cell = getCell()
    local px, py = player:getX(), player:getY()
    for attempt = 1, 30 do
        local angle = ZombRand(3600) / 3600 * 2 * math.pi
        local dist = MIN_DIST + ZombRand(MAX_DIST - MIN_DIST + 1)
        local x, y = math.floor(px + math.cos(angle) * dist), math.floor(py + math.sin(angle) * dist)
        local sq = cell:getGridSquare(x, y, 0)
        if sq and sq:isFree(false) and (attempt > 15 or sq:getRoom() ~= nil) and farFromEveryone(x, y) then
            return sq
        end
    end
    return nil
end

-- addZombiesInOutfit gained a trailing health argument in some builds; try the long form first.
local function spawnOne(x, y, z, outfit)
    local ok = pcall(function() addZombiesInOutfit(x, y, z, 1, outfit, 50, false, false, false, false, false, false, 1.0) end)
    if ok then return true end
    return pcall(function() addZombiesInOutfit(x, y, z, 1, outfit, 50, false, false, false, false, false, false) end)
end

local function callOut(player, siren)
    local count = MIN_ZOMBIES + ZombRand(MAX_ZOMBIES - MIN_ZOMBIES + 1)
    local now = getTimestampMs()
    for i = 1, count do
        queue[#queue + 1] = {
            at = now + ZombRand(MAX_STAGGER_MS),
            fn = function()
                if player:isDead() then return end
                local outfit = pickOutfit()
                local sq = outfit and findSpawnSquare(player)
                if not sq then return end
                if spawnOne(sq:getX(), sq:getY(), sq:getZ(), outfit) then
                    -- bring them to the player, as the siren is doing to everything else
                    addSound(nil, math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()), 60, 50)
                end
            end,
        }
    end
end

local function onTick()
    if #queue == 0 then return end
    local now = getTimestampMs()
    for i = #queue, 1, -1 do
        local job = queue[i]
        if now >= job.at then
            table.remove(queue, i)
            pcall(job.fn)
        end
    end
end

local function check()
    local system = sirenSystem()
    if not system or not CivilDefenseSiren then return end

    local started = {}
    for i = 1, system:getLuaObjectCount() do
        local siren = system:getLuaObjectByIndex(i)
        local key = siren.x .. "," .. siren.y
        local active = siren.active == true
        if primed and active and not wasActive[key] and attractsZombies(siren) then
            started[#started + 1] = siren
        end
        wasActive[key] = active
    end
    primed = true
    if #started == 0 then return end

    local hours = getGameTime():getWorldAgeHours()
    forEachPlayer(function(player)
        local key = playerKey(player)
        if lastCall[key] and hours - lastCall[key] < COOLDOWN_HOURS then return end
        -- one wave per player no matter how many sirens started together (a storm starts all of them at once)
        for _, siren in ipairs(started) do
            if hearsSiren(player, siren) then
                lastCall[key] = hours
                callOut(player, siren)
                return
            end
        end
    end)
end

Events.OnTick.Add(onTick)
Events.EveryOneMinute.Add(check)
