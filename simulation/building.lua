-- simulation/building.lua
-- Building factory and worker management. Three work patterns stubbed as
-- state machine hooks: hub gathering, stationary extraction, production crafting.

local registry = require("core.registry")
local world    = require("core.world")
local log      = require("core.log")

--- Deep-copy a table (one level of nesting — sufficient for interior/hauling_rules).
local function copyTable(t)
    if t == nil then return nil end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = type(v) == "table" and copyTable(v) or v
    end
    return copy
end

--- Initialise an inventory from a config spec.
local function initInventory(spec)
    local slots = {}
    for i = 1, spec.slot_count do
        slots[i] = { resource = nil, amount = 0 }
    end
    return {
        slots         = slots,
        slot_capacity = spec.slot_capacity,
        filters       = {},
    }
end

local building = {}

--- Create a building, insert into registry and world.buildings, and return it.
--- params: { type, x, y, crop, worker_limit }
function building:create(params)
    local cfg = BuildingConfig[params.type]
    assert(cfg, "building:create: unknown type '" .. tostring(params.type) .. "'")

    local b = {
        id   = registry:nextId(),
        type = params.type,
        x    = params.x or 0,
        y    = params.y or 0,
        width  = cfg.width  or 1,
        height = cfg.height or 1,

        is_built       = false,
        build_progress = 0,

        interior = copyTable(cfg.interior) or {},
        crop     = params.crop,

        worker_ids   = {},
        worker_limit = params.worker_limit or (cfg.max_workers or 1),

        input  = cfg.input  and initInventory(cfg.input)  or nil,
        output = cfg.output and initInventory(cfg.output) or nil,

        hauling_rules    = copyTable(cfg.default_hauling_rules),
        work_in_progress = nil,
    }

    registry:insert(b)
    table.insert(world.buildings, b)
    log:info("WORLD", "placed %s (id=%d) at (%d,%d)", b.type, b.id, b.x, b.y)
    return b
end

--- Assign a worker to a building. Returns true on success, false if at capacity.
function building:assignWorker(b, unit_id)
    if #b.worker_ids >= b.worker_limit then return false end
    table.insert(b.worker_ids, unit_id)
    return true
end

--- Remove a worker from a building (swap-and-pop).
function building:removeWorker(b, unit_id)
    for i = 1, #b.worker_ids do
        if b.worker_ids[i] == unit_id then
            b.worker_ids[i] = b.worker_ids[#b.worker_ids]
            b.worker_ids[#b.worker_ids] = nil
            return
        end
    end
end

--- Hub gathering: workers go out to gather resources and return to this building.
--- (woodcutters_camp, gatherers_hut, hunting_cabin, fishing_dock)
function building:tickHubGathering(b, time)
    -- Phase 11: post chop_tree/gather/hunt/fish jobs for idle workers
end

--- Stationary extraction: workers produce resources on-site.
--- (mine, quarry)
function building:tickExtraction(b, time)
    -- Phase 11: post mining/quarrying jobs for idle workers
end

--- Production crafting: workers fetch input resources, craft, produce output.
--- (mill, bakery, brewery, smithy, foundry, etc.)
function building:tickProduction(b, time)
    -- Phase 11: post fetch and craft jobs; advance work_in_progress
end

return building
