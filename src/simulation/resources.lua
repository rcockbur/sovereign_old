-- simulation/resources.lua
-- Resource entity lifecycle, container operations, reservation system, and running tallies.
-- Sole owner of all resource mutations — no other module writes to container contents,
-- reservation fields, or world.resource_counts.
--
-- Reservation units:
--   reserved_out  — item amounts  (matches stock formula: available = stock - reserved_out)
--   reserved_in   — item amounts  (getAvailableCapacity converts weight capacity to count internally)

local world    = require("core.world")
local registry = require("core.registry")

local resources = {}

-- ── Internal helpers ──────────────────────────────────────────────────────────

local function addToCount(tally, type, delta)
    tally[type] = (tally[type] or 0) + delta
    if tally[type] == 0 then
        tally[type] = nil
    end
end

local function isStack(entity)
    return entity.amount ~= nil
end

local function entityAmount(entity)
    return isStack(entity) and entity.amount or 1
end

local function entityWeight(entity_id)
    local entity = registry[entity_id]
    return ResourceConfig[entity.type].weight * entityAmount(entity)
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
        return container.count_category
    end
    error("unknown container_type: " .. tostring(ct))
end

-- ── Tile inventory: internal tile selection ───────────────────────────────────

local function tileHasType(tile_entry, type)
    for i = 1, #tile_entry.contents do
        local entity = registry[tile_entry.contents[i]]
        if entity.type == type then
            return true
        end
    end
    return false
end

local function tileHasOther(tile_entry, type)
    for i = 1, #tile_entry.contents do
        local entity = registry[tile_entry.contents[i]]
        if entity.type ~= type then
            return true
        end
    end
    return false
end

local function tileStockOfType(tile_entry, type)
    local n = 0
    for i = 1, #tile_entry.contents do
        local entity = registry[tile_entry.contents[i]]
        if entity.type == type then
            n = n + entityAmount(entity)
        end
    end
    return n
end

-- local function tileForDeposit(container, type, entity_weight)
--     local best_same_idx  = nil
--     local best_empty_idx = nil
--     for idx, tile_entry in ipairs(container.tiles) do
--         local used       = tileUsedWeight(tile_entry)
--         local phys_avail = container.tile_capacity - used
--         if phys_avail >= entity_weight then
--             local has_type  = tileHasType(tile_entry, type)
--             local has_other = tileHasOther(tile_entry, type)
--             if has_type and not has_other then
--                 if best_same_idx == nil then
--                     best_same_idx = idx
--                 end
--             elseif not has_type and not has_other then
--                 if best_empty_idx == nil then
--                     best_empty_idx = idx
--                 end
--             end
--         end
--     end
--     return best_same_idx or best_empty_idx
-- end

local function tileForDeposit(container, type)
    local best_empty_idx = nil
    for i = 1, #container.tiles do
        local tile_entry = container.tiles[i]
         if tileHasType(tile_entry, type) and container.tile_capacity > tileUsedWeight(tile_entry) then
            return i
        elseif #tile_entry.contents == 0 then
            if best_empty_idx == nil then
                best_empty_idx = i
            end
        end
    end
    return best_empty_idx
end

local function tileForWithdraw(container, type)
    for idx, tile_entry in ipairs(container.tiles) do
        if tileHasType(tile_entry, type) then
            return idx, tile_entry
        end
    end
    return nil, nil
end


-- ── Query operations ──────────────────────────────────────────────────────────

function resources.getStock(container, type)
    local ct = container.container_type
    if ct == "tile_inventory" then
        local total = 0
        for _, tile_entry in ipairs(container.tiles) do
            total = total + tileStockOfType(tile_entry, type)
        end
        return total
    elseif ct == "bin" or ct == "stack_inventory" or ct == "item_inventory" or ct == "ground_pile" then
        local total = 0
        for i = 1, #container.contents do
            local entity = registry[container.contents[i]]
            if entity.type == type then
                total = total + entityAmount(entity)
            end
        end
        return total
    end
    error("getStock: unknown container_type: " .. tostring(ct))
