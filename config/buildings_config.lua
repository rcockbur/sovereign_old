-- config/buildings.lua
-- BuildingConfig: dimensions, costs, worker limits, inventories, hauling rules.
-- Separate from constants.lua for readability. Sets BuildingConfig global.

BuildingConfig = {
    -- Storage
    stockpile = {
        is_player_sized = true,   -- width/height set by player at placement
        build_cost      = {},     -- free, no construction required
        slot_capacity   = 20,
    },
    warehouse = {
        width = 4, height = 4,
        build_cost    = { logs = 80, stone = 40 },
        slot_count    = 16,
        slot_capacity = 60,
    },

    -- Housing
    cottage = {
        width = 3, height = 3, housing_tier = Tier.SERF,
        build_cost = { logs = 40, stone = 20 },
        interior   = {
            { type = "bed", x = 0, y = 0 }, { type = "bed", x = 1, y = 0 },
            { type = "bed", x = 0, y = 2 }, { type = "bed", x = 1, y = 2 },
        },
    },
    house = {
        width = 4, height = 3, housing_tier = Tier.FREEMAN,
        build_cost = { logs = 80, stone = 50 },
        interior   = {
            { type = "bed", x = 0, y = 0 }, { type = "bed", x = 1, y = 0 },
            { type = "bed", x = 2, y = 0 }, { type = "bed", x = 0, y = 2 },
            { type = "bed", x = 1, y = 2 }, { type = "bed", x = 2, y = 2 },
        },
    },
    manor = {
        width = 5, height = 4, housing_tier = Tier.GENTRY,
        build_cost = { logs = 150, stone = 120 },
        interior   = {
            { type = "bed", x = 0, y = 0 }, { type = "bed", x = 1, y = 0 },
            { type = "bed", x = 3, y = 0 }, { type = "bed", x = 4, y = 0 },
            { type = "bed", x = 0, y = 3 }, { type = "bed", x = 1, y = 3 },
            { type = "bed", x = 3, y = 3 }, { type = "bed", x = 4, y = 3 },
        },
    },

    -- Farming
    farm_plot = {
        width = 4, height = 4,
        build_cost  = { logs = 10 },
        max_workers = 4,
    },

    -- Hub gathering (output only; workers gather from the world)
    woodcutters_camp = {
        width = 2, height = 2,
        build_cost  = { logs = 20 },
        max_workers = 4,
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "logs" } },
        default_hauling_rules = {
            { direction = "push", resource = "logs", threshold = 15 },
        },
    },
    gatherers_hut = {
        width = 2, height = 2,
        build_cost  = { logs = 15 },
        max_workers = 3,
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "berries" } },
        default_hauling_rules = {
            { direction = "push", resource = "berries", threshold = 15 },
        },
    },
    hunting_cabin = {
        width = 2, height = 2,
        build_cost  = { logs = 25 },
        max_workers = 2,
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "meat" } },
        default_hauling_rules = {
            { direction = "push", resource = "meat", threshold = 15 },
        },
    },

    -- Stationary extraction (output only; workers produce on-site)
    mine = {
        width = 3, height = 3,
        build_cost  = { logs = 40, stone = 30 },
        placement   = "rock_edge",
        max_workers = 4,
        output = { slot_count = 4, slot_capacity = 20, accepted_resources = { "iron", "gold", "silver", "gems" } },
        default_hauling_rules = {
            { direction = "push", resource = "iron",   threshold = 15 },
            { direction = "push", resource = "gold",   threshold = 5  },
            { direction = "push", resource = "silver", threshold = 5  },
            { direction = "push", resource = "gems",   threshold = 5  },
        },
    },
    quarry = {
        width = 3, height = 3,
        build_cost  = { logs = 30 },
        max_workers = 4,
        output = { slot_count = 4, slot_capacity = 20, accepted_resources = { "stone" } },
        default_hauling_rules = {
            { direction = "push", resource = "stone", threshold = 15 },
        },
    },
    fishing_dock = {
        width = 2, height = 2,
        build_cost  = { logs = 20 },
        placement   = "water_edge",
        max_workers = 2,
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "fish" } },
        default_hauling_rules = {
            { direction = "push", resource = "fish", threshold = 15 },
        },
    },

    -- Processing (input + output; workers fetch inputs and craft)
    mill = {
        width = 3, height = 3,
        build_cost  = { logs = 50, stone = 30 },
        max_workers = 2,
        input  = { slot_count = 2, slot_capacity = 20, accepted_resources = { "wheat" } },
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "flour" } },
        default_hauling_rules = {
            { direction = "pull", resource = "wheat", threshold = 5  },
            { direction = "push", resource = "flour", threshold = 15 },
        },
    },
    bakery = {
        width = 3, height = 3,
        build_cost  = { logs = 40, stone = 20 },
        max_workers = 2,
        input  = { slot_count = 2, slot_capacity = 20, accepted_resources = { "flour" } },
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "bread" } },
        default_hauling_rules = {
            { direction = "pull", resource = "flour", threshold = 5  },
            { direction = "push", resource = "bread", threshold = 15 },
        },
    },
    brewery = {
        width = 3, height = 3,
        build_cost  = { logs = 50, stone = 20 },
        max_workers = 2,
        input  = { slot_count = 2, slot_capacity = 20, accepted_resources = { "barley" } },
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "beer" } },
        default_hauling_rules = {
            { direction = "pull", resource = "barley", threshold = 5  },
            { direction = "push", resource = "beer",   threshold = 15 },
        },
    },
    tailors_shop = {
        width = 3, height = 3,
        build_cost  = { logs = 40, stone = 15 },
        max_workers = 2,
        input  = { slot_count = 2, slot_capacity = 20, accepted_resources = { "flax" } },
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "clothing" } },
        default_hauling_rules = {
            { direction = "pull", resource = "flax",     threshold = 5  },
            { direction = "push", resource = "clothing", threshold = 15 },
        },
    },
    smithy = {
        width = 3, height = 3,
        build_cost  = { logs = 30, stone = 40 },
        max_workers = 2,
        input  = { slot_count = 2, slot_capacity = 20, accepted_resources = { "iron" } },
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "tools", "weapons", "armor" } },
        default_hauling_rules = {
            { direction = "pull", resource = "iron",    threshold = 5  },
            { direction = "push", resource = "tools",   threshold = 15 },
            { direction = "push", resource = "weapons", threshold = 15 },
            { direction = "push", resource = "armor",   threshold = 15 },
        },
    },
    foundry = {
        width = 4, height = 4,
        build_cost  = { logs = 60, stone = 80 },
        max_workers = 2,
        input  = { slot_count = 4, slot_capacity = 20, accepted_resources = { "iron" } },
        output = { slot_count = 4, slot_capacity = 20, accepted_resources = { "steel", "tools", "weapons", "armor" } },
        default_hauling_rules = {
            { direction = "pull", resource = "iron",    threshold = 5  },
            { direction = "push", resource = "steel",   threshold = 15 },
            { direction = "push", resource = "tools",   threshold = 15 },
            { direction = "push", resource = "weapons", threshold = 15 },
            { direction = "push", resource = "armor",   threshold = 15 },
        },
    },
    jewelers_workshop = {
        width = 3, height = 3,
        build_cost  = { logs = 40, stone = 30 },
        max_workers = 1,
        input  = { slot_count = 2, slot_capacity = 20, accepted_resources = { "gold", "silver", "gems" } },
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "jewelry" } },
        default_hauling_rules = {
            { direction = "pull", resource = "gold",    threshold = 5  },
            { direction = "pull", resource = "silver",  threshold = 5  },
            { direction = "pull", resource = "gems",    threshold = 5  },
            { direction = "push", resource = "jewelry", threshold = 10 },
        },
    },

    -- Services
    market = {
        width = 4, height = 3,
        build_cost  = { logs = 60, stone = 30 },
        max_workers = 1,
    },
    church = {
        width = 5, height = 4,
        build_cost  = { logs = 80, stone = 60 },
        max_workers = 1,
    },
    infirmary = {
        width = 3, height = 3,
        build_cost  = { logs = 50, stone = 30 },
        max_workers = 2,
        input = { slot_count = 2, slot_capacity = 20, accepted_resources = { "herbs" } },
        default_hauling_rules = {
            { direction = "pull", resource = "herbs", threshold = 5 },
        },
    },
    tavern = {
        width = 4, height = 3,
        build_cost  = { logs = 60, stone = 30 },
        max_workers = 1,
        input = { slot_count = 2, slot_capacity = 20, accepted_resources = { "beer" } },
        default_hauling_rules = {
            { direction = "pull", resource = "beer", threshold = 5 },
        },
    },
    school = {
        width = 3, height = 3,
        build_cost  = { logs = 50, stone = 20 },
        max_workers = 1,
    },

    -- Military
    barracks   = { width = 4, height = 3, build_cost = { logs = 60, stone = 40 } },
    watchtower = { width = 2, height = 2, build_cost = { logs = 30, stone = 30 } },

    -- Governance / Late-game
    town_hall = { width = 5, height = 4, build_cost = { logs = 120, stone = 100 } },
    library   = { width = 4, height = 3, build_cost = { logs = 80,  stone = 50  }, max_workers = 1 },
}
