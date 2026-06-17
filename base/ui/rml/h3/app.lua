--[[
  Halo 3 main menu — RmlUI logic layer (port of web/h3-main-menu/app.js).
]]

local ListController = require("lib.listcontroller")
local data = require("data")
local Polyfills = require("lib.css_polyfills")

local SLOWMO_FACTOR = 1
local TRANSITION_MS = math.floor(666 * SLOWMO_FACTOR)

local App = {}
local Timers
local document
local screen_el
local page_main
local page_lobby
local main_list
local lobby_list
local lobby_mode
local current_page = "main_menu"
local active_list
local transitioning = false
local online = false

local ROSTER_SLOT_COUNT = 16
local initial_roster = {
  { name = "Player 1", serviceTag = "PL1", state = "filled", focused = true, leader = true },
}

-- ---------------------------------------------------------------------------
-- DOM helpers
-- ---------------------------------------------------------------------------

local function $(id)
  return document:GetElementById(id)
end

local function show(el)
  if el then el.style.display = "block" end
end

local function hide(el)
  if el then el.style.display = "none" end
end

local function set_text(el, text)
  if el then el.inner_rml = text or "" end
end

-- ---------------------------------------------------------------------------
-- Button keys
-- ---------------------------------------------------------------------------

local function render_button_keys(bar_el, prompts)
  if not bar_el then return end
  while bar_el.first_child do
    bar_el:RemoveChild(bar_el.first_child)
  end
  for _, p in ipairs(prompts) do
    local wrap = document:CreateElement("span")
    wrap:SetAttribute("class", "button-key")
    local glyph = document:CreateElement("span")
    glyph:SetAttribute("class", "button-key__glyph")
    glyph:SetAttribute("data-glyph", p.glyph)
    glyph.inner_rml = p.glyph
    local lbl = document:CreateElement("span")
    lbl.inner_rml = p.label
    wrap:AppendChild(glyph)
    wrap:AppendChild(lbl)
    bar_el:AppendChild(wrap)
  end
end

local function render_main_button_keys()
  local which = online and "main_menu_online" or "main_menu_offline"
  render_button_keys($("button-keys"), data.button_keys[which])
end

local function render_lobby_button_keys()
  render_button_keys($("lobby-button-keys"), data.pregame_lobbies.template.button_keys)
end

-- ---------------------------------------------------------------------------
-- Roster
-- ---------------------------------------------------------------------------

local function update_player_count()
  local list = $("lobby-roster-list")
  local count_el = $("lobby-players-count")
  local max_el = $("lobby-players-max")
  if not list or not count_el or not max_el then return end
  local filled = 0
  local child = list.first_child
  while child do
    if child:GetAttribute("data-state") ~= "empty" then
      filled = filled + 1
    end
    child = child.next_sibling
  end
  set_text(count_el, tostring(filled))
  set_text(max_el, tostring(ROSTER_SLOT_COUNT))
end

local function build_roster_slots()
  local list = $("lobby-roster-list")
  if not list then return end
  while list.first_child do
    list:RemoveChild(list.first_child)
  end

  for i = 1, ROSTER_SLOT_COUNT do
    local seed = initial_roster[i]
    local li = document:CreateElement("li")
    li:SetAttribute("class", "roster-slot")
    li:SetAttribute("data-index", tostring(i - 1))
    li:SetAttribute("data-state", seed and (seed.state or "filled") or "empty")
    li:SetAttribute("data-focused", seed and seed.focused and "true" or "false")
    li:SetAttribute("data-leader", seed and seed.leader and "true" or "false")
    li:SetAttribute("data-speaking", "false")

    local base = document:CreateElement("span")
    base:SetAttribute("class", "roster-slot__base")
    li:AppendChild(base)

    local name_el = document:CreateElement("span")
    name_el:SetAttribute("class", "roster-slot__name")
    name_el.inner_rml = seed and seed.name or ""
    li:AppendChild(name_el)

    local tag_el = document:CreateElement("span")
    tag_el:SetAttribute("class", "roster-slot__service-tag")
    tag_el.inner_rml = seed and (seed.serviceTag or "") or ""
    li:AppendChild(tag_el)

    local prompt = document:CreateElement("span")
    prompt:SetAttribute("class", "roster-slot__empty-prompt")
    prompt.inner_rml = "PRESS A TO JOIN"
    li:AppendChild(prompt)

    list:AppendChild(li)
  end
  update_player_count()
