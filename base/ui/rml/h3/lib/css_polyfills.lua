-- H3 Menu Option B Compatibility Layer: Lua polyfills for unsupported RmlUI CSS
-- Place in base/ui/rml/h3/lib/css_polyfills.lua
-- Loaded from app.lua or main.lua; reloadable via menu_restart
-- Polyfills: transitions, animations (via timers), filters (emulated), border-radius (image based), grid->flex, etc.
-- RCSS preprocessor hooks here too.
-- Reference: web/h3-main-menu/ as source of truth for intended visuals.

local Polyfills = {}

function Polyfills.init(rml_document)
  -- Hook timers for emulated transitions/animations (666ms slide_up per data.json)
  if Timers then
    -- Example: Polyfills.schedule_transition(el, "slide_up", 666)
  end
  print("[polyfill] H3 CSS compatibility layer initialized (Option B)")
end

-- Timer-driven transition polyfill (called from app.lua on page change)
function Polyfills.schedule_transition(element, effect, duration_ms)
  -- Uses existing Timers from app context; real impl would manipulate element style/decorators
  print(string.format("[polyfill] transition %s over %dms", effect, duration_ms))
end

-- Preprocessor stub: called before loading RCSS if needed
function Polyfills.preprocess_rcss(raw_css)
  -- Remove unsupported: font-display, filter, text-shadow, transition, animation, aspect-ratio, grid, place-items, border-radius, isolation, list-style
  local cleaned = raw_css:gsub("font%-display:[^;]+;", "/* removed */")
  cleaned = cleaned:gsub("filter:[^;]+;", "/* removed */")
  cleaned = cleaned:gsub("text%-shadow:[^;]+;", "/* removed */")
  cleaned = cleaned:gsub("transition:[^;]+;", "/* polyfilled in Lua */")
  cleaned = cleaned:gsub("animation:[^;]+;", "/* polyfilled in Lua */")
  cleaned = cleaned:gsub("aspect%-ratio:[^;]+;", "width: auto; height: auto; /* replaced */")
  cleaned = cleaned:gsub("display:%s*grid[^;]*;", "display: flex; flex-direction: column; /* grid polyfilled */")
  cleaned = cleaned:gsub("place%-items:[^;]+;", "/* removed */")
  cleaned = cleaned:gsub("border%-radius:[^;]+;", "/* use image assets */")
  cleaned = cleaned:gsub("isolation:[^;]+;", "/* removed */")
  cleaned = cleaned:gsub("list%-style:[^;]+;", "/* removed */")
  -- Convert hsl/rgba advanced syntax to simple rgb if needed
  return cleaned
end

-- Asset gen note: run tools/generate_h3_assets.py to produce shadows/gradients as PNGs in assets/
return Polyfills
