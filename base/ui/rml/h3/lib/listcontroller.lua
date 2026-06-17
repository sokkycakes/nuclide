--[[
  ListController — shared row-focus state machine (port of app.js ListController).
]]

local M = {}

local function set_class(el, class_name, on)
  if on then
    el:SetAttribute("class", class_name)
  else
    local c = el:GetAttribute("class") or ""
    c = c:gsub(class_name, ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    el:SetAttribute("class", c)
  end
end

local function add_class(el, token)
  local c = el:GetAttribute("class") or ""
  if not c:find(token, 1, true) then
    el:SetAttribute("class", (c == "" and token) or (c .. " " .. token))
  end
end

local function remove_class(el, token)
  local c = el:GetAttribute("class") or ""
  c = c:gsub(token, ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  el:SetAttribute("class", c)
end

local function toggle_class(el, token, on)
  if on then add_class(el, token) else remove_class(el, token) end
end

--- Create a list controller.
-- @param opts table with: document, items, wraps, item_class, build_row, mount, clear_mounts, on_confirm, on_focus_change
function M.new(opts)
  local document = opts.document
  local items = opts.items
  local wraps = opts.wraps
  local item_class = opts.item_class
  local focused_class = item_class .. "--focused"
  local disabled_class = item_class .. "--disabled"
  local build_row = opts.build_row
  local mount = opts.mount
  local clear_mounts = opts.clear_mounts
  local on_confirm = opts.on_confirm
  local on_focus_change = opts.on_focus_change

  local row_els = {}
  local focus = 1

  local function apply_focus()
    for i, li in ipairs(row_els) do
      toggle_class(li, focused_class, i == focus)
    end
    if on_focus_change then
      on_focus_change(focus, items[focus])
    end
  end

  local function make_row(i)
    local item = items[i]
    local li = document:CreateElement("li")
    li:SetAttribute("class", item_class)
    if item.disabled then
      add_class(li, disabled_class)
    end
    li:SetAttribute("data-index", tostring(i - 1))
    li:SetAttribute("data-id", item.id or "")

    local bar = document:CreateElement("img")
    bar:SetAttribute("class", "focus-bar")
    bar:SetAttribute("src", "assets/buttonhover.png")
    li:AppendChild(bar)

    build_row(li, item, document)

    return li
  end

  local ctrl = {}

  function ctrl.build()
    clear_mounts()
    row_els = {}
    for i = 1, #items do
      local li = make_row(i)
      row_els[i] = li
      mount(li, i)
    end
    if focus > #items then focus = math.max(1, #items) end
    apply_focus()
  end

  function ctrl.set_focus(i)
    i = math.floor(i)
    if i < 1 or i > #items or focus == i then return end
    focus = i
    apply_focus()
  end

  function ctrl.move_focus(delta)
    local next_i
    if wraps then
      next_i = ((focus - 1 + delta) % #items) + 1
    else
      next_i = math.max(1, math.min(#items, focus + delta))
    end
    ctrl.set_focus(next_i)
  end

  function ctrl.confirm()
    local item = items[focus]
    if item.disabled then
      local row = row_els[focus]
      if row then
        add_class(row, "is-shake")
        opts.timers.set_timeout(function()
          remove_class(row, "is-shake")
        end, 200)
      end
      return
    end
    on_confirm(item)
  end

  function ctrl.apply_focus()
    apply_focus()
  end

  function ctrl.reset()
    focus = 1
    apply_focus()
  end

  function ctrl.get_focus()
    return focus
  end

  function ctrl.get_items()
    return items
  end

  function ctrl.get_row_els()
    return row_els
  end

  return ctrl
end

return M
