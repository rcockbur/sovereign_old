-- simulation/mood.lua
-- Stateless mood recalculation. Called once per HASH_INTERVAL ticks per unit.
-- mood = sum of stored decaying modifiers + sum of calculated modifiers.
-- Stored modifiers tick down by 1 per hash update and are removed when expired.

local mood = {}

--- Tick down all stored modifiers. Remove any that have expired.
local function processModifiers(unit)
    local i = 1
    while i <= #unit.mood_modifiers do
        local mod = unit.mood_modifiers[i]
        mod.ticks_remaining = mod.ticks_remaining - 1
        if mod.ticks_remaining <= 0 then
            unit.mood_modifiers[i] = unit.mood_modifiers[#unit.mood_modifiers]
            unit.mood_modifiers[#unit.mood_modifiers] = nil
        else
            i = i + 1
        end
    end
end

--- Calculated modifiers — each is a stub returning 0 until the relevant system exists.

local function calcNeedsPenalty(unit)
    local cfg = NeedsConfig[unit.is_child and "child" or unit.tier]
    local total = 0
    if unit.needs.satiation  <= cfg.satiation.mood_threshold  then total = total + cfg.satiation.mood_penalty  end
    if unit.needs.energy     <= cfg.energy.mood_threshold     then total = total + cfg.energy.mood_penalty     end
    if unit.needs.recreation <= cfg.recreation.mood_threshold then total = total + cfg.recreation.mood_penalty end
    return total
end

local function calcHousing(unit)      return 0 end  -- Phase 6
local function calcFoodVariety(unit)  return 0 end  -- Phase 6
local function calcRelationships(unit) return 0 end -- Phase 7
local function calcHealthPenalty(unit) return 0 end -- Phase 6

--- Recalculate unit.mood from scratch.
function mood.recalculate(unit, time)
    processModifiers(unit)

    local total = 0

    -- Stored decaying modifiers (family death, events, etc.)
    for i = 1, #unit.mood_modifiers do
        total = total + unit.mood_modifiers[i].value
    end

    -- Calculated modifiers derived from current state
    total = total + calcNeedsPenalty(unit)
    total = total + calcHousing(unit)
    total = total + calcFoodVariety(unit)
    total = total + calcRelationships(unit)
    total = total + calcHealthPenalty(unit)

    unit.mood = total
end

return mood