end

function resources.getAvailableStock(container, type)
    local ct = container.container_type
    if ct == "tile_inventory" then
        local total = 0
        for _, tile_entry in ipairs(container.tiles) do
            total = total + tileStockOfType(tile_entry, type)
        end
        return math.max(0, total - (container.reserved_out[type] or 0))
    elseif ct == "bin" then
        return resources.getStock(container, type) - container.reserved_out
    else
        return math.max(0, resources.getStock(container, type) - (container.reserved_out[type] or 0))
    end
end

function resources.getAvailableCapacity(container, type)
    local ct = container.container_type
    if ct == "tile_inventory" then
        local weight   = ResourceConfig[type].weight
        local physical = 0
        for _, tile_entry in ipairs(container.tiles) do
            if not tileHasOther(tile_entry, type) then
                local used = tileUsedWeight(tile_entry)
                physical = physical + math.max(0, container.tile_capacity - used)
            end
        end
        local count = math.max(0, math.floor(physical / weight) - (container.reserved_in[type] or 0))
        local filter = container.filters[type]
        if filter ~= nil and filter.limit ~= nil then
            local current     = resources.getStock(container, type)
            local limit_avail = math.max(0, filter.limit - current)
            count = math.min(count, limit_avail)
        end
        return count
    elseif ct == "bin" then
        local weight = ResourceConfig[type].weight
        local used = 0
        for i = 1, #container.contents do
            used = used + entityWeight(container.contents[i])
        end
        return math.max(0, math.floor((container.capacity - used) / weight) - container.reserved_in)
    elseif ct == "stack_inventory" then
        local weight = ResourceConfig[type].weight
        local used = 0
        for i = 1, #container.contents do
            used = used + entityWeight(container.contents[i])
        end
        local count = math.max(0, math.floor((container.capacity - used) / weight) - (container.reserved_in[type] or 0))
        local filter = container.filters[type]
        if filter ~= nil and filter.limit ~= nil then
            local current     = resources.getStock(container, type)
            local limit_avail = math.max(0, filter.limit - current)
            count = math.min(count, limit_avail)
        end
        return count
    elseif ct == "item_inventory" then
        local total_reserved_in = 0
        for _, v in pairs(container.reserved_in) do total_reserved_in = total_reserved_in + v end
        return math.max(0, container.item_capacity - #container.contents - total_reserved_in)
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
    local entity          = registry[entity_id]
    local ct              = container.container_type
    local cat             = containerCategory(container)
    local deposited_amount = entityAmount(entity)

    if ct == "tile_inventory" then
        assert(deposited_amount <= (container.reserved_in[entity.type] or 0), "deposit: no reservation for " .. deposited_amount .. " of " .. entity.type)
        local more_to_be_added = true
        while more_to_be_added do
            local idx = tileForDeposit(container, entity.type)
            assert(idx ~= nil, "deposit: no tile available for type " .. entity.type)
            local tile_entry = container.tiles[idx]
            if #tile_entry.contents == 0 then
                tile_entry.contents[1] = entity_id
                more_to_be_added = false
            else
                local weight = ResourceConfig[entity.type].weight
                local available_space = (container.tile_capacity - tileUsedWeight(tile_entry)) / weight
                local deposit_amount = math.min(available_space, entity.amount)
                local existing = registry[tile_entry.contents[1]]
                existing.amount = existing.amount + deposit_amount
                entity.amount = entity.amount - deposit_amount
                if entity.amount == 0 then
                    resources.destroy(entity_id)
                    more_to_be_added = false
                end
            end
        end
        container.reserved_in[entity.type] = container.reserved_in[entity.type] - deposited_amount
        if container.reserved_in[entity.type] == 0 then container.reserved_in[entity.type] = nil end
    elseif ct == "bin" then
        assert(container.reserved_in >= deposited_amount,
            "deposit: no bin reservation for " .. deposited_amount .. " of " .. entity.type)
        container.contents[#container.contents + 1] = entity_id
        container.reserved_in = container.reserved_in - deposited_amount
    elseif ct == "stack_inventory" then
        assert((container.reserved_in[entity.type] or 0) >= deposited_amount,
            "deposit: no stack_inventory reservation for " .. deposited_amount .. " of " .. entity.type)
        container.contents[#container.contents + 1] = entity_id
        container.reserved_in[entity.type] = (container.reserved_in[entity.type] or 0) - deposited_amount
        if container.reserved_in[entity.type] == 0 then container.reserved_in[entity.type] = nil end
    elseif ct == "item_inventory" then
        assert((container.reserved_in[entity.type] or 0) >= 1,
            "deposit: no item_inventory reservation for " .. entity.type)
        container.contents[#container.contents + 1] = entity_id
        container.reserved_in[entity.type] = (container.reserved_in[entity.type] or 0) - 1
        if container.reserved_in[entity.type] == 0 then container.reserved_in[entity.type] = nil end
    elseif ct == "ground_pile" then
        container.contents[#container.contents + 1] = entity_id
    else
        error("deposit: unknown container_type: " .. tostring(ct))
    end

    addToCount(world.resource_counts[cat], entity.type, deposited_amount)
end

function resources.withdraw(container, type, amount)
    local ct  = container.container_type
    local cat = containerCategory(container)
    local result    = {}
    local remaining = amount

    if ct == "tile_inventory" then
        for _, tile_entry in ipairs(container.tiles) do
            if remaining <= 0 then
                break
            end
            for i = #tile_entry.contents, 1, -1 do
                if remaining <= 0 then
                    break
                end
                local eid    = tile_entry.contents[i]
                local entity = registry[eid]
                if entity.type == type then
                    if entity.amount <= remaining then
                        remaining = remaining - entity.amount
                        result[#result + 1] = eid
                        table.remove(tile_entry.contents, i)
                        addToCount(world.resource_counts[cat], type, -entity.amount)
                    else
                        entity.amount = entity.amount - remaining
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
            if remaining <= 0 then
                break
            end
            local eid    = container.contents[i]
            local entity = registry[eid]
            if entity.type == type then
                if entity.amount ~= nil then
                    if entity.amount <= remaining then
                        remaining = remaining - entity.amount
                        result[#result + 1] = eid
                        table.remove(container.contents, i)
                        addToCount(world.resource_counts[cat], type, -entity.amount)
                    else
                        entity.amount = entity.amount - remaining
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
            if remaining <= 0 then
                break
            end
            local eid    = container.contents[i]
            local entity = registry[eid]
            if entity.type == type then
                remaining = remaining - 1
                result[#result + 1] = eid
                table.remove(container.contents, i)
                addToCount(world.resource_counts[cat], type, -1)
            end
        end
    else
        error("withdraw: unknown container_type: " .. tostring(ct))
    end

    if ct == "tile_inventory" or ct == "stack_inventory" or ct == "item_inventory" then
        local ro = container.reserved_out[type] or 0
        assert(ro >= amount, "withdraw: no out-reservation for " .. amount .. " of " .. type)
        container.reserved_out[type] = ro - amount
        if container.reserved_out[type] == 0 then container.reserved_out[type] = nil end
        addToCount(world.resource_counts.storage_reserved, type, -amount)
    elseif ct == "bin" then
        assert(container.reserved_out >= amount,
            "withdraw: no bin out-reservation for " .. amount .. " of " .. type)
        container.reserved_out = container.reserved_out - amount
    elseif ct == "ground_pile" then
        local ro = container.reserved_out[type] or 0
        assert(ro >= amount, "withdraw: no ground_pile out-reservation for " .. amount .. " of " .. type)
        container.reserved_out[type] = ro - amount
        if container.reserved_out[type] == 0 then container.reserved_out[type] = nil end
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
    local entity = registry[entity_id]
    assert(isStack(entity), "carryEntity: entity is not a stack")

    if #unit.carrying == 0 then
        unit.carrying[1] = entity_id
    else
        local existing = registry[unit.carrying[1]]
        assert(existing.type == entity.type, "carryEntity: carrying type mismatch")
        existing.amount = existing.amount + entity.amount
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

    addToCount(world.resource_counts.carrying, entity.type, entity.amount)
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
        if remaining <= 0 then
            break
        end
        local eid    = unit.carrying[i]
        local entity = registry[eid]
        if entity.type == type then
            if entity.amount <= remaining then
                remaining = remaining - entity.amount
                result[#result + 1] = eid
                table.remove(unit.carrying, i)
                addToCount(world.resource_counts.carrying, type, -entity.amount)
            else
                entity.amount = entity.amount - remaining
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
    local entity = registry[item_id]
    unit.equipped[slot] = item_id
    addToCount(world.resource_counts.equipped, entity.type, 1)
end

function resources.unequip(unit, slot)
    local item_id = unit.equipped[slot]
    if item_id == nil then
        return nil
    end
    local entity = registry[item_id]
    unit.equipped[slot] = nil
    addToCount(world.resource_counts.equipped, entity.type, -1)
    return item_id
end

-- ── Reservation operations ────────────────────────────────────────────────────

-- amount for "out" and "in" are both in item amounts.
function resources.reserve(container, type, amount, direction)
    local ct = container.container_type
    if direction == "in" then
        assert(amount <= resources.getAvailableCapacity(container, type),
            "reserve in: insufficient capacity for " .. amount .. " of " .. type)
    else
        assert(amount <= resources.getAvailableStock(container, type),
            "reserve out: insufficient stock for " .. amount .. " of " .. type)
    end

    if ct == "tile_inventory" or ct == "stack_inventory" or ct == "item_inventory" then
        if direction == "out" then
            container.reserved_out[type] = (container.reserved_out[type] or 0) + amount
            addToCount(world.resource_counts.storage_reserved, type, amount)
        else
            container.reserved_in[type] = (container.reserved_in[type] or 0) + amount
        end
    elseif ct == "bin" then
        if direction == "out" then
            container.reserved_out = container.reserved_out + amount
        else
            container.reserved_in = container.reserved_in + amount
        end
    elseif ct == "ground_pile" then
        assert(direction == "out", "reserve: ground_pile only supports out")
        container.reserved_out[type] = (container.reserved_out[type] or 0) + amount
    else
        error("reserve: unknown container_type: " .. tostring(ct))
    end
end

function resources.releaseReservation(container, type, amount, direction)
    local ct = container.container_type
    if ct == "tile_inventory" or ct == "stack_inventory" or ct == "item_inventory" then
        if direction == "out" then
            local new_val = (container.reserved_out[type] or 0) - amount
            assert(new_val >= 0, "releaseReservation: over-release of reserved_out for " .. type)
            container.reserved_out[type] = new_val > 0 and new_val or nil
            addToCount(world.resource_counts.storage_reserved, type, -amount)
        else
            local new_val = (container.reserved_in[type] or 0) - amount
            assert(new_val >= 0, "releaseReservation: over-release of reserved_in for " .. type)
            container.reserved_in[type] = new_val > 0 and new_val or nil
        end
    elseif ct == "bin" then
        if direction == "out" then
            container.reserved_out = container.reserved_out - amount
            assert(container.reserved_out >= 0, "releaseReservation: over-release of bin reserved_out")
        else
            container.reserved_in = container.reserved_in - amount
            assert(container.reserved_in >= 0, "releaseReservation: over-release of bin reserved_in")
        end
    elseif ct == "ground_pile" then
        local new_val = (container.reserved_out[type] or 0) - amount
        assert(new_val >= 0, "releaseReservation: over-release of ground_pile reserved_out for " .. type)
        container.reserved_out[type] = new_val > 0 and new_val or nil
    else
        error("releaseReservation: unknown container_type: " .. tostring(ct))
    end
end

-- ── Ground pile operations ───────────────────────────────────────────────────

local GROUND_DIRS = { {0,-1}, {0,1}, {-1,0}, {1,0} }

function resources.createGroundPile(x, y)
    local gp = registry.createEntity(world.ground_piles, {
        container_type = "ground_pile",
        count_category = "ground",
        x = x, y = y,
        contents     = {},
        reserved_out = {},
    })
    world.tiles[tileIndex(x, y)].ground_pile_id = gp.id
    return gp
end

function resources.destroyGroundPile(gp)
    world.tiles[tileIndex(gp.x, gp.y)].ground_pile_id = nil
    registry[gp.id] = nil
    for i = 1, #world.ground_piles do
        if world.ground_piles[i].id == gp.id then
            world.ground_piles[i] = world.ground_piles[#world.ground_piles]
            world.ground_piles[#world.ground_piles] = nil
            return
        end
    end
end

-- BFS from (from_x, from_y) within GROUND_DROP_SEARCH_RADIUS to find:
--   1. Same-type pile below GROUND_PILE_PREFERRED_CAPACITY
--   2. First empty pathable non-start tile
--   3. Fallback: start tile
-- Deposits entity_ids into the chosen pile (creating one if needed), returns pile.
local function dropEntitiesToGround(entity_ids, rtype, from_x, from_y)
    local start_idx = tileIndex(from_x, from_y)
    local best_merge_idx = nil
    local best_empty_idx = nil

    local queue   = { { start_idx, 0 } }
    local head    = 1
    local visited = { [start_idx] = true }

    while head <= #queue do
        local entry = queue[head]; head = head + 1
        local cur, depth = entry[1], entry[2]
        local tile = world.tiles[cur]

        if tile.ground_pile_id ~= nil then
            if best_merge_idx == nil then
                local gp = registry[tile.ground_pile_id]
                if resources.getStock(gp, rtype) > 0 then
                    local w = 0
                    for i = 1, #gp.contents do w = w + entityWeight(gp.contents[i]) end
                    if w < GROUND_PILE_PREFERRED_CAPACITY then
                        best_merge_idx = cur
                    end
                end
            end
        elseif best_empty_idx == nil and cur ~= start_idx then
            best_empty_idx = cur
        end

        if depth < GROUND_DROP_SEARCH_RADIUS then
            local cx, cy = tileXY(cur)
            for _, d in ipairs(GROUND_DIRS) do
                local nx, ny = cx + d[1], cy + d[2]
                if nx >= 1 and nx <= MAP_WIDTH and ny >= 1 and ny <= MAP_HEIGHT then
                    local nidx = tileIndex(nx, ny)
                    if visited[nidx] == nil and world.getTileCost(world.tiles[nidx]) ~= nil then
                        visited[nidx] = true
                        queue[#queue + 1] = { nidx, depth + 1 }
                    end
                end
            end
        end
    end

    local target_idx = best_merge_idx or best_empty_idx or start_idx
    local tx, ty     = tileXY(target_idx)
    local target_tile = world.tiles[target_idx]

    local gp
    if target_tile.ground_pile_id ~= nil then
        gp = registry[target_tile.ground_pile_id]
    else
        gp = resources.createGroundPile(tx, ty)
    end

    for i = 1, #entity_ids do
        resources.deposit(gp, entity_ids[i])
    end
    return gp
end

-- Drops all resources carried by unit to the ground near their position.
-- Returns the ground pile, or nil if unit was not carrying anything.
function resources.groundDrop(unit)
    if #unit.carrying == 0 then
        return nil
    end
    local stack  = registry[unit.carrying[1]]
    local rtype  = stack.type
    local amount = stack.amount
    local ids    = resources.withdrawFromCarrying(unit, rtype, amount)
    return dropEntitiesToGround(ids, rtype, unit.x, unit.y)
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
    local entity = registry[entity_id]
    registry[entity_id] = nil
    local collection = isStack(entity) and world.stacks or world.items
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
    rc.construction     = {}
    rc.carrying         = {}
    rc.equipped         = {}
    rc.ground           = {}

    for i = 1, #world.buildings do
        local building = world.buildings[i]
        if building.storage ~= nil then
            local ct = building.storage.container_type
            if ct == "tile_inventory" then
                for _, tile_entry in ipairs(building.storage.tiles) do
                    for j = 1, #tile_entry.contents do
                        local entity = registry[tile_entry.contents[j]]
                        addToCount(rc.storage, entity.type, entityAmount(entity))
                    end
                end
                for rtype, amt in pairs(building.storage.reserved_out) do
                    addToCount(rc.storage_reserved, rtype, amt)
                end
            elseif ct == "stack_inventory" then
                for j = 1, #building.storage.contents do
                    local entity = registry[building.storage.contents[j]]
                    addToCount(rc.storage, entity.type, entity.amount)
                end
                for rtype, amt in pairs(building.storage.reserved_out) do
                    addToCount(rc.storage_reserved, rtype, amt)
                end
            elseif ct == "item_inventory" then
                for j = 1, #building.storage.contents do
                    local entity = registry[building.storage.contents[j]]
                    addToCount(rc.storage, entity.type, 1)
                end
                for rtype, amt in pairs(building.storage.reserved_out) do
                    addToCount(rc.storage_reserved, rtype, amt)
                end
            end
        end
        if building.housing ~= nil then
            for _, bin in ipairs(building.housing.bins) do
                for j = 1, #bin.contents do
                    local entity = registry[bin.contents[j]]
                    addToCount(rc.housing, entity.type, entityAmount(entity))
                end
            end
        end
        if building.production ~= nil and building.production.input_bins ~= nil then
            for _, bin in ipairs(building.production.input_bins) do
                for j = 1, #bin.contents do
                    local entity = registry[bin.contents[j]]
                    addToCount(rc.processing, entity.type, entityAmount(entity))
                end
            end
        end
    end

    for i = 1, #world.ground_piles do
        local gp = world.ground_piles[i]
        for j = 1, #gp.contents do
            local entity = registry[gp.contents[j]]
            addToCount(rc.ground, entity.type, entityAmount(entity))
        end
    end

    for i = 1, #world.units do
        local unit = world.units[i]
        if unit.is_dead == false then
            for j = 1, #unit.carrying do
                local entity = registry[unit.carrying[j]]
                addToCount(rc.carrying, entity.type, entityAmount(entity))
            end
            if unit.equipped ~= nil then
                for slot, item_id in pairs(unit.equipped) do
                    if item_id ~= nil then
                        local entity = registry[item_id]
                        addToCount(rc.equipped, entity.type, 1)
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
        local saved_counts = saved[cat]
        local fresh_counts = world.resource_counts[cat]
        for type, amount in pairs(saved_counts) do
            assert((fresh_counts[type] or 0) == amount,
                "validateCounts: " .. cat .. "[" .. type .. "] mismatch: saved=" .. amount .. " rebuilt=" .. (fresh_counts[type] or 0))
        end
        for type, amount in pairs(fresh_counts) do
            assert((saved_counts[type] or 0) == amount,
                "validateCounts: " .. cat .. "[" .. type .. "] mismatch: saved=" .. (saved_counts[type] or 0) .. " rebuilt=" .. amount)
        end
    end

    assertMatch("storage")
    assertMatch("storage_reserved")
    assertMatch("carrying")
    assertMatch("ground")
    assertMatch("housing")
    assertMatch("processing")
    assertMatch("construction")
    assertMatch("equipped")
end

function resources.findNearestStorage(unit, type, min_capacity)
    min_capacity = min_capacity or 1
    local best_dist     = nil
    local best_building = nil
    for i = 1, #world.buildings do
        local building = world.buildings[i]
        if building.is_deleted == false and building.storage ~= nil then
            if resources.getAvailableCapacity(building.storage, type) >= min_capacity then
                local dist = math.abs(unit.x - building.x) + math.abs(unit.y - building.y)
                if best_dist == nil or dist < best_dist then
                    best_dist     = dist
                    best_building = building
                end
            end
        end
    end
    return best_building
end

return resources
