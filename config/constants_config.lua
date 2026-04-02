-- config/constants.lua
-- All constants. Pure data, no dependencies. Sets globals.

Tier           = { SERF = 1, FREEMAN = 2, GENTRY = 3 }
JobTier        = { T1 = 1, T2 = 2, T3 = 3 }
Priority       = { DISABLED = 0, LOW = 1, NORMAL = 2, HIGH = 3 }
InterruptLevel = { NONE = 0, SOFT = 1, HARD = 2 }

-- Map
MAP_WIDTH          = 400
MAP_HEIGHT         = 200
SETTLEMENT_COLUMNS = 200
FOREST_START       = 201

-- Calendar
MINUTES_PER_HOUR = 60
HOURS_PER_DAY    = 24
DAYS_PER_SEASON  = 7
SEASONS_PER_YEAR = 4
DAYS_PER_YEAR    = DAYS_PER_SEASON * SEASONS_PER_YEAR    -- 28
HOURS_PER_SEASON = HOURS_PER_DAY * DAYS_PER_SEASON       -- 168
HOURS_PER_YEAR   = HOURS_PER_SEASON * SEASONS_PER_YEAR   -- 672

-- Tick system
TICK_RATE        = 60
HASH_INTERVAL    = 60
TICKS_PER_MINUTE = 25
TICKS_PER_HOUR   = 1500
TICKS_PER_DAY    = 36000
TICKS_PER_SEASON = 252000
TICKS_PER_YEAR   = 1008000

-- Conversion helpers (multiply a per-hour rate to get per-tick rate)
PER_MINUTE = 1 / TICKS_PER_MINUTE
PER_HOUR   = 1 / TICKS_PER_HOUR
PER_DAY    = 1 / TICKS_PER_DAY
PER_SEASON = 1 / TICKS_PER_SEASON

-- Speed multipliers
Speed = { NORMAL = 1, FAST = 2, VERY_FAST = 4, ULTRA = 8 }

-- Schedule
WAKE_HOUR  = 6
SLEEP_HOUR = 22
DAY_START  = 6
DAY_END    = 18
CHURCH_DAY = 1   -- Sunday

-- Aging
AGES_PER_YEAR    = SEASONS_PER_YEAR
AGE_OF_ADULTHOOD = 16

-- Plants
SPREAD_TILES_PER_TICK = 50
SPREAD_CHANCE         = 0.01
SPREAD_RADIUS         = 4
SEEDLING_GROWTH_TICKS = 0    -- TBD
YOUNG_GROWTH_TICKS    = 0    -- TBD

-- Visibility
SIGHT_RADIUS = 8

-- Hauling
CARRY_CAPACITY = 10

-- Rendering
TILE_SIZE = 32
ZOOM_MIN  = 0.5
ZOOM_MAX  = 2.0

