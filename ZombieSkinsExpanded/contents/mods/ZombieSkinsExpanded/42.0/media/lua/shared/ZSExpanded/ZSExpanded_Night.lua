-- Night helper shared by the zone definitions (spawn side) and the client.
--
-- One configurable night window, plus a per-night "intensity" that is rolled once per night. Every client and the
-- server derive it from the in-game date alone, so they all agree without sending anything over the network.
-- Intensity drives how many of our skins spawn (the spawn multiplier).

ZSExpandedNight = ZSExpandedNight or {}
local N = ZSExpandedNight

local function vars()
    return SandboxVars and SandboxVars.ZSExpanded or nil
end

local function opt(key, default)
    local v = vars()
    v = v and v[key]
    if v == nil then return default end
    return v
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function currentHour()
    local ok, hour = pcall(function() return getGameTime():getHour() end)
    if ok and type(hour) == "number" then return hour end
    return nil
end

-- Window start/end hour. Start is 0-23, end is 1-24 and exclusive. Start >= end wraps past midnight (22 -> 5 is
-- 10pm to 5am); start == end covers the whole day.
function N.window()
    local s = clamp(math.floor(opt("NightStartHour", 0)), 0, 23)
    local e = clamp(math.floor(opt("NightEndHour", 6)), 1, 24)
    return s, e
end

-- Nightmare is a shortcut for two options at once: Spawn Only At Night and Night Spawn Scaling. Either option can
-- still be turned on by itself.
function N.nightmare()
    return opt("Nightmare", false) == true
end

function N.nightOnly()
    return opt("NightOnly", false) == true or N.nightmare()
end

function N.spawnScaleOn()
    return opt("NightSpawnScale", false) == true or N.nightmare()
end

function N.isNight(hour)
    hour = hour or currentHour()
    if not hour then return false end -- an unreadable clock counts as not night
    local s, e = N.window()
    if s < e then return hour >= s and hour < e end
    return hour >= s or hour < e
end

-- Number identifying the night we are in. The part of a wrapping window after midnight still belongs to the
-- night that started the evening before.
function N.nightIndex()
    local ok, idx = pcall(function()
        local gt = getGameTime()
        local day = gt:getYear() * 372 + gt:getMonth() * 31 + gt:getDay()
        local s, e = N.window()
        if s >= e and gt:getHour() < e then day = day - 1 end
        return day
    end)
    if ok and type(idx) == "number" then return idx end
    return 0
end

-- Integer-only hash, so the result is identical on every machine (no floating point functions involved).
-- The `x % 1013` term keeps neighbouring seeds from producing an obvious arithmetic pattern.
local MOD = 2147483647
local function mix(x)
    x = math.floor(math.abs(x)) % MOD
    for _ = 1, 6 do
        x = (x * 48271 + (x % 1013) * 7919 + 12345) % MOD
    end
    return x
end

-- Deterministic value in [0, 1) for a seed.
local function unit(seed)
    return mix(seed) / MOD
end

-- Current moon phase, 0 (new) to 7, with 4 being the full moon. nil if the game does not give one.
function N.moonPhase()
    local ok, phase = pcall(function() return getClimateMoon():getCurrentMoonPhase() end)
    if ok and type(phase) == "number" then return phase end
    return nil
end

local FULL_MOON = 4

-- Everything that depends on tonight. The result is a plain table the caller may keep for the current minute.
--   night        inside the window
--   quiet        a calm night: skins spawn at the low end of the range
--   intensity    0..1, how bad tonight is
--   spawnMult    multiplier for skin spawn chances (1 outside the window or with the options off)
function N.state()
    local st = { night = false, quiet = false, intensity = 0, spawnMult = 1 }
    if not N.isNight() then return st end
    st.night = true

    local scaleOn = N.spawnScaleOn()
    local fullMoonOn = opt("FullMoonDoubleSpawn", false) == true
    if not scaleOn and not fullMoonOn then return st end

    if scaleOn then
        local idx = N.nightIndex()
        local quietChance = clamp(opt("NightQuietChance", 15), 0, 100)
        st.quiet = unit(idx * 3 + 1) * 100 < quietChance
        st.intensity = st.quiet and 0 or unit(idx * 3 + 2)

        local lo, hi = opt("NightSpawnMin", 50), opt("NightSpawnMax", 300)
        if lo > hi then lo, hi = hi, lo end
        -- A calm night spawns at the low end instead of at zero, so the skins never vanish entirely.
        st.spawnMult = math.max(0, (lo + (hi - lo) * st.intensity) / 100)
    end

    -- Full moon doubles whatever the night would otherwise spawn.
    if fullMoonOn and N.moonPhase() == FULL_MOON then st.spawnMult = st.spawnMult * 2 end
    return st
end

return N
