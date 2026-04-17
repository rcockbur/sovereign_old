-- app/loading.lua
-- Transient startup state. Runs config validation then switches to main menu.

local gamestate  = require("app.gamestate")
local main_menu  = require("app.main_menu")

local loading = {}

function loading.enter()
    -- Config validation stubs (full validation added in M02)
    gamestate:switch(main_menu)
end

return loading
