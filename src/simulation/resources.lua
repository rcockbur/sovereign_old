-- simulation/resources.lua
-- Resource entity lifecycle, container operations, reservation system, and running tallies.
-- Sole owner of all resource mutations — no other module writes to container contents,
-- reservation fields, or world.resource_counts.
--
-- Reservation units:
--   reserved_out  — item amounts  (matches stock formula: available = stock - reserved_out)
--   reserved_in   — weight units  (matches capacity formula: available = capacity - used - reserved_in)

local world    = require("core.world")
local registry = require("core.registry")

local resources = {}

-- ── Internal helpers ──────────────────────────────────────────────────────────

local function addToCount(tally, type, delta)
    tally[type] = (tally[type] or 0) + delta
    if tally[type] == 0 then tally[type] = nil end
end

local function isStack(entity)
    return entity.amount ~= nil
end

local function entityAmount(entity)
    return isStack(entity) and entity.amount or 1
end

local function entityWeight(entity_id)
    local e = registry[entity_id]
    return ResourceConfig[e.type].weight * entityAmount(e)
end

local function tileUsedWeight(tile_entry)
    local w = 0
    for i = 1, #tile_entry.contents do
        w = w + entityWeight(tile_entry.contents[i])
    end
    return w
end

local function containerCategory(container)
    local ct = container.container_type
    if ct == "tile_inventory" or ct == "stack_inventory" or ct == "item_inventory" then
        return "storage"
    elseif ct == "ground_pile" then
        return "ground"
    elseif ct == "bin" then
        return container.category
    end
    error("unknown container_type: " .. tostring(ct))
end

-- ── Tile inventory: internal tile selection ───────────────────────────────────

local function tileHasType(tile_entry, type)
    for i = 1, #tile_entry.contents do
        if registry[tile_entry.contents[i]].type == type then return true end
    end
    return false
end

local function tileHasOther(tile_entry, type)
    for i = 1, #tile_entry.contents do
        if registry[tile_entry.contents[i]].type ~= type then return true end
    end
    return false
end

local function tileStockOfType(tile_entry, type)
    local n = 0
    for i = 1, #tile_entry.contents do
        local e = registry[tile_entry.contents[i]]
        if e.type == type then n = n + entityAmount(e) end
    end
    return n
end

local function tileForDeposit(container, type, entity_weight)
    local best_same  = nil
    local best_empty = nil
    for idx, tile_entry in pairs(container.tiles) do
        local used       = tileUsedWeight(tile_entry)
        local phys_avail = container.tile_capacity - used
        if phys_avail >= entity_weight then
            local has_type  = tileHasType(tile_entry, type)
            local has_other = tileHasOther(tile_entry, type)
            if has_type and not has_other then
                if best_same == nil then
                    best_same = idx
                end
            elseif not has_type and not has_other then
                if best_empty == nil then
                    best_empty = idx
                end
            end
        end
    end
    return best_same or best_empty
end

local function tileForWithdraw(container, type)
    for idx, tile_entry in pairs(container.tiles) do
        if tileHasType(tile_entry, type) then
            return idx, tile_entry
        end
    end
    return nil, nil
end

local function tileForReserveOut(container, type, amount)
    for idx, tile_entry in pairs(container.tiles) do
        local stock = tileStockOfType(tile_entry, type)
        if stock - tile_entry.reserved_out >= amount then
            return idx
        end
    end
    return nil
end

local function tileForReserveIn(container, type, weight_amount)
    local best_same  = nil
    local best_empty = nil
    for idx, tile_entry in pairs(container.tiles) do
        local used  = tileUsedWeight(tile_entry)
        local avail = container.tile_capacity - used - tile_entry.reserved_in
        if avail >= weight_amount then
            local has_type  = tileHasType(tile_entry, type)
            local has_other = tileHasOther(tile_entry, type)
            if has_type and not has_other then
                if best_same == nil then
                    best_same = idx
                end
            elseif not has_type and not has_other then
                if best_empty == nil then
                    best_empty = idx
                end
            end
        end
    end
    return best_same or best_empty
end

-- ── Query operations ──────────────────────────────────────────────────────────

function resources.getStock(container, type)
    local ct = container.container_type
    if ct == "tile_inventory" then
        local total = 0
        for _, tile_entry in pairs(container.tiles) do
            total = total + tileStockOfType(tile_entry, type)
        end
        return total
    elseif ct == "bin" or ct == "stack_inventory" or ct == "item_inventory" or ct == "ground_pile" then
        local total = 0
        for i = 1, #container.contents do
            local e = registry[container.contents[i]]
            if e.type == type then
                total = total + entityAmount(e)
            end
        end
        return total
    end
    error("getStock: unknown container_type: " .. tostring(ct))
