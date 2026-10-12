local function damagePlayer(player, dmg)
    local bd = player and player:getBodyDamage()
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

local function delaySeconds(func, seconds)
    local target = getTimestampMs() + seconds * 1000
    local function onTick()
        if getTimestampMs() < target then return end
        Events.OnTick.Remove(onTick)
        func()
    end
    Events.OnTick.Add(onTick)
end

local lastEvent = {}
local dedupWindowMs = 1500
local lastPrune = 0

local function shouldRelay(command, args)
    local key = command .. ":" .. math.floor(args.x) .. "," .. math.floor(args.y) .. "," .. math.floor(args.z)
    local now = getTimestampMs()

    if now - lastPrune > 60000 then
        lastPrune = now
        for k, t in pairs(lastEvent) do
            if now - t >= dedupWindowMs then lastEvent[k] = nil end
        end
    end
    if lastEvent[key] and (now - lastEvent[key]) < dedupWindowMs then
        return false
    end
    lastEvent[key] = now
    return true
end

local function serverSetting(key, clientValue, default, max)
    local vars = SandboxVars and SandboxVars.ZSExpanded
    local v = vars and vars[key]
    if v == nil then v = tonumber(clientValue) or default end
    if v > max then v = max end
    if v < 0 then v = 0 end
    return v
end

local function isCoordinate(args)
    return type(args) == "table" and type(args.x) == "number" and type(args.y) == "number"
        and type(args.z) == "number"
end

local function damagePlayersInRadius(cx, cy, cz, radius, dmg)
    local players = getOnlinePlayers()
    if not players then return end
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p and not p:isDead() and math.floor(p:getZ() + 0.5) == math.floor(cz + 0.5) then
            local dx, dy = p:getX() - cx, p:getY() - cy
            if math.sqrt(dx * dx + dy * dy) <= radius then
                damagePlayer(p, dmg)
            end
        end
    end
end

local function onClientCommand(module, command, player, args)
    if module ~= "ZSExpanded" then return end

    if command == "ToxicDamage" then

        damagePlayer(player, serverSetting("ToxicDamage", args and args.dmg, 0.5, 10))
        return
    end

    if command == "Scream" then
        if isCoordinate(args) and shouldRelay(command, args) then

            sendServerCommand("ZSExpanded", "Scream", { x = args.x, y = args.y, z = args.z, voice = args.voice })
        end
        return
    end

    if command == "Explode" then
        if not isCoordinate(args) then return end
        if not shouldRelay(command, args) then return end
        local cx, cy, cz = args.x, args.y, args.z
        local radius = serverSetting("ExploderRadius", args.radius, 5, 50)
        local dmg = serverSetting("ExploderDamagePlayers", args.dmg, 3, 30)

        sendServerCommand("ZSExpanded", "Explode", { x = cx, y = cy, z = cz, radius = radius, dmg = dmg })

        delaySeconds(function()
            damagePlayersInRadius(cx, cy, cz, radius, dmg)
        end, 2)

        local vars = SandboxVars and SandboxVars.ZSExpanded
        local emitFire = vars and vars.ExploderEmitFire
        if emitFire == nil then emitFire = args.emitFire end
        if emitFire then
            local fireEnergy = serverSetting("ExploderFireEnergy", args.fireEnergy, 5.0, 100)
            local fireDuration = serverSetting("ExploderFireDuration", args.fireDuration, 300, 10000)
            delaySeconds(function()
                local sq = getCell():getGridSquare(cx, cy, cz)
                if sq then
                    IsoFireManager.StartFire(getCell(), sq, true, fireEnergy, fireDuration)
                end
            end, 2)
        end
        return
    end
end

Events.OnClientCommand.Add(onClientCommand)
