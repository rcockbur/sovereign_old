-- tests/test_resources.lua
-- Run with: lua tests/run.lua (from repo root)

require("config.constants")
require("config.tables")

local world     = require("core.world")
local registry  = require("core.registry")
local resources = require("simulation.resources")

-- ── Test helpers ──────────────────────────────────────────────────────────────

local function resetState()
    world.stacks        = {}
    world.items         = {}
    world.buildings     = {}
    world.ground_piles  = {}
    world.units         = {}
    world.resource_counts = {
        storage          = {},
        storage_reserved = {},
        processing       = {},
        housing          = {},
        carrying         = {},
        equipped         = {},
        ground           = {},
    }
    -- Clear registry entity entries, reset id counter
    registry.next_id = 0
    for k, _ in pairs(registry) do
        if type(k) == "number" then registry[k] = nil end
    end
end

local function makeStockpile(tile_count)
    -- Build a minimal stockpile with tile_count tiles keyed 1..tile_count
    local tiles = {}
    for i = 1, tile_count do
        tiles[i] = { contents = {}, reserved_in = 0, reserved_out = 0 }
    end
    local filters = {}
    for type_name, _ in pairs(ResourceConfig) do
        filters[type_name] = { mode = "accept", limit = nil }
    end
    local storage = {
        container_type = "tile_inventory",
        tile_capacity  = STOCKPILE_TILE_CAPACITY,
        filters        = filters,
        tiles          = tiles,
    }
    local b = registry.createEntity(world.buildings, {
        type     = "stockpile",
        category = "storage",
        x = 1, y = 1,
        width = tile_count, height = 1,
        phase      = "complete",
        is_deleted = false,
        posted_activity_ids = {},
        storage    = storage,
    })
    return b
end

-- ── Tests ─────────────────────────────────────────────────────────────────────

local function test_depositToStockpile()
    resetState()
    local b  = makeStockpile(4)
    local id = resources.create("wood", 8)
    resources.deposit(b.storage, id)

    local stock = resources.getStock(b.storage, "wood")
    assert(stock == 8, "stock should be 8 after deposit, got " .. stock)
    assert((world.resource_counts.storage["wood"] or 0) == 8,
        "resource_counts.storage[wood] should be 8")
end

local function test_partialWithdraw()
    resetState()
    local b  = makeStockpile(4)
    local id = resources.create("wood", 10)
    resources.deposit(b.storage, id)

    local ids = resources.withdraw(b.storage, "wood", 3)
    assert(#ids == 1, "withdraw should return 1 entity id")
    local split = registry[ids[1]]
    assert(split ~= nil, "split stack should exist in registry")
    assert(split.amount == 3, "split stack amount should be 3, got " .. split.amount)

    local remaining = resources.getStock(b.storage, "wood")
    assert(remaining == 7, "remaining stock should be 7, got " .. remaining)
    assert((world.resource_counts.storage["wood"] or 0) == 7,
        "resource_counts.storage[wood] should be 7 after partial withdraw")
end

local function test_capacityEnforcement()
    resetState()
    -- STOCKPILE_TILE_CAPACITY = 64 weight; wood weight = 4
    -- 1 tile holds 16 wood (64 weight); 2 tiles → 32 wood total
    -- Deposit one full tile worth per stack so each stack fits exactly.
    local b = makeStockpile(2)
    resources.deposit(b.storage, resources.create("wood", 16))
    resources.deposit(b.storage, resources.create("wood", 16))

    local avail = resources.getAvailableCapacity(b.storage, "wood")
    assert(avail == 0, "available capacity should be 0 when both tiles full, got " .. avail)

    -- Withdraw 8 wood → frees 32 weight on one tile
    resources.withdraw(b.storage, "wood", 8)
    avail = resources.getAvailableCapacity(b.storage, "wood")
    assert(avail == 32, "available capacity should be 32 weight after withdrawing 8 wood, got " .. avail)
end

local function test_reservationArithmetic()
    resetState()
    local b  = makeStockpile(4)
    local id = resources.create("wood", 12)
    resources.deposit(b.storage, id)

    -- Reserve 5 wood out (a hauler is picking up 5)
    resources.reserve(b.storage, "wood", 5, "out")

    local avail = resources.getAvailableStock(b.storage, "wood")
    assert(avail == 7, "available stock should be 12-5=7, got " .. avail)
    assert((world.resource_counts.storage_reserved["wood"] or 0) == 5,
        "storage_reserved[wood] should be 5")

    -- Release 3 of the 5 reserved
    resources.releaseReservation(b.storage, "wood", 3, "out")
    avail = resources.getAvailableStock(b.storage, "wood")
    assert(avail == 10, "available stock should be 12-2=10 after partial release, got " .. avail)
    assert((world.resource_counts.storage_reserved["wood"] or 0) == 2,
        "storage_reserved[wood] should be 2 after partial release")
end

local function test_rebuildCountsMatchesTally()
    resetState()
    local b = makeStockpile(6)

    resources.deposit(b.storage, resources.create("wood",    10))
    resources.deposit(b.storage, resources.create("berries", 4))
    resources.deposit(b.storage, resources.create("wood",    6))

    -- Capture running tallies
    local wood_tally    = world.resource_counts.storage["wood"]    or 0
    local berry_tally   = world.resource_counts.storage["berries"] or 0

    -- Rebuild from scratch and compare
    resources.rebuildCounts()

    assert((world.resource_counts.storage["wood"]    or 0) == wood_tally,
        "rebuildCounts wood mismatch: tally=" .. wood_tally ..
        " rebuilt=" .. (world.resource_counts.storage["wood"] or 0))
    assert((world.resource_counts.storage["berries"] or 0) == berry_tally,
        "rebuildCounts berries mismatch: tally=" .. berry_tally ..
        " rebuilt=" .. (world.resource_counts.storage["berries"] or 0))
end

return {
    { "depositToStockpile",         test_depositToStockpile         },
    { "partialWithdraw",            test_partialWithdraw            },
    { "capacityEnforcement",        test_capacityEnforcement        },
    { "reservationArithmetic",      test_reservationArithmetic      },
    { "rebuildCountsMatchesTally",  test_rebuildCountsMatchesTally  },
}
