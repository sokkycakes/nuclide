--[[
  Frame-driven timers (setTimeout / setInterval) for LuaRmlUi hosts that
  call Timers.update(dt) once per frame from main.lua.
]]

local Timers = {}
local queue = {}
local next_id = 1

--- Schedule a one-shot callback after `delay_ms` milliseconds.
function Timers.set_timeout(fn, delay_ms)
  local id = next_id
  next_id = next_id + 1
  queue[id] = {
    fn = fn,
    remaining = delay_ms / 1000.0,
    interval = nil,
    alive = true,
  }
  return id
end

--- Schedule a repeating callback every `interval_ms` milliseconds.
function Timers.set_interval(fn, interval_ms)
  local id = next_id
  next_id = next_id + 1
  queue[id] = {
    fn = fn,
    remaining = interval_ms / 1000.0,
    interval = interval_ms / 1000.0,
    alive = true,
  }
  return id
end

function Timers.clear(id)
  if queue[id] then
    queue[id].alive = false
    queue[id] = nil
  end
end

--- Advance all timers by `dt` seconds (typically Host_GetElapsedTime).
function Timers.update(dt)
  local fired = {}
  for id, t in pairs(queue) do
    if t.alive then
      t.remaining = t.remaining - dt
      if t.remaining <= 0 then
        table.insert(fired, t)
        if t.interval then
          t.remaining = t.interval
        else
          t.alive = false
          queue[id] = nil
        end
      end
    end
  end
  for _, t in ipairs(fired) do
    if t.alive or t.interval then
      t.fn()
    end
  end
end

return Timers
