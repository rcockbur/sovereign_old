-- app/gamestate.lua
-- Stack-based state machine. Owns the stack mechanism only.

local gamestate = {}

local stack = {}

local top
local callHook

function gamestate:switch(state)
    if top() and top().exit then
        top().exit()
    end
    stack = {}
    stack[1] = state
    if state.enter then
        state.enter()
    end
end

function gamestate:push(state)
    if top() and top().exit then
        top().exit()
    end
    stack[#stack + 1] = state
    if state.enter then
        state.enter()
    end
end

function gamestate:pop()
    if top() and top().exit then
        top().exit()
    end
    stack[#stack] = nil
end

function gamestate:update(dt)
    callHook("update", dt)
end

function gamestate:draw()
    callHook("draw")
end

function gamestate:keypressed(key)
    callHook("keypressed", key)
end

function gamestate:mousepressed(x, y, button)
    callHook("mousepressed", x, y, button)
end

function top()
    return stack[#stack]
end

function callHook(name, ...)
    local state = top()
    if state and state[name] then
        state[name](...)
    end
end

return gamestate
