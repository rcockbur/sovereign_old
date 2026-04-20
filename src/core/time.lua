-- core/time.lua
-- Game clock: tick accumulation, calendar derivation, energy thresholds, TPS tracking.
-- Operates on world.time. TPS tracking fields live here — transient, not serialized.

local world = require("core.world")
local log   = require("core.log")

local time = {}

time.ticks_this_second = 0
time.ticks_last_second = 0

local real_time_acc = 0

local updateCalendar

function time.init()
    real_time_acc          = 0
    time.ticks_this_second = 0
    time.ticks_last_second = 0
end

function time.setSpeed(speed)
    world.time.speed = speed
end

function time.togglePause()
    world.time.is_paused = world.time.is_paused == false
end

function time.accumulate(dt)
    real_time_acc = real_time_acc + dt
    if real_time_acc >= 1.0 then
        real_time_acc          = real_time_acc - 1.0
        time.ticks_last_second = time.ticks_this_second
        time.ticks_this_second = 0
    end

    if world.time.is_paused then
        return 0
    end

    world.time.accumulator = world.time.accumulator + dt * TICK_RATE * world.time.speed
    local ticks = math.floor(world.time.accumulator)
    world.time.accumulator = world.time.accumulator - ticks
    return ticks
end

function time.advance()
    local prev_hour        = world.time.game_hour
    world.time.tick        = world.time.tick + 1
    time.ticks_this_second = time.ticks_this_second + 1
    updateCalendar()
    if world.time.game_hour ~= prev_hour then
        local world_time = world.time
        log:info("TIME", "Year %d  Season %d  Day %d  Hour %d",
            world_time.game_year, world_time.game_season, world_time.game_day, world_time.game_hour)
    end
end

function time.hashOffset(id)
    return (id * 7919) % HASH_INTERVAL
end

function time.getEnergyThresholds()
    local ticks_in_day = world.time.tick % TICKS_PER_DAY
    local frac_hour    = ticks_in_day / TICKS_PER_HOUR

    if frac_hour >= DAY_START and frac_hour < EVENING_START then
        return { soft = SleepConfig.day.soft, wake = SleepConfig.day.wake }
    elseif frac_hour < MORNING_START then
        return { soft = SleepConfig.night.soft, wake = SleepConfig.night.wake }
    elseif frac_hour < DAY_START then
        local t = (frac_hour - MORNING_START) / (DAY_START - MORNING_START)
        return {
            soft = SleepConfig.night.soft + t * (SleepConfig.day.soft  - SleepConfig.night.soft),
            wake = SleepConfig.night.wake + t * (SleepConfig.day.wake  - SleepConfig.night.wake),
        }
    else
        local t = (frac_hour - EVENING_START) / (HOURS_PER_DAY - EVENING_START)
        return {
            soft = SleepConfig.day.soft + t * (SleepConfig.night.soft - SleepConfig.day.soft),
            wake = SleepConfig.day.wake + t * (SleepConfig.night.wake - SleepConfig.day.wake),
        }
    end
end

function updateCalendar()
    local world_time    = world.time
    local total_minutes = math.floor(world_time.tick / TICKS_PER_MINUTE)
    world_time.game_minute      = total_minutes % MINUTES_PER_HOUR
    local total_hours   = math.floor(total_minutes / MINUTES_PER_HOUR)
    world_time.game_hour        = total_hours % HOURS_PER_DAY
    local total_days    = math.floor(total_hours / HOURS_PER_DAY)
    world_time.game_day         = (total_days % DAYS_PER_SEASON) + 1
    local total_seasons = math.floor(total_days / DAYS_PER_SEASON)
    world_time.game_season      = (total_seasons % SEASONS_PER_YEAR) + 1
    world_time.game_year        = math.floor(total_seasons / SEASONS_PER_YEAR) + 1
end

return time
