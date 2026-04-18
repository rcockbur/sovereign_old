-- tests/run.lua
-- Run with: lua tests/run.lua (from repo root)

package.path = "./src/?.lua;./tests/?.lua;" .. package.path

require("core.util")
require("config.constants")
require("config.keybinds")
require("config.tables")

local test_files = {
    require("test_pathfinding"),
    require("test_resources"),
}

local passed = 0
local failed = 0

for _, tests in ipairs(test_files) do
    for _, entry in ipairs(tests) do
        local name = entry[1]
        local fn   = entry[2]
        local ok, err = pcall(fn)
        if ok then
            passed = passed + 1
            print("PASS  " .. name)
        else
            failed = failed + 1
            print("FAIL  " .. name .. "\n      " .. tostring(err))
        end
    end
end

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
