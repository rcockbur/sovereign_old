-- config/resources.lua
-- ResourceConfig: slot_size per resource type (units per slot = slot_capacity / slot_size).
-- ResourceSpawnConfig: minimum forest_depth required to spawn each resource category.


ResourceConfig = {
    logs     = { slot_size = 2 },
    stone    = { slot_size = 2 },
    iron     = { slot_size = 2 },
    steel    = { slot_size = 2 },
    gold     = { slot_size = 2 },
    silver   = { slot_size = 2 },
    gems     = { slot_size = 2 },
    wheat    = { slot_size = 2 },
    barley   = { slot_size = 2 },
    flax     = { slot_size = 2 },
    flour    = { slot_size = 2 },
    bread    = { slot_size = 2 },
    berries  = { slot_size = 2 },
    meat     = { slot_size = 2 },
    fish     = { slot_size = 2 },
    beer     = { slot_size = 2 },
    clothing = { slot_size = 2 },
    herbs    = { slot_size = 2 },
    tools    = { slot_size = 2 },
    weapons  = { slot_size = 2 },
    armor    = { slot_size = 2 },
    jewelry  = { slot_size = 2 },
}

ResourceSpawnConfig = {
    timber     = { min_depth = 0.0  },
    wildlife   = { min_depth = 0.0  },
    herbs      = { min_depth = 0.01 },
    berry_bush = { min_depth = 0.0  },
    artifacts  = { min_depth = 0.8  },
}
