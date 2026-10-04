-- Night helper shared by the zone definitions (spawn side) and the client (sprint side).
--
-- One configurable night window, plus a per-night "intensity" that is rolled once per night. Every client and the
-- server derive it from the in-game date alone, so they all agree without sending anything over the network.
-- Intensity drives two things: how many of our skins spawn (spawn multiplier) and what share of them sprint.

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

-- Fog density 0..1 from the climate manager (0 = clear). An unreadable value counts as clear.
function N.fogIntensity()
    local ok, fog = pcall(function() return getClimateManager():getFogIntensity() end)
    if ok and type(fog) == "number" then return fog end
    return 0
end

-- True when fog is at least as dense as the FogMinIntensity setting (percent). The setting is the knob for how
-- heavy "fog" has to be: light mist sits low on the scale, thick fog near the top.
function N.isFoggy()
    local min = clamp(opt("FogMinIntensity", 60), 1, 100) / 100
    return N.fogIntensity() >= min
end

-- Moon brightness 0 (new) .. 1 (full) for each of the 8 phases, 0-indexed like getCurrentMoonPhase().
local MOON_LIGHT = { [0] = 0, 0.25, 0.5, 0.75, 1, 0.75, 0.5, 0.25 }

local function moonMultiplier()
    if not opt("NightMoonScaling", false) then return 1 end
    local ok, phase = pcall(function() return getClimateMoon():getCurrentMoonPhase() end)
    local light = ok and MOON_LIGHT[phase] or nil
    if not light then return 1 end
    local new = opt("NightMoonNew", 50) / 100
    local full = opt("NightMoonFull", 200) / 100
    return new + (full - new) * light
end

-- Everything that depends on tonight. The result is a plain table the caller may keep for the current minute.
--   night        inside the window
--   quiet        a calm night: nothing extra happens
--   intensity    0..1, how bad tonight is
--   spawnMult    multiplier for skin spawn chances (1 outside the window or with the option off)
--   sprintChance percent of our skins that sprint tonight (0 when the feature is off)
function N.state()
    local st = { night = false, quiet = false, intensity = 0, spawnMult = 1, sprintChance = 0 }
    if not N.isNight() then return st end
    st.night = true

    local sprintOn = opt("NightSprintersEnable", false)
    local spawnOn = opt("NightSpawnScale", false)
    if not sprintOn and not spawnOn then return st end

    local idx = N.nightIndex()
    local quietChance = clamp(opt("NightQuietChance", 15), 0, 100)
    st.quiet = unit(idx * 3 + 1) * 100 < quietChance
    st.intensity = st.quiet and 0 or unit(idx * 3 + 2)

    local moon = moonMultiplier()

    if spawnOn then
        local lo, hi = opt("NightSpawnMin", 50), opt("NightSpawnMax", 300)
        if lo > hi then lo, hi = hi, lo end
        -- A calm night spawns at the low end instead of at zero, so the skins never vanish entirely.
        st.spawnMult = math.max(0, (lo + (hi - lo) * st.intensity) / 100 * moon)
    end

    if sprintOn and not st.quiet then
        local lo, hi = opt("NightSprinterMin", 15), opt("NightSprinterMax", 60)
        if lo > hi then lo, hi = hi, lo end
        st.sprintChance = clamp((lo + (hi - lo) * st.intensity) * moon, 0, 100)
    end

    return st
end

-- Stable per-zombie roll in [0, 100) for tonight, so a zombie keeps its answer when it changes hands between
-- clients. Falls back to a random roll kept in modData if the game does not give us a persistent id.
function N.zombieRoll(zombie, md)
    local idx = N.nightIndex()
    if md.ZSE_rollNight == idx and md.ZSE_roll then return md.ZSE_roll end
    local ok, id = pcall(function() return zombie:getPersistentOutfitID() end)
    local roll
    if ok and type(id) == "number" then
        roll = unit(id * 7 + idx) * 100
    else
        roll = ZombRand(10000) / 100
    end
    md.ZSE_rollNight = idx
    md.ZSE_roll = roll
    return roll
end

return N
