-- core/time.lua
-- Owns the clock. Drives the tick accumulator and speed multiplier.
-- Does not know about any other system.


local time = {
    speed       = Speed.NORMAL,
    is_paused   = false,
    accumulator = 0,

    -- Tick counter. Starts at WAKE_HOUR so the clock reads 6:00 on Day 1.
    tick        = WAKE_HOUR * TICKS_PER_HOUR,

    -- Derived clock values. Updated each tick by updateClock().
    game_minute = 0,
    game_hour   = WAKE_HOUR,
    game_day    = 1,
    game_season = 1,
    game_year   = 1,
}

--- Accumulate real time and return how many ticks to run this frame.
--- @param dt number  love.update delta time in seconds
--- @return number ticks_this_frame
function time:accumulate(dt)
    self.accumulator = self.accumulator + dt * self.speed
    local ticks = math.floor(self.accumulator * TICK_RATE)
    self.accumulator = self.accumulator - ticks / TICK_RATE
    return ticks
end

--- Advance the tick counter by one.
function time:advance()
    self.tick = self.tick + 1
    self.game_minute = math.floor(self.tick % TICKS_PER_HOUR  / TICKS_PER_MINUTE)
    self.game_hour   = math.floor(self.tick % TICKS_PER_DAY   / TICKS_PER_HOUR)
    self.game_day    = math.floor(self.tick % TICKS_PER_SEASON / TICKS_PER_DAY) + 1
    self.game_season = math.floor(self.tick % TICKS_PER_YEAR  / TICKS_PER_SEASON) + 1
    self.game_year   = math.floor(self.tick / TICKS_PER_YEAR) + 1
end

--- Spread unit updates evenly across HASH_INTERVAL ticks using the unit's id.
--- @param id number
--- @return number  offset in [0, HASH_INTERVAL)
function time:hashOffset(id)
    return (id * 7919) % HASH_INTERVAL
end

--- Reset clock to start-of-game state.
function time:reset()
    self.speed       = Speed.NORMAL
    self.is_paused   = false
    self.accumulator = 0
    self.tick        = WAKE_HOUR * TICKS_PER_HOUR
    self.game_minute = 0
    self.game_hour   = WAKE_HOUR
    self.game_day    = 1
    self.game_season = 1
    self.game_year   = 1
end

--- Stub: return serializable state. Full implementation in Phase 11.
function time:serialize()   return {} end
function time:deserialize(data) end

return time
