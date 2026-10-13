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

function N.window()
    local s = clamp(math.floor(opt("NightStartHour", 0)), 0, 23)
    local e = clamp(math.floor(opt("NightEndHour", 6)), 1, 24)
    return s, e
end

function N.nightOnly()
    return opt("NightOnly", false) == true
end

function N.spawnScaleOn()
    return opt("NightSpawnScale", false) == true
end

function N.isNight(hour)
    hour = hour or currentHour()
    if not hour then return false end
    local s, e = N.window()
    if s < e then return hour >= s and hour < e end
    return hour >= s or hour < e
end

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

local MOD = 2147483647
local function mix(x)
    x = math.floor(math.abs(x)) % MOD
    for _ = 1, 6 do
        x = (x * 48271 + (x % 1013) * 7919 + 12345) % MOD
    end
    return x
end

local function unit(seed)
    return mix(seed) / MOD
end

function N.state()
    local st = { night = false, quiet = false, intensity = 0, spawnMult = 1 }
    if not N.isNight() then return st end
    st.night = true

    if not N.spawnScaleOn() then return st end

    local idx = N.nightIndex()
    local quietChance = clamp(opt("NightQuietChance", 15), 0, 100)
    st.quiet = unit(idx * 3 + 1) * 100 < quietChance
    st.intensity = st.quiet and 0 or unit(idx * 3 + 2)

    local lo, hi = opt("NightSpawnMin", 50), opt("NightSpawnMax", 300)
    if lo > hi then lo, hi = hi, lo end

    st.spawnMult = math.max(0, (lo + (hi - lo) * st.intensity) / 100)

    return st
end

return N