end

-- ---------------------------------------------------------------------------
-- Lobby list
-- ---------------------------------------------------------------------------

local function build_lobby_list(mode)
  local cfg = data.pregame_lobbies.modes[mode]
  set_text($("lobby-title"), cfg.title)
  set_text($("lobby-status"), cfg.lobby_status)
  set_text($("lobby-game-name"), cfg.game_name)
  page_lobby:SetAttribute("data-show-preview", cfg.show_preview and "true" or "false")

  local preview_targets = { level = true, variant = true, map = true, film = true, hopper = true }
  local game_item
  for _, it in ipairs(cfg.items) do
    if preview_targets[it.target] then
      game_item = it
      break
    end
  end
  set_text($("lobby-preview-gametype"), (game_item and game_item.value) or cfg.title)

  local lobby_list_el = $("lobby-list")
  lobby_list = ListController.new({
    document = document,
    timers = Timers,
    items = cfg.items,
    wraps = true,
    item_class = "lobby-list__item",
    build_row = function(li, item, doc)
      if item.id == "start_game" then
        local c = li:GetAttribute("class") or ""
        li:SetAttribute("class", c .. " lobby-list__item--separated")
      end
      local name = doc:CreateElement("span")
      name:SetAttribute("class", "lobby-list__name")
      name.inner_rml = item.label
      li:AppendChild(name)
      if item.value and item.value ~= "" then
        local sep = doc:CreateElement("span")
        sep:SetAttribute("class", "lobby-list__sep")
        sep.inner_rml = ": "
        li:AppendChild(sep)
        local val = doc:CreateElement("span")
        val:SetAttribute("class", "lobby-list__value")
        val.inner_rml = item.value
        li:AppendChild(val)
      end
    end,
    mount = function(li)
      lobby_list_el:AppendChild(li)
    end,
    clear_mounts = function()
      while lobby_list_el.first_child do
        lobby_list_el:RemoveChild(lobby_list_el.first_child)
      end
    end,
    on_confirm = function(item)
      if item.id == "switch_lobby" then
        App.back()
        return
      end
      if item.id == "start_game" then
        App.open_overlay({
          title = "STARTING GAME",
          tag = "mode=" .. mode .. " -> " .. cfg.game_name,
        })
        return
      end
      local title = item.label
      if item.target then
        title = title .. " (" .. item.target .. ")"
      end
      App.open_overlay({
        title = string.upper(title),
        tag = cfg.datasource .. ".dsrc -> " .. item.id,
      })
    end,
    on_focus_change = function(idx, item)
      set_text($("dbg-focus"), string.format("%d (%s)", idx - 1, item.id))
    end,
  })
  lobby_list.build()
end

-- ---------------------------------------------------------------------------
-- Page transitions
-- ---------------------------------------------------------------------------

