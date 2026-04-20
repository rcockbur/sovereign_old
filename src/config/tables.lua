-- config/tables.lua
-- All config tables. Loaded as globals via main.lua after constants.

-- Three needs tiers: meager (serfs), standard (freemen, priests), luxurious (gentry, bishops).
-- Satiation is uniform across tiers. Energy hard_threshold is uniform; soft threshold is
-- time-of-day varying (see SleepConfig). Recreation is a mood meter, not a behavioral interrupt.
-- Lookup: NeedsConfig[unit.needs_tier]
NeedsConfig = {
    meager = {
        satiation  = { drain = 2 * PER_HOUR, soft_threshold = 75, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        energy     = { drain = 4 * PER_HOUR,                      hard_threshold = 10, mood_threshold = 30, mood_penalty = -10 },
        recreation = { mood_threshold = 30, mood_penalty = -10 },
    },
    standard = {
        satiation  = { drain = 2 * PER_HOUR, soft_threshold = 75, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        energy     = { drain = 4 * PER_HOUR,                      hard_threshold = 10, mood_threshold = 50, mood_penalty = -15 },
        recreation = { mood_threshold = 50, mood_penalty = -15 },
    },
    luxurious = {
        satiation  = { drain = 2 * PER_HOUR, soft_threshold = 75, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        energy     = { drain = 4 * PER_HOUR,                      hard_threshold = 10, mood_threshold = 60, mood_penalty = -20 },
        recreation = { mood_threshold = 60, mood_penalty = -20 },
    },
}

-- Energy recovery and time-of-day sleep thresholds.
-- Four periods: Night (flat night values), Morning (lerp night→day),
-- Day (flat day values), Evening (lerp day→night). See BEHAVIOR.md Sleep.
SleepConfig = {
    recovery_rate = 8 * PER_HOUR,
    night = { soft = 50, wake = 100 },
    day   = { soft = 20, wake = 85  },
}

-- Recreation: mood meter only. Drain while awake and not recreating.
-- Diminishing returns formula TBD during tuning.
RecreationConfig = {
    work_drain    = 4.55 * PER_HOUR,
    recovery_rate = 10 * PER_HOUR,
}

MerchantConfig = {
    carry_capacity    = 64,
    idle_ticks_base   = 2 * TICKS_PER_HOUR,
    drop_amount       = 2,
    critical_threshold = 2,
    serious_threshold  = 4,
    bin_threshold = { bread = 6, berries = 6, fish = 6 },
}

-- One bin per entry; built dynamically on housing construction.
HousingBinConfig = {
    { type = "bread",   capacity = 128 },
    { type = "berries", capacity = 128 },
    { type = "fish",    capacity = 128 },
}

ActivityConfig = {
    age_weight = 0.2,    -- score = age_weight * (tick - posted_tick) - manhattan_distance
}

-- is_specialty = false: any serf. is_specialty = true: freeman/clergy with matching specialty.
-- work_source: "plant" | "recipe" | "crop" | "activity" | "target" | nil
ActivityTypeConfig = {
    -- Unskilled
    hauler      = { is_specialty = false, attribute = "strength" },
    woodcutter  = { is_specialty = false, attribute = "strength",     work_source = "plant" },
    iron_miner  = { is_specialty = false, attribute = "strength",     work_source = "activity", work_ticks = 2 * TICKS_PER_HOUR },
    stonecutter = { is_specialty = false, attribute = "strength",     work_source = "activity", work_ticks = 2 * TICKS_PER_HOUR },
    miller      = { is_specialty = false, attribute = "strength",     work_source = "recipe" },
    builder     = { is_specialty = false, attribute = "intelligence", work_source = "target" },
    farmer      = { is_specialty = false, attribute = "intelligence", work_source = "crop" },
    fisher      = { is_specialty = false, attribute = "intelligence", work_source = "activity", work_ticks = 2 * TICKS_PER_HOUR },
    gatherer    = { is_specialty = false, attribute = "intelligence", work_source = "plant" },
    herbalist   = { is_specialty = false, attribute = "intelligence", work_source = "plant" },

    -- Specialty — freeman
    smith    = { is_specialty = true, class = "freeman", attribute = "strength",     skill = "smithing",   max_skill = 10, work_source = "recipe" },
    smelter  = { is_specialty = true, class = "freeman", attribute = "strength",     skill = "smelting",   max_skill = 10, work_source = "recipe" },
    tailor   = { is_specialty = true, class = "freeman", attribute = "intelligence", skill = "tailoring",  max_skill = 10, work_source = "recipe" },
    baker    = { is_specialty = true, class = "freeman", attribute = "intelligence", skill = "baking",     max_skill = 10, work_source = "recipe" },
    brewer   = { is_specialty = true, class = "freeman", attribute = "intelligence", skill = "brewing",    max_skill = 10, work_source = "recipe" },
    teacher  = { is_specialty = true, class = "freeman", attribute = "intelligence", skill = "teaching",   max_skill = 10 },
    scholar  = { is_specialty = true, class = "freeman", attribute = "intelligence", skill = "research",   max_skill = 10 },
    physician = { is_specialty = true, class = "freeman", attribute = "intelligence", skill = "medicine",  max_skill = 10 },
    barkeep  = { is_specialty = true, class = "freeman", attribute = "charisma",     skill = "barkeeping", max_skill = 10 },
    merchant = { is_specialty = true, class = "freeman", attribute = "charisma",     skill = "trading",    max_skill = 10 },

    -- Specialty — clergy
    priest = { is_specialty = true, class = "clergy", attribute = "charisma", skill = "priesthood", max_skill = 10 },
    bishop = { is_specialty = true, class = "clergy", attribute = "charisma", skill = "priesthood", max_skill = 10 },
}

SerfChildActivities = { "hauler", "farmer", "gatherer", "fisher" }

RecipeConfig = {
    flour          = { input = { wheat = 1 },              output = { flour = 1 },          work_ticks = 30 * TICKS_PER_MINUTE },
    bread          = { input = { flour = 1 },              output = { bread = 1 },          work_ticks = 1 * TICKS_PER_HOUR },
    beer           = { input = { barley = 1 },             output = { beer = 1 },           work_ticks = 1 * TICKS_PER_HOUR },
    plain_clothing = { input = { flax = 2 },               output = { plain_clothing = 1 }, work_ticks = 2 * TICKS_PER_HOUR },
    steel          = { input = { iron = 2, firewood = 4 }, output = { steel = 1 },          work_ticks = 2 * TICKS_PER_HOUR },
    iron_tools     = { input = { iron = 2 },               output = { iron_tools = 1 },     work_ticks = 2 * TICKS_PER_HOUR },
    steel_tools    = { input = { steel = 2 },              output = { steel_tools = 1 },    work_ticks = 2 * TICKS_PER_HOUR },
}

GrowthConfig = {
    -- progress accumulates per tick during specialty work; level-up at skill_level_ticks * (skill + 1)
    skill_level_ticks      = 70000,
    genetic_attribute_max  = 7,
    acquired_attribute_max = 3,
    school_intelligence_gain = 0,    -- TBD
}

MoodThresholdConfig = {
    inspired   = 80,
    content    = 40,
    sad        = 20,
    distraught = 0,
}

MoodModifierConfig = {
    -- Calculated each update
    no_home            = -20,
    food_variety_bonus =   5,
    has_clothing       =   5,
    no_clothing        = -15,
    low_health         = -10,

    -- Event-driven (stored with ticks_remaining)
    family_death      = { value = -20, duration = 14 * TICKS_PER_DAY },
    friend_death      = { value = -10, duration =  7 * TICKS_PER_DAY },
    marriage          = { value =  20, duration = 14 * TICKS_PER_DAY },
    specialty_revoked = { value = -15, duration =  7 * TICKS_PER_DAY },
    sunday_service_base = { value = 10, duration = 7 * TICKS_PER_DAY },
    funeral_attended  = { value =   5, duration =  3 * TICKS_PER_DAY },
    wedding_attended  = { value =   5, duration =  3 * TICKS_PER_DAY },
    beer_consumed     = { value =  10, duration =  1 * TICKS_PER_DAY },
}

InjuryConfig = {
    bruised = { initial_damage = 10, recovery = 0.5  * PER_HOUR },
    wounded = { initial_damage = 30, recovery = 0.2  * PER_HOUR },
    maimed  = { initial_damage = 50, recovery = 0.05 * PER_HOUR },
}

IllnessConfig = {
    cold        = { damage = 0.1 * PER_HOUR, recovery_chance = 0.08,  recovery = 0.4  * PER_HOUR },
    flu         = { damage = 0.2 * PER_HOUR, recovery_chance = 0.08,  recovery = 0.4  * PER_HOUR },
    flux        = { damage = 0.4 * PER_HOUR, recovery_chance = 0.10,  recovery = 0.3  * PER_HOUR },
    consumption = { damage = 0.1 * PER_HOUR, recovery_chance = 0.005, recovery = 0.2  * PER_HOUR },
    pox         = { damage = 0.3 * PER_HOUR, recovery_chance = 0.02,  recovery = 0.2  * PER_HOUR },
    pestilence  = { damage = 0.5 * PER_HOUR, recovery_chance = 0.01,  recovery = 0.15 * PER_HOUR },
}

MalnourishedConfig = { damage = 0.3 * PER_HOUR, recovery = 0.5 * PER_HOUR }

-- Stackable: fungible (split/merge). Non-stackable: items with durability.
-- weight: used for carry capacity and storage density alike.
ResourceConfig = {
    -- Construction
    wood  = { weight = 4, is_stackable = true },
    stone = { weight = 4, is_stackable = true },

    -- Metals
    iron  = { weight = 4, is_stackable = true },
    steel = { weight = 4, is_stackable = true },

    -- Fuel
    firewood = { weight = 4, is_stackable = true },

    -- Crops
    wheat  = { weight = 1, is_stackable = true },
    barley = { weight = 1, is_stackable = true },
    flax   = { weight = 1, is_stackable = true },

    -- Processed crops
    flour = { weight = 1, is_stackable = true },

    -- Food (all weight 4, nutrition 24)
    bread   = { weight = 4, is_stackable = true, nutrition = 24 },
    berries = { weight = 4, is_stackable = true, nutrition = 24 },
    fish    = { weight = 4, is_stackable = true, nutrition = 24 },

    -- Other consumables
    beer  = { weight = 4, is_stackable = true },
    herbs = { weight = 1, is_stackable = true },

    -- Equipment (items)
    plain_clothing = { weight = 1, is_stackable = false, max_durability = 100 },
    iron_tools     = { weight = 2, is_stackable = false, max_durability = 100, tool_bonus = 3 },
    steel_tools    = { weight = 2, is_stackable = false, max_durability = 200, tool_bonus = 5 },
}

PlantConfig = {
    tree = {
        min_depth      = 0.0,
        seedling_ticks = 1 * TICKS_PER_SEASON,
        young_ticks    = 2 * TICKS_PER_SEASON,
        harvest_ticks  = 1 * TICKS_PER_HOUR,
        harvest_yield  = 4,
        spread_chance  = 0.01,
        spread_radius  = 4,
    },
    herb_bush = {
        min_depth      = 0.0,
        seedling_ticks = math.floor(0.5 * TICKS_PER_SEASON),
        young_ticks    = math.floor(0.5 * TICKS_PER_SEASON),
        harvest_ticks  = 4 * TICKS_PER_HOUR,
        harvest_yield  = 0,    -- TBD: herbs have no consumer until Phase 4
        spread_chance  = 0.01,
        spread_radius  = 4,
    },
    berry_bush = {
        min_depth      = 0.0,
        seedling_ticks = math.floor(0.5 * TICKS_PER_SEASON),
        young_ticks    = math.floor(0.5 * TICKS_PER_SEASON),
        harvest_ticks  = 1 * TICKS_PER_HOUR,
        harvest_yield  = 4,
        spread_chance  = 0.01,
        spread_radius  = 4,
    },
}

-- growth_ticks TBD: wheat longest, barley medium, flax shortest.
-- yield_per_tile: output at 1.0 maturity; partial = floor(yield * maturity).
CropConfig = {
    wheat  = { plant_ticks = 15 * TICKS_PER_MINUTE, harvest_ticks = 30 * TICKS_PER_MINUTE, growth_ticks = 0, yield_per_tile = 8 },
    barley = { plant_ticks = 15 * TICKS_PER_MINUTE, harvest_ticks = 30 * TICKS_PER_MINUTE, growth_ticks = 0, yield_per_tile = 6 },
    flax   = { plant_ticks = 15 * TICKS_PER_MINUTE, harvest_ticks = 30 * TICKS_PER_MINUTE, growth_ticks = 0, yield_per_tile = 10 },
}

-- Input bin and storage capacity values are in weight units.
-- Capacity per resource type = floor(capacity / ResourceConfig[type].weight).
BuildingConfig = {
    -- Storage
    stockpile = {
        category       = "storage",
        is_player_sized = true,
        build_cost     = {},
        build_ticks_per_tile = 15 * TICKS_PER_MINUTE,
        storage        = { tile_capacity = STOCKPILE_TILE_CAPACITY },
    },
    warehouse = {
        category   = "storage",
        width = 4, height = 4,
        build_cost = { wood = 60, stone = 40 },
        build_ticks = 12 * TICKS_PER_HOUR,
        storage    = { is_stackable_only = true, capacity = WAREHOUSE_CAPACITY },
        tile_map   = {},
        layout     = {},
    },
    barn = {
        category   = "storage",
        width = 4, height = 3,
        build_cost = { wood = 50, stone = 30 },
        build_ticks = 10 * TICKS_PER_HOUR,
        storage    = { is_items_only = true, item_capacity = 40 },
        tile_map   = {},
        layout     = {},
    },

    -- Housing
    cottage = {
        category   = "housing",
        width = 3, height = 3,
        build_cost = { wood = 40, stone = 20 },
        build_ticks = 6 * TICKS_PER_HOUR,
        tile_map = {
            "I", "I", "I",
            "I", "I", "I",
            "I", "D", "I",
        },
        layout = {
            beds = {
                { x = 0, y = 0 }, { x = 2, y = 0 },
                { x = 0, y = 1 }, { x = 2, y = 1 },
            },
        },
    },
    house = {
        category   = "housing",
        width = 4, height = 3,
        build_cost = { wood = 60, stone = 40 },
        build_ticks = 10 * TICKS_PER_HOUR,
        tile_map   = {},
        layout     = { beds = {} },
    },
    manor = {
        category   = "housing",
        width = 5, height = 4,
        build_cost = { wood = 100, stone = 80 },
        build_ticks = 14 * TICKS_PER_HOUR,
        tile_map   = {},
        layout     = { beds = {} },
    },

    -- Farming (player-sized, no tile_map)
    farm = {
        category        = "farming",
        is_player_sized = true,
        build_cost      = { wood = 10 },
        build_ticks_per_tile = 15 * TICKS_PER_MINUTE,
        max_workers     = 4,
        activity_type   = "farmer",
    },

    -- Hub gathering (solid buildings — all-X tile map, no interior)
    woodcutters_camp = {
        category      = "gathering",
        width = 2, height = 2,
        build_cost    = { wood = 20 },
        build_ticks   = 4 * TICKS_PER_HOUR,
        max_workers   = 4,
        activity_type = "woodcutter",
        tile_map = {
            "X", "X",
            "X", "X",
        },
        layout = {},
    },
    gatherers_hut = {
        category      = "gathering",
        width = 2, height = 2,
        build_cost    = { wood = 15 },
        build_ticks   = 4 * TICKS_PER_HOUR,
        max_workers   = 4,
        activity_type = "gatherer",
        tile_map = {
            "X", "X",
            "X", "X",
        },
        layout = {},
    },
    herbalists_hut = {
        category      = "gathering",
        width = 2, height = 2,
        build_cost    = { wood = 15 },
        build_ticks   = 4 * TICKS_PER_HOUR,
        max_workers   = 4,
        activity_type = "herbalist",
        tile_map = {
            "X", "X",
            "X", "X",
        },
        layout = {},
    },

    -- Extraction
    fishing_dock = {
        category      = "extraction",
        width = 3, height = 3,
        build_cost    = { wood = 20 },
        build_ticks   = 6 * TICKS_PER_HOUR,
        placement     = "water",
        max_workers   = 3,
        activity_type = "fisher",
        tile_map = {
            "I", "I", "I",
            "I", "I", "I",
            "I", "D", "I",
        },
        layout = {
            workstation = { { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 2, y = 0 } },
        },
    },
    iron_mine = {
        category      = "extraction",
        width = 3, height = 3,
        build_cost    = { wood = 40, stone = 30 },
        build_ticks   = 10 * TICKS_PER_HOUR,
        placement     = "rock",
        max_workers   = 4,
        activity_type = "iron_miner",
        tile_map      = {},
        layout        = {},
    },
    quarry = {
        category      = "extraction",
        width = 3, height = 3,
        build_cost    = { wood = 30, stone = 10 },
        build_ticks   = 10 * TICKS_PER_HOUR,
        placement     = "rock",
        max_workers   = 4,
        activity_type = "stonecutter",
        tile_map      = {},
        layout        = {},
    },

    -- Processing (all max_workers = 1)
    mill = {
        category      = "processing",
        width = 3, height = 3,
        build_cost    = { wood = 40, stone = 20 },
        build_ticks   = 8 * TICKS_PER_HOUR,
        max_workers   = 1,
        activity_type = "miller",
        recipes       = { "flour" },
        default_production_orders = {
            { recipe = "flour", is_standing = true, amount = -1 },
        },
        input_bins = {
            { type = "wheat", capacity = 128 },
        },
        tile_map = {},
        layout   = {},
    },
    bakery = {
        category      = "processing",
        width = 3, height = 3,
        build_cost    = { wood = 40, stone = 20 },
        build_ticks   = 8 * TICKS_PER_HOUR,
        max_workers   = 1,
        activity_type = "baker",
        recipes       = { "bread" },
        default_production_orders = {
            { recipe = "bread", is_standing = true, amount = -1 },
        },
        input_bins = {
            { type = "flour", capacity = 128 },
        },
        tile_map = {},
        layout   = {},
    },
    brewery = {
        category      = "processing",
        width = 3, height = 3,
        build_cost    = { wood = 40, stone = 20 },
        build_ticks   = 8 * TICKS_PER_HOUR,
        max_workers   = 1,
        activity_type = "brewer",
        recipes       = { "beer" },
        default_production_orders = {
            { recipe = "beer", is_standing = true, amount = -1 },
        },
        input_bins = {
            { type = "barley", capacity = 128 },
        },
        tile_map = {},
        layout   = {},
    },
    tailors_shop = {
        category      = "processing",
        width = 3, height = 3,
        build_cost    = { wood = 40, stone = 20 },
        build_ticks   = 8 * TICKS_PER_HOUR,
        max_workers   = 1,
        activity_type = "tailor",
        recipes       = { "plain_clothing" },
        default_production_orders = {
            { recipe = "plain_clothing", is_standing = true, amount = -1 },
        },
        input_bins = {
            { type = "flax", capacity = 128 },
        },
        tile_map = {},
        layout   = {},
    },
    smithy = {
        category      = "processing",
        width = 3, height = 3,
        build_cost    = { wood = 40, stone = 40 },
        build_ticks   = 12 * TICKS_PER_HOUR,
        max_workers   = 1,
        activity_type = "smith",
        recipes       = { "iron_tools" },
        default_production_orders = {
            { recipe = "iron_tools", is_standing = true, amount = -1 },
        },
        input_bins = {
            { type = "iron", capacity = 128 },
        },
        tile_map = {},
        layout   = {},
    },
    bloomery = {
        category      = "processing",
        width = 3, height = 3,
        build_cost    = { wood = 40, stone = 40 },
        build_ticks   = 12 * TICKS_PER_HOUR,
        max_workers   = 1,
        activity_type = "smelter",
        recipes       = { "steel" },
        default_production_orders = {
            { recipe = "steel", is_standing = true, amount = -1 },
        },
        input_bins = {
            { type = "iron",     capacity = 128 },
            { type = "firewood", capacity = 128 },
        },
        tile_map = {},
        layout   = {},
    },

    -- Service
    market = {
        category      = "service",
        width = 3, height = 3,
        build_cost    = { wood = 40, stone = 20 },
        build_ticks   = 8 * TICKS_PER_HOUR,
        max_workers   = 1,
        activity_type = "merchant",
        tile_map      = {},
        layout        = {},
    },
    tavern = {
        category      = "service",
        width = 3, height = 3,
        build_cost    = { wood = 40, stone = 20 },
        build_ticks   = 8 * TICKS_PER_HOUR,
        max_workers   = 1,
        activity_type = "barkeep",
        tile_map      = {},
        layout        = {},
    },
    apothecary = {
        category      = "service",
        width = 3, height = 3,
        build_cost    = { wood = 40, stone = 20 },
        build_ticks   = 8 * TICKS_PER_HOUR,
        max_workers   = 1,
        activity_type = "physician",
        tile_map      = {},
        layout        = {},
    },
}

NameConfig = {
    male = {
        "Aldric", "Alfred", "Baldwin", "Beric", "Brand", "Cedric", "Colin",
        "Conrad", "Edmund", "Edward", "Garrett", "Geoffrey", "Gilbert",
        "Godwin", "Gunther", "Harold", "Henry", "Hugh", "Miles", "Oswin",
        "Ralph", "Reynard", "Richard", "Robert", "Roger", "Roland", "Rolf",
        "Thomas", "Walter", "William",
    },
    female = {
        "Ada", "Agnes", "Alice", "Annette", "Astrid", "Aveline", "Beatrice",
        "Brenna", "Cecily", "Constance", "Eleanor", "Elise", "Emma", "Freya",
        "Greta", "Gwynn", "Hadley", "Hilda", "Ingrid", "Isabel", "Lena",
        "Maren", "Margery", "Matilda", "Marta", "Millicent", "Roslyn",
        "Seren", "Sigrid", "Wynna",
    },
    surname = {
        "Aldham", "Aldren", "Barrow", "Breck", "Caskwell", "Corwin",
        "Delling", "Dunbar", "Elsworth", "Falkner", "Fenwick", "Hale",
        "Harren", "Hollis", "Kessler", "Langford", "Leclerc", "Merrick",
        "Norwick", "Overton", "Pemberton", "Rathmore", "Selwyn", "Stroud",
        "Talbot", "Voss", "Wardell", "Wyndham", "Yoren",
    },
}

SettlementNameConfig = {
    prefix = {
        "Alder", "Amber", "Black", "Bramble", "Crow", "Elder", "Fen",
        "Glen", "Hallow", "Holly", "Iron", "Meadow", "Oak", "Raven",
        "Silver", "Stone", "Thorn", "Willow", "Winter",
    },
    suffix = {
        "bridge", "crest", "dale", "fall", "field", "ford", "gate",
        "glen", "haven", "holm", "keep", "march", "mere", "moor",
        "ton", "vale", "watch", "wick", "wood",
    },
}
