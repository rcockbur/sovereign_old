-- simulation/health.lua
-- Stateless health recalculation. Called once per HASH_INTERVAL ticks per unit.
-- health = 100 + sum(modifier.value), clamped 0-100.
-- Modifier values are <= 0; they increase toward 0 as the unit recovers.
-- Death fires when health <= 0.

local math_max    = math.max
local math_min    = math.min
local math_random = math.random

local health = {}

--- Process one injury modifier. Returns true if the modifier should be removed.
local function tickInjury(mod)
    local cfg = InjuryConfig[mod.subtype]
    mod.value = mod.value + cfg.recovery * HASH_INTERVAL
    return mod.value >= 0
end

--- Process one illness modifier. Returns true if the modifier should be removed.
local function tickIllness(mod)
    local cfg = IllnessConfig[mod.subtype]
    if mod.is_recovering then
        mod.value = mod.value + cfg.recovery * HASH_INTERVAL
        return mod.value >= 0
    else
        mod.value = mod.value - cfg.damage * HASH_INTERVAL
        if math_random() < cfg.recovery_chance then
            mod.is_recovering = true
        end
        return false
    end
end

--- Process the malnourished modifier. Returns true if the modifier should be removed.
local function tickMalnourished(mod, unit)
    if unit.needs.satiation <= 0 then
        mod.value = mod.value - MalnourishedConfig.damage * HASH_INTERVAL
        return false
    else
        mod.value = mod.value + MalnourishedConfig.recovery * HASH_INTERVAL
        return mod.value >= 0
    end
end

--- Recalculate unit.health from scratch. Sets unit.is_dead = true if health <= 0.
function health.recalculate(unit, time)
    -- Add malnourished modifier if satiation is empty and one isn't already present
    if unit.needs.satiation <= 0 then
        local has_malnourished = false
        for i = 1, #unit.health_modifiers do
            if unit.health_modifiers[i].type == "malnourished" then
                has_malnourished = true
                break
            end
        end
        if has_malnourished == false then
            table.insert(unit.health_modifiers, {
                type    = "malnourished",
                subtype = nil,
                source  = "malnourished",
                value   = 0,
            })
        end
    end

    -- Tick each modifier; remove recovered ones (swap-and-pop)
    local i = 1
    while i <= #unit.health_modifiers do
        local mod     = unit.health_modifiers[i]
        local is_expired = false

        if mod.type == "injury" then
            is_expired = tickInjury(mod)
        elseif mod.type == "illness" then
            is_expired = tickIllness(mod)
        elseif mod.type == "malnourished" then
            is_expired = tickMalnourished(mod, unit)
        end

        if is_expired then
            unit.health_modifiers[i] = unit.health_modifiers[#unit.health_modifiers]
            unit.health_modifiers[#unit.health_modifiers] = nil
        else
            i = i + 1
        end
    end

    -- Sum all modifier values
    local total = 100
    for i = 1, #unit.health_modifiers do
        total = total + unit.health_modifiers[i].value
    end
    unit.health = math_max(0, math_min(100, total))

    if unit.health <= 0 then
        unit.is_dead    = true
        unit.death_cause = "health"
    end
end

return health