local function play_animation(root_el, class_name, done_cb)
  local finished = false
  local function finish()
    if finished then return end
    finished = true
    root_el:RemoveEventListener("animationend", on_end, false)
    local c = root_el:GetAttribute("class") or ""
    c = c:gsub(class_name, ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    root_el:SetAttribute("class", c)
    if done_cb then done_cb() end
  end
  local function on_end(ev)
    if ev.target ~= root_el then return end
    finish()
  end
  local c = root_el:GetAttribute("class") or ""
  if not c:find(class_name, 1, true) then
    root_el:SetAttribute("class", (c == "" and class_name) or (c .. " " .. class_name))
  end
  root_el:AddEventListener("animationend", on_end, false)
  Timers.set_timeout(finish, TRANSITION_MS + 150)
end

local function show_page(target_page, opts)
  opts = opts or {}
  if transitioning then return end
  if target_page == current_page then return end

  local from_page = current_page
  local from_el = (from_page == "main_menu") and page_main or page_lobby
  local to_el = (target_page == "main_menu") and page_main or page_lobby
  if not from_el or not to_el then return end

  transitioning = true

  if target_page == "pregame_lobby" then
    lobby_mode = opts.mode
    screen_el:SetAttribute("data-lobby-mode", opts.mode or "")
    build_lobby_list(opts.mode)
    render_lobby_button_keys()
  elseif target_page == "main_menu" then
    lobby_mode = nil
    screen_el:SetAttribute("data-lobby-mode", "")
  end

  show(to_el)

  local pending = 2
  local function one_done()
    pending = pending - 1
    if pending > 0 then return end
    hide(from_el)
    local fc = from_el:GetAttribute("class") or ""
    fc = fc:gsub("is%-leaving", ""):gsub("is%-entering", ""):gsub("%s+", " ")
    from_el:SetAttribute("class", fc)
    local tc = to_el:GetAttribute("class") or ""
    tc = tc:gsub("is%-leaving", ""):gsub("is%-entering", ""):gsub("%s+", " ")
    to_el:SetAttribute("class", tc)

    current_page = target_page
    screen_el:SetAttribute("data-screen", target_page)
    set_text($("dbg-screen"), target_page)

    if target_page == "main_menu" then
      active_list = main_list
      main_list.apply_focus()
    else
      active_list = lobby_list
    end
    transitioning = false
  end

  play_animation(from_el, "is-leaving", one_done)
  play_animation(to_el, "is-entering", one_done)
end

-- ---------------------------------------------------------------------------
-- Navigation
-- ---------------------------------------------------------------------------

function App.navigate_to(destination)
  if destination == "_quit" then
    document.body.style.opacity = "0"
    Timers.set_timeout(function()
      document.body.style.opacity = "1"
    end, 1200)
    return
  end

  if destination:sub(1, 14) == "pregame_lobby_" then
    local mode = destination:sub(15)
    if data.pregame_lobbies.modes[mode] then
      show_page("pregame_lobby", { mode = mode })
      set_text($("dbg-nav"), destination)
      return
    end
  end

  local tag = data.navigation_table[destination] or "(no widget tag - engine-side)"
  App.open_overlay({
    title = destination:gsub("_", " "):upper(),
    tag = tag .. ".scn3",
  })
  set_text($("dbg-nav"), destination)
end

function App.open_overlay(opts)
  set_text($("overlay-title"), opts.title)
  set_text($("overlay-tag"), opts.tag)
  show($("submenu-overlay"))
end

function App.close_overlay()
  hide($("submenu-overlay"))
  set_text($("dbg-nav"), "-")
end

function App.back()
  local overlay = $("submenu-overlay")
  if overlay and overlay.style.display ~= "none" then
    App.close_overlay()
    return
  end
  if current_page == "pregame_lobby" then
    show_page("main_menu")
  end
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

local function key_matches(event, ...)
  local kid = event.parameters.key_identifier
  if kid == nil then return false end
  for i = 1, select("#", ...) do
    local want = select(i, ...)
    if kid == want or kid == string.lower(want) or kid == string.upper(want) then
      return true
    end
  end
  return false
end

local KI = nil
local function bind_keys(rmlui_mod)
  if rmlui_mod and rmlui_mod.key_identifier then
    KI = rmlui_mod.key_identifier
  end
end

local function on_keydown(event)
  if key_matches(event, "`", "KI_GRAVE", "GRAVE") then
    local dbg = $("debug")
    if dbg.style.display == "none" then show(dbg) else hide(dbg) end
    event:StopPropagation()
    return
  end

  if transitioning then
    event:StopPropagation()
    return
  end

  local up = KI and (event.parameters.key_identifier == KI.UP) or key_matches(event, "UP", "KI_UP")
  local down = KI and (event.parameters.key_identifier == KI.DOWN) or key_matches(event, "DOWN", "KI_DOWN")
  local confirm = KI and (event.parameters.key_identifier == KI.RETURN or event.parameters.key_identifier == KI.SPACE)
    or key_matches(event, "RETURN", "ENTER", "SPACE", "A")
  local back = KI and (event.parameters.key_identifier == KI.ESCAPE) or key_matches(event, "ESCAPE", "B")
  local x_key = key_matches(event, "X")
  local y_key = key_matches(event, "Y")

  if up or key_matches(event, "w", "W") then
    active_list.move_focus(-1)
    event:StopPropagation()
  elseif down or key_matches(event, "s", "S") then
    active_list.move_focus(1)
    event:StopPropagation()
  elseif confirm then
    active_list.confirm()
    event:StopPropagation()
  elseif back then
    App.back()
    event:StopPropagation()
  elseif x_key then
    App.navigate_to("start_menu_settings")
    event:StopPropagation()
  elseif y_key then
    if current_page == "pregame_lobby" then
      App.open_overlay({
        title = "ROSTER",
        tag = "ui\\halox\\common\\roster\\roster.grup",
      })
    elseif online then
      App.navigate_to("start_menu_hq")
    end
    event:StopPropagation()
  end
end

-- ---------------------------------------------------------------------------
-- Main menu list
-- ---------------------------------------------------------------------------

local function filter_main_items()
  local out = {}
  for _, it in ipairs(data.list.items) do
    if not it.hidden_by_default then
      table.insert(out, it)
    end
  end
  return out
end

local function build_main_list()
  local primary_el = $("menu-primary")
  local main_list_el = $("mainmenu-list")

  main_list = ListController.new({
    document = document,
    timers = Timers,
    items = filter_main_items(),
    wraps = data.list.wraps,
    item_class = "mainmenu-list__item",
    build_row = function(li, item, doc)
      local label = doc:CreateElement("span")
      label.inner_rml = item.label
      li:AppendChild(label)
    end,
    mount = function(li, i)
      if i == 1 then
        primary_el:AppendChild(li)
      else
        main_list_el:AppendChild(li)
      end
    end,
    clear_mounts = function()
      while primary_el.first_child do primary_el:RemoveChild(primary_el.first_child) end
      while main_list_el.first_child do main_list_el:RemoveChild(main_list_el.first_child) end
    end,
    on_confirm = function(item)
      App.navigate_to(item.destination)
    end,
    on_focus_change = function(idx, item)
      set_text($("dbg-focus"), string.format("%d (%s)", idx - 1, item.id))
    end,
  })
  main_list.build()
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------

function App.init(doc, _context, timers_mod, rmlui_mod)
  if App._initialized then return end
  App._initialized = true

  document = doc
  Timers = timers_mod
  bind_keys(rmlui_mod)
  Polyfills.init(doc) -- Option B compatibility layer

  screen_el = $("screen")
  page_main = $("page-main")
  page_lobby = $("page-lobby")

  local title_logo = $("title-logo")
  local bungie_logo = $("bungie-logo")
  if title_logo then title_logo:SetAttribute("src", data.right_group_chrome.title_bitmap) end
  if bungie_logo then bungie_logo:SetAttribute("src", data.right_group_chrome.bungie_bitmap) end
  set_text($("build-text"), "build 12070.07.10.18.2128.delta")
  set_text($("version-text"), "version 1.0")

  build_main_list()
  render_main_button_keys()
  build_roster_slots()

  active_list = main_list
  current_page = "main_menu"
  set_text($("dbg-screen"), current_page)

  document:AddEventListener("keydown", on_keydown, false)

  local overlay = $("submenu-overlay")
  if overlay then
    overlay:AddEventListener("click", function()
      App.close_overlay()
    end, false)
  end

  print("[h3-main-menu-rml] Loaded; lobby modes: " .. table.concat({
    "campaign", "matchmaking", "multiplayer", "mapeditor", "theater"
  }, ", "))
end

return App
