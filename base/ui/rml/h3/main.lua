--[[
  LuaRmlUi entrypoint for Halo 3 main menu (RmlUI native).

  Run from this directory (paths are relative to the process cwd):

    luarmlui main.lua

  Or point your LuaRmlUi host at main.lua and ensure package.path includes
  this folder. The returned function must be called each frame with dt in
  seconds so lib/timers.lua can fire callbacks.
]]

local function script_dir()
  local src = debug.getinfo(1, "S").source
  if src:sub(1, 1) == "@" then src = src:sub(2) end
  return src:match("^(.*)[/\\][^/\\]+$") or "."
end

local DIR = script_dir()
package.path = table.concat({
  DIR .. "/?.lua",
  DIR .. "/lib/?.lua",
  package.path,
}, ";")

local Timers = require("lib.timers")
local App = require("app")

local rmlui = require("rmlui")
local context_name = "main"
local context = rmlui.contexts[context_name]
if not context then
  context = rmlui.CreateContext(context_name)
end

-- Font: Conduit-ITC.ttf is IosevkaStiletto fallback until a real Conduit TTF is supplied.
local font_path = DIR .. "/assets/Conduit-ITC.ttf"
context:LoadFontFace(font_path)

local doc = context:LoadDocument(DIR .. "/main.rml")
if not doc then
  error("Failed to load main.rml from " .. DIR)
end
doc:Show()

App.init(doc, context, Timers, rmlui)

print("[h3-main-menu-rml] Document shown. Pump returned update(dt) each frame.")

return function(dt)
  Timers.update(dt)
end
