-- core/log.lua
-- Ring buffer logger with severity levels, categories, and file output.
-- Call log:init() once at startup before logging anything.

local log = {}

local LEVEL_ERROR = 1
local LEVEL_WARN  = 2
local LEVEL_INFO  = 3
local LEVEL_DEBUG = 4

local LEVEL_NAMES = { "ERROR", "WARN", "INFO", "DEBUG" }

local VALID_CATEGORIES = {
    TIME = true, UNIT = true, ACTIVITY = true, WORLD = true,
    HEALTH = true, HAUL = true, SAVE = true, STATE = true,
}

local RING_SIZE    = 200
local MAX_LOG_FILES = 20

local ring       = {}
local ring_head  = 0
local ring_count = 0

local overlay_severity = LEVEL_INFO
local file_severity    = LEVEL_DEBUG
local log_filename     = nil
local current_filename = "logs/current.log"

local writeEntry
local logAt

function log:init()
    love.filesystem.createDirectory("logs")

    local files = love.filesystem.getDirectoryItems("logs")
    local log_files = {}
    for _, filename in ipairs(files) do
        if filename:match("%.log$") then
            log_files[#log_files + 1] = filename
        end
    end
    table.sort(log_files)
    while #log_files >= MAX_LOG_FILES do
        love.filesystem.remove("logs/" .. log_files[1])
        table.remove(log_files, 1)
    end

    log_filename = "logs/" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".log"
    log.filepath = love.filesystem.getSaveDirectory() .. "/" .. current_filename
    love.filesystem.write(log_filename, "")
    love.filesystem.write(current_filename, "")
end

function log:error(category, fmt, ...) logAt(LEVEL_ERROR, category, fmt, ...) end
function log:warn(category, fmt, ...)  logAt(LEVEL_WARN,  category, fmt, ...) end
function log:info(category, fmt, ...)  logAt(LEVEL_INFO,  category, fmt, ...) end
function log:debug(category, fmt, ...) logAt(LEVEL_DEBUG, category, fmt, ...) end

function log:getRecent(n)
    local count = math.min(n, ring_count)
    local result = {}
    for i = 1, count do
        local idx = ((ring_head - i) % RING_SIZE) + 1
        result[i] = ring[idx]
    end
    return result
end

function logAt(level, category, fmt, ...)
    assert(VALID_CATEGORIES[category], "Unknown log category: " .. tostring(category))
    writeEntry(level, category, string.format(fmt, ...))
end

function writeEntry(level, category, message)
    if level > file_severity and level > overlay_severity then
        return
    end

    local entry = string.format("[%s][%s][%s] %s",
        os.date("%H:%M:%S"), LEVEL_NAMES[level], category, message)

    if level <= overlay_severity then
        ring_head = ring_head % RING_SIZE + 1
        ring[ring_head] = entry
        if ring_count < RING_SIZE then
            ring_count = ring_count + 1
        end
    end

    if level <= file_severity and log_filename then
        love.filesystem.append(log_filename, entry .. "\n")
        love.filesystem.append(current_filename, entry .. "\n")
    end
end

return log
