-- Zombie Skins: Expanded - lado SERVIDOR (multiplayer).
--
-- La deteccion de habilidades vive en el cliente (los zombies cercanos se simulan alli),
-- pero el DANO AL JUGADOR es autoritativo del servidor: si lo aplica el cliente, el
-- servidor lo sobreescribe en el siguiente update (por eso en MP no pasaba nada). Asi lo
-- hacia tambien el mod original en Build 41: el dano se aplicaba en lua/server. Aqui el
-- cliente detecta y avisa, y el servidor aplica el dano y lo sincroniza.
-- En singleplayer este archivo no hace nada (no hay red; el cliente resuelve todo).

-- Resta vida al jugador. En B42 hay que llamar a syncBodyPart() tras modificar la parte
-- para que el cambio se propague (0xFFFFFFFFFFF = todos los campos, igual que hace el
-- propio juego en ClientCommands.lua). Aplicado en el servidor, sincroniza al cliente.
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

-- Ejecuta func tras `seconds` de tiempo real (OnTick es por-frame; usamos reloj).
local function delaySeconds(func, seconds)
    local target = getTimestampMs() + seconds * 1000
    local function onTick()
        if getTimestampMs() < target then return end
        Events.OnTick.Remove(onTick)
        func()
    end
    Events.OnTick.Add(onTick)
end

-- Deduplicacion de eventos de sonido/explosion por si llegan desde varios clientes.
local lastEvent = {}
local dedupWindowMs = 1500

local function shouldRelay(command, args)
    local key = command .. ":" .. math.floor(args.x) .. "," .. math.floor(args.y) .. "," .. math.floor(args.z)
    local now = getTimestampMs()
    if lastEvent[key] and (now - lastEvent[key]) < dedupWindowMs then
        return false
    end
    lastEvent[key] = now
    return true
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
        -- El cliente ya comprobo rango y Hazmat; danamos al jugador que envio el comando.
        if args and args.dmg then damagePlayer(player, args.dmg) end
        return
    end

    if command == "Scream" then
        if args and args.x ~= nil and shouldRelay(command, args) then
            sendServerCommand("ZSExpanded", "Scream", args)
        end
        return
    end

    if command == "Explode" then
        if not args or args.x == nil then return end
        if not shouldRelay(command, args) then return end
        -- Reemitir a todos los clientes (sonido + dano a zombies que cada uno simula).
        sendServerCommand("ZSExpanded", "Explode", args)
        -- Dano autoritativo a los jugadores en radio, 2s despues (cuadra con el sonido).
        local cx, cy, cz = args.x, args.y, args.z
        local radius, dmg = args.radius or 5, args.dmg or 3
        delaySeconds(function()
            damagePlayersInRadius(cx, cy, cz, radius, dmg)
        end, 2)
        -- Fuego autoritativo: el fuego es estado del mundo, asi que lo inicia el SERVIDOR
        -- (no cada cliente por separado, que es lo que hacia antes y no persistia en MP -
        -- el fuego iniciado solo en un cliente se perdia en el siguiente sync del mundo).
        if args.emitFire then
            local fireEnergy = args.fireEnergy or 5.0
            local fireDuration = args.fireDuration or 300
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
