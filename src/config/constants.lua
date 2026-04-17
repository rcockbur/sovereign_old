-- config/constants.lua
-- All game constants. Loaded as globals via main.lua before any other module.

-- Priorities
Priority       = { DISABLED = 0, LOW = 1, NORMAL = 2, HIGH = 3 }
InterruptLevel = { NONE = 0, SOFT = 1, HARD = 2 }

-- Map
MAP_WIDTH          = 400
MAP_HEIGHT         = 200
SETTLEMENT_COLUMNS = 200
FOREST_START       = 201

-- Calendar (authored)
MINUTES_PER_HOUR = 60
HOURS_PER_DAY    = 24
DAYS_PER_SEASON  = 7
SEASONS_PER_YEAR = 4

-- Calendar (derived)
DAYS_PER_YEAR    = DAYS_PER_SEASON  * SEASONS_PER_YEAR    -- 28
HOURS_PER_SEASON = HOURS_PER_DAY   * DAYS_PER_SEASON      -- 168
HOURS_PER_YEAR   = HOURS_PER_SEASON * SEASONS_PER_YEAR    -- 672

-- Tick system (authored)
TICK_RATE        = 60
HASH_INTERVAL    = 60
TICKS_PER_MINUTE = 25

-- Tick system (derived)
TICKS_PER_HOUR   = TICKS_PER_MINUTE * MINUTES_PER_HOUR    -- 1500
TICKS_PER_DAY    = TICKS_PER_HOUR   * HOURS_PER_DAY       -- 36000
TICKS_PER_SEASON = TICKS_PER_DAY    * DAYS_PER_SEASON     -- 252000
TICKS_PER_YEAR   = TICKS_PER_SEASON * SEASONS_PER_YEAR    -- 1008000

-- Per-tick conversion helpers
PER_MINUTE = 1 / TICKS_PER_MINUTE
PER_HOUR   = 1 / TICKS_PER_HOUR
PER_DAY    = 1 / TICKS_PER_DAY
PER_SEASON = 1 / TICKS_PER_SEASON

-- Speed multipliers
Speed = { NORMAL = 1, FAST = 2, VERY_FAST = 4, ULTRA = 8, TURBO = 32, MAX = 64 }

-- Schedule (hour boundaries for sleep threshold bands)
MORNING_START = 5     -- night → day lerp begins
DAY_START     = 7     -- flat day band begins
EVENING_START = 20    -- day → night lerp begins
NIGHT_START   = 0     -- flat night band begins at midnight
CHURCH_DAY    = 1     -- Sunday (day_of_season index)

-- Aging
AGES_PER_YEAR    = SEASONS_PER_YEAR    -- 4 age increments per year
AGE_OF_ADULTHOOD = 16
AGE_OF_SCHOOLING = 6

-- Frost (exact day ranges TBD during tuning)
-- THAW_DAY_MIN / THAW_DAY_MAX   — spring thaw roll range
-- FROST_DAY_MIN / FROST_DAY_MAX — autumn frost roll range
-- FROST_WARNING_DAYS            — days before frost_day that warning fires
-- FROST_DECAY_RATE              — maturity loss per tick on unharvested crops after frost

-- Plants
SPREAD_TILES_PER_TICK = 50

-- Visibility (all tiles explored/visible until implemented)
SIGHT_RADIUS        = 8
FOREST_SIGHT_RADIUS = 3

-- Movement
BASE_MOVE_COST       = 6        -- ticks per tile on open ground
TREE_MOVE_MULTIPLIER = 3.0      -- trees stage 2+ slow movement
SQRT2                = math.sqrt(2)

-- Carrying
CARRY_WEIGHT_MAX = 32
MAX_CARRY_SLOW   = 0.5          -- max speed reduction at full weight and 0 strength

-- Storage
STOCKPILE_TILE_CAPACITY       = 64     -- weight capacity per stockpile tile
WAREHOUSE_CAPACITY            = 128    -- total weight capacity for warehouse
GROUND_PILE_PREFERRED_CAPACITY = 64    -- soft cap for ground pile spreading

-- Ground drops
GROUND_DROP_SEARCH_RADIUS = 2

-- Resource scanning
RESOURCE_SCAN_RADIUS = 100

-- Food
FOOD_VARIETY_WINDOW = 3 * TICKS_PER_DAY

-- Work day and recreation
WORK_DAY_RESET_HOUR      = 4
RECREATION_WANDER_RADIUS = 6

-- Building layout tile types
TILE_WALL  = "W"
TILE_FLOOR = "F"
TILE_DOOR  = "D"

-- Building placement
CLEARING_DEPTH = 1    -- tiles in front of door face that cannot have buildings

-- Rendering
TILE_SIZE = 32
ZOOM_MIN  = 0.5
ZOOM_MAX  = 2.0

-- Day and season names (indexed 1-based)
DAY_NAMES    = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
SEASON_NAMES = { "Spring", "Summer", "Autumn", "Winter" }