end

function resources.getAvailableStock(container, type)
    local ct = container.container_type
    if ct == "tile_inventory" then
        local available = 0
        for _, tile_entry in pairs(container.tiles) do
            local stock = tileStockOfType(tile_entry, type)
            if stock > 0 then
                available = available + math.max(0, stock - tile_entry.reserved_out)
            end
        end
        return available
    else
        return resources.getStock(container, type) - (container.reserved_out or 0)
    end
end

function resources.getAvailableCapacity(container, type)
    local ct = container.container_type
    if ct == "tile_inventory" then
        local physical = 0
        for _, tile_entry in pairs(container.tiles) do
            if not tileHasOther(tile_entry, type) then
                local used  = tileUsedWeight(tile_entry)
                local avail = math.max(0, container.tile_capacity - used - tile_entry.reserved_in)
                physical = physical + avail
            end
        end
        local filter = container.filters[type]
        if filter ~= nil and filter.limit ~= nil then
            local current     = resources.getStock(container, type)
            local limit_avail = math.max(0, filter.limit - current)
            physical = math.min(physical, limit_avail)
        end
        return physical
    elseif ct == "bin" then
        local used = 0
        for i = 1, #container.contents do
            used = used + entityWeight(container.contents[i])
        end
        return math.max(0, container.capacity - used - container.reserved_in)
    elseif ct == "stack_inventory" then
        local used = 0
        for i = 1, #container.contents do
            used = used + entityWeight(container.contents[i])
        end
        local physical = math.max(0, container.capacity - used - container.reserved_in)
        local filter = container.filters[type]
        if filter ~= nil and filter.limit ~= nil then
            local current     = resources.getStock(container, type)
            local limit_avail = math.max(0, filter.limit - current)
            physical = math.min(physical, limit_avail)
        end
        return physical
    elseif ct == "item_inventory" then
        return math.max(0, container.item_capacity - #container.contents - container.reserved_in)
    elseif ct == "ground_pile" then
        return math.huge
    end
    error("getAvailableCapacity: unknown container_type: " .. tostring(ct))
end

function resources.accepts(container, type)
    local ct = container.container_type
    if ct == "bin" then
        return container.type == type
    elseif ct == "tile_inventory" or ct == "stack_inventory" or ct == "item_inventory" then
        return container.filters[type].mode ~= "reject"
    elseif ct == "ground_pile" then
        return true
    end
    error("accepts: unknown container_type: " .. tostring(ct))
end

function resources.countWeight(carrying)
    local w = 0
    for i = 1, #carrying do
        w = w + entityWeight(carrying[i])
    end
    return w
end

-- ── Transfer operations ───────────────────────────────────────────────────────

function resources.deposit(container, entity_id)
    local e   = registry[entity_id]
    local ct  = container.container_type
    local cat = containerCategory(container)

    if ct == "tile_inventory" then
        local idx = tileForDeposit(container, e.type, entityWeight(entity_id))
        assert(idx ~= nil, "deposit: no tile available for type " .. e.type)
        local tile_entry = container.tiles[idx]
        tile_entry.contents[#tile_entry.contents + 1] = entity_id
    elseif ct == "bin" or ct == "stack_inventory" or ct == "item_inventory" or ct == "ground_pile" then
        container.contents[#container.contents + 1] = entity_id
    else
        error("deposit: unknown container_type: " .. tostring(ct))
    end

    addToCount(world.resource_counts[cat], e.type, entityAmount(e))
end

function resources.withdraw(container, type, amount)
    local ct  = container.container_type
    local cat = containerCategory(container)
    local result    = {}
    local remaining = amount

    if ct == "tile_inventory" then
        for _, tile_entry in pairs(container.tiles) do
            if remaining <= 0 then break end
            for i = #tile_entry.contents, 1, -1 do
                if remaining <= 0 then break end
                local eid = tile_entry.contents[i]
                local e   = registry[eid]
                if e.type == type then
                    if e.amount <= remaining then
                        remaining = remaining - e.amount
                        result[#result + 1] = eid
                        table.remove(tile_entry.contents, i)
                        addToCount(world.resource_counts[cat], type, -e.amount)
                    else
                        e.amount = e.amount - remaining
                        local split = registry.createEntity(world.stacks, { type = type, amount = remaining })
                        result[#result + 1] = split.id
                        addToCount(world.resource_counts[cat], type, -remaining)
                        remaining = 0
                    end
                end
            end
        end
    elseif ct == "bin" or ct == "stack_inventory" or ct == "ground_pile" then
        for i = #container.contents, 1, -1 do
            if remaining <= 0 then break end
            local eid = container.contents[i]
            local e   = registry[eid]
            if e.type == type then
                if e.amount ~= nil then
                    if e.amount <= remaining then
                        remaining = remaining - e.amount
                        result[#result + 1] = eid
                        table.remove(container.contents, i)
                        addToCount(world.resource_counts[cat], type, -e.amount)
                    else
                        e.amount = e.amount - remaining
                        local split = registry.createEntity(world.stacks, { type = type, amount = remaining })
                        result[#result + 1] = split.id
                        addToCount(world.resource_counts[cat], type, -remaining)
                        remaining = 0
                    end
                else
                    -- item
                    remaining = remaining - 1
                    result[#result + 1] = eid
                    table.remove(container.contents, i)
                    addToCount(world.resource_counts[cat], type, -1)
                end
            end
        end
    elseif ct == "item_inventory" then
        for i = #container.contents, 1, -1 do
            if remaining <= 0 then break end
            local eid = container.contents[i]
            local e   = registry[eid]
            if e.type == type then
                remaining = remaining - 1
                result[#result + 1] = eid
                table.remove(container.contents, i)
                addToCount(world.resource_counts[cat], type, -1)
            end
        end
    else
        error("withdraw: unknown container_type: " .. tostring(ct))
    end

    assert(remaining == 0, "withdraw: could not fulfill " .. amount .. " of " .. type)
    return result
end

function resources.transfer(source, destination, type, amount)
    local entity_ids = resources.withdraw(source, type, amount)
    for i = 1, #entity_ids do
        resources.deposit(destination, entity_ids[i])
    end
end

-- ── Carrying operations ───────────────────────────────────────────────────────

local function recalcMoveSpeed(unit)
    local weight       = resources.countWeight(unit.carrying)
    local weight_ratio = weight / CARRY_WEIGHT_MAX
    local strength     = 0
    if unit.base_attributes ~= nil then
        strength = (unit.base_attributes.strength or 0)
                 + (unit.acquired_attributes.strength or 0)
    end
    local slow_factor  = MAX_CARRY_SLOW * (1 - math.min(strength, 10) / 10)
    unit.move_speed = math.max(0, 1.0 - weight_ratio * slow_factor)
end

function resources.carryEntity(unit, entity_id)
    local e = registry[entity_id]
    assert(isStack(e), "carryEntity: entity is not a stack")

    if #unit.carrying == 0 then
        unit.carrying[1] = entity_id
    else
        local existing = registry[unit.carrying[1]]
        assert(existing.type == e.type, "carryEntity: carrying type mismatch")
        existing.amount = existing.amount + e.amount
        registry[entity_id] = nil
        local stacks = world.stacks
        for i = 1, #stacks do
            if stacks[i].id == entity_id then
                stacks[i] = stacks[#stacks]
                stacks[#stacks] = nil
                break
            end
        end
    end

    addToCount(world.resource_counts.carrying, e.type, e.amount)
    recalcMoveSpeed(unit)
end

function resources.carryResource(unit, type, amount)
    assert(ResourceConfig[type] ~= nil, "carryResource: unknown type " .. type)
    local new_weight = resources.countWeight(unit.carrying) + ResourceConfig[type].weight * amount
    assert(new_weight <= CARRY_WEIGHT_MAX, "carryResource: would exceed carry cap")

    if #unit.carrying == 0 then
        local stack = registry.createEntity(world.stacks, { type = type, amount = amount })
        unit.carrying[1] = stack.id
    else
        local existing = registry[unit.carrying[1]]
        assert(existing.type == type, "carryResource: carrying type mismatch")
        existing.amount = existing.amount + amount
    end

    addToCount(world.resource_counts.carrying, type, amount)
    recalcMoveSpeed(unit)
end

function resources.withdrawFromCarrying(unit, type, amount)
    local result    = {}
    local remaining = amount

    for i = #unit.carrying, 1, -1 do
        if remaining <= 0 then break end
        local eid = unit.carrying[i]
        local e   = registry[eid]
        if e.type == type then
            if e.amount <= remaining then
                remaining = remaining - e.amount
                result[#result + 1] = eid
                table.remove(unit.carrying, i)
                addToCount(world.resource_counts.carrying, type, -e.amount)
            else
                e.amount = e.amount - remaining
                local split = registry.createEntity(world.stacks, { type = type, amount = remaining })
                result[#result + 1] = split.id
                addToCount(world.resource_counts.carrying, type, -remaining)
                remaining = 0
            end
        end
    end

    assert(remaining == 0, "withdrawFromCarrying: not enough " .. type)
    recalcMoveSpeed(unit)
    return result
end

-- ── Equip operations ──────────────────────────────────────────────────────────

function resources.equip(unit, slot, item_id)
    local e = registry[item_id]
    unit.equipped[slot] = item_id
    addToCount(world.resource_counts.equipped, e.type, 1)
end

function resources.unequip(unit, slot)
    local item_id = unit.equipped[slot]
    if item_id == nil then return nil end
    local e = registry[item_id]
    unit.equipped[slot] = nil
    addToCount(world.resource_counts.equipped, e.type, -1)
    return item_id
end

-- ── Reservation operations ────────────────────────────────────────────────────

-- amount for "out" is in item amounts; amount for "in" is in weight units.
function resources.reserve(container, type, amount, direction)
    local ct = container.container_type
    if ct == "tile_inventory" then
        if direction == "out" then
            local idx = tileForReserveOut(container, type, amount)
            assert(idx ~= nil, "reserve out: no tile with " .. amount .. " available " .. type)
            container.tiles[idx].reserved_out = container.tiles[idx].reserved_out + amount
            addToCount(world.resource_counts.storage_reserved, type, amount)
        else
            local idx = tileForReserveIn(container, type, amount)
            assert(idx ~= nil, "reserve in: no tile with capacity for " .. type)
            container.tiles[idx].reserved_in = container.tiles[idx].reserved_in + amount
        end
    elseif ct == "stack_inventory" or ct == "item_inventory" then
        if direction == "out" then
            container.reserved_out = container.reserved_out + amount
            addToCount(world.resource_counts.storage_reserved, type, amount)
        else
            container.reserved_in = container.reserved_in + amount
        end
    elseif ct == "bin" then
        if direction == "out" then
            container.reserved_out = container.reserved_out + amount
        else
            container.reserved_in = container.reserved_in + amount
        end
    elseif ct == "ground_pile" then
        assert(direction == "out", "reserve: ground_pile only supports out")
        container.reserved_out = container.reserved_out + amount
    else
        error("reserve: unknown container_type: " .. tostring(ct))
    end
end

function resources.releaseReservation(container, type, amount, direction)
    local ct = container.container_type
    if ct == "tile_inventory" then
        if direction == "out" then
            local released = 0
            for _, tile_entry in pairs(container.tiles) do
                if released >= amount then break end
                if tile_entry.reserved_out > 0 and tileHasType(tile_entry, type) then
                    local rel = math.min(amount - released, tile_entry.reserved_out)
                    tile_entry.reserved_out = tile_entry.reserved_out - rel
                    released = released + rel
                end
            end
            addToCount(world.resource_counts.storage_reserved, type, -released)
        else
            local released = 0
            for _, tile_entry in pairs(container.tiles) do
                if released >= amount then break end
                if tile_entry.reserved_in > 0 then
                    local rel = math.min(amount - released, tile_entry.reserved_in)
                    tile_entry.reserved_in = tile_entry.reserved_in - rel
                    released = released + rel
                end
            end
        end
    elseif ct == "stack_inventory" or ct == "item_inventory" then
        if direction == "out" then
            container.reserved_out = container.reserved_out - amount
            addToCount(world.resource_counts.storage_reserved, type, -amount)
        else
            container.reserved_in = container.reserved_in - amount
        end
    elseif ct == "bin" then
        if direction == "out" then
            container.reserved_out = container.reserved_out - amount
        else
            container.reserved_in = container.reserved_in - amount
        end
    elseif ct == "ground_pile" then
        container.reserved_out = container.reserved_out - amount
    else
        error("releaseReservation: unknown container_type: " .. tostring(ct))
    end
end

-- ── Lifecycle operations ──────────────────────────────────────────────────────

function resources.create(type, amount)
    local rc = ResourceConfig[type]
    assert(rc ~= nil, "create: unknown resource type " .. tostring(type))
    if rc.is_stackable then
        local stack = registry.createEntity(world.stacks, { type = type, amount = amount })
        return stack.id
    else
        local ids = {}
        for i = 1, amount do
            local item = registry.createEntity(world.items, {
                type       = type,
                durability = rc.max_durability,
            })
            ids[i] = item.id
        end
        return ids
    end
end

function resources.destroy(entity_id)
    local e = registry[entity_id]
    registry[entity_id] = nil
    local collection = isStack(e) and world.stacks or world.items
    for i = 1, #collection do
        if collection[i].id == entity_id then
            collection[i] = collection[#collection]
            collection[#collection] = nil
            return
        end
    end
end

-- ── Count operations ──────────────────────────────────────────────────────────

function resources.rebuildCounts()
    local rc = world.resource_counts
    rc.storage          = {}
    rc.storage_reserved = {}
    rc.processing       = {}
    rc.housing          = {}
    rc.carrying         = {}
    rc.equipped         = {}
    rc.ground           = {}

    for i = 1, #world.buildings do
        local b = world.buildings[i]
        if b.storage ~= nil then
            local ct = b.storage.container_type
            if ct == "tile_inventory" then
                for _, tile_entry in pairs(b.storage.tiles) do
                    for j = 1, #tile_entry.contents do
                        local e = registry[tile_entry.contents[j]]
                        addToCount(rc.storage, e.type, entityAmount(e))
                    end
                    -- Attribute reserved_out to the type on this tile
                    if tile_entry.reserved_out > 0 then
                        for j = 1, #tile_entry.contents do
                            local e = registry[tile_entry.contents[j]]
                            addToCount(rc.storage_reserved, e.type, tile_entry.reserved_out)
                            break
                        end
                    end
                end
            elseif ct == "stack_inventory" then
                for j = 1, #b.storage.contents do
                    local e = registry[b.storage.contents[j]]
                    addToCount(rc.storage, e.type, e.amount)
                end
                if b.storage.reserved_out > 0 then
                    -- Can't attribute to a type without scanning contents — skip
                end
            elseif ct == "item_inventory" then
                for j = 1, #b.storage.contents do
                    local e = registry[b.storage.contents[j]]
                    addToCount(rc.storage, e.type, 1)
                end
            end
        end
        if b.housing ~= nil then
            for _, bin in ipairs(b.housing.bins) do
                for j = 1, #bin.contents do
                    local e = registry[bin.contents[j]]
                    addToCount(rc.housing, e.type, entityAmount(e))
                end
            end
        end
        if b.production ~= nil and b.production.input_bins ~= nil then
            for _, bin in ipairs(b.production.input_bins) do
                for j = 1, #bin.contents do
                    local e = registry[bin.contents[j]]
                    addToCount(rc.processing, e.type, entityAmount(e))
                end
            end
        end
    end

    for i = 1, #world.ground_piles do
        local gp = world.ground_piles[i]
        for j = 1, #gp.contents do
            local e = registry[gp.contents[j]]
            addToCount(rc.ground, e.type, entityAmount(e))
        end
    end

    for i = 1, #world.units do
        local u = world.units[i]
        if u.is_dead == false then
            for j = 1, #u.carrying do
                local e = registry[u.carrying[j]]
                addToCount(rc.carrying, e.type, entityAmount(e))
            end
            if u.equipped ~= nil then
                for slot, item_id in pairs(u.equipped) do
                    if item_id ~= nil then
                        local e = registry[item_id]
                        addToCount(rc.equipped, e.type, 1)
                    end
                end
            end
        end
    end
end

function resources.validateCounts()
    local saved = table.deepCopy(world.resource_counts)
    resources.rebuildCounts()

    local function assertMatch(cat)
        local s = saved[cat]
        local f = world.resource_counts[cat]
        for type, amount in pairs(s) do
            assert((f[type] or 0) == amount,
                "validateCounts: " .. cat .. "[" .. type .. "] mismatch: saved=" .. amount .. " rebuilt=" .. (f[type] or 0))
        end
        for type, amount in pairs(f) do
            assert((s[type] or 0) == amount,
                "validateCounts: " .. cat .. "[" .. type .. "] mismatch: saved=" .. (s[type] or 0) .. " rebuilt=" .. amount)
        end
    end

    assertMatch("storage")
    assertMatch("storage_reserved")
    assertMatch("carrying")
    assertMatch("ground")
    assertMatch("housing")
    assertMatch("processing")
    assertMatch("equipped")
end

function resources.findNearestStorage(unit, type)
    local best_dist     = nil
    local best_building = nil
    for i = 1, #world.buildings do
        local b = world.buildings[i]
        if b.is_deleted == false and b.storage ~= nil then
            if resources.getAvailableCapacity(b.storage, type) > 0 then
                local dist = math.abs(unit.x - b.x) + math.abs(unit.y - b.y)
                if best_dist == nil or dist < best_dist then
                    best_dist     = dist
                    best_building = b
                end
            end
        end
    end
    return best_building
end

return resources
