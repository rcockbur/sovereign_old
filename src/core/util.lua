-- core/util.lua
-- Pure utility functions with no game concepts. Loaded as globals via main.lua.

-- Tile coordinate helpers (MAP_HEIGHT is a global set in config/constants.lua)
function tileIndex(x, y)
    return (x - 1) * MAP_HEIGHT + y
end

function tileXY(index)
    local x = math.floor((index - 1) / MAP_HEIGHT) + 1
    local y = (index - 1) % MAP_HEIGHT + 1
    return x, y
end

-- Shallow-safe recursive copy of a table. No cycle detection — not needed for
-- the flat/nested-but-acyclic tables this project copies (e.g. resource_counts).
function table.deepCopy(t)
    if type(t) ~= "table" then
        return t
    end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = table.deepCopy(v)
    end
    return copy
end
