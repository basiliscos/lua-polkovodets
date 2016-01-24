--[[

Copyright (C) 2016 Ivan Baidakou

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

]]--

local inspect = require('inspect')
local _ = require ("moses")

local HorizontalPanel = require ('polkovodets.gui.HorizontalPanel')
local Image = require 'polkovodets.utils.Image'

local UnitInfoWindow = {}
UnitInfoWindow.__index = UnitInfoWindow
setmetatable(UnitInfoWindow, HorizontalPanel)

local TTILE_FONT_SIZE = 16
local DEFAULT_FONT_SIZE = 12
local DEFAULT_COLOR = 0xAAAAAA

function UnitInfoWindow.create(engine, data)
  local o = HorizontalPanel.create(engine)
  setmetatable(o, UnitInfoWindow)
  o.drawing.content_fn = nil
  o.content = {}
  o.unit = assert(data)
  return o
end

function UnitInfoWindow:_render_string(label, color)
  local engine = self.engine
  local font = engine.renderer.theme:get_font('default', DEFAULT_FONT_SIZE)
  local image = Image.create(
    engine.renderer.sdl_renderer,
    font:renderUtf8(label, "solid", color)
  )
  return image
end

function UnitInfoWindow:_construct_info_tab()
  local engine = self.engine
  local unit = self.unit
  local font = engine.renderer.theme:get_font('default', DEFAULT_FONT_SIZE)
  local all = {}
  local tab_data = {
    all       = all,
    active    = all,
    r_aligned = {},
    icon      = {
      hint    = engine:translate('ui.unit-info.tab.info.hint'),
      current = 'available',
      states  = engine.renderer.theme.tabs.info,
    },
    mouse_click = function(event) end,
    mouse_move = function(event) end,
  }

  local dx, dy = 0, 0

  -- definition name
  local definition_name = Image.create(
    engine.renderer.sdl_renderer,
    font:renderUtf8(unit.definition.data.name, "solid", DEFAULT_COLOR)
  )
  table.insert(tab_data.all, {
    dx = dx,
    dy = dy,
    image = definition_name,
  })

  local max_label_x = 0
  local add_row = function(key, value)
    local label = Image.create(
      engine.renderer.sdl_renderer,
      font:renderUtf8(engine:translate(key), "solid", DEFAULT_COLOR)
    )
    table.insert(tab_data.all, {
      dx = dx,
      dy = tab_data.all[#tab_data.all].dy + tab_data.all[#tab_data.all].image.h + 5,
      image = label,
    })
    local value_img = self:_render_string(value, DEFAULT_COLOR);
    local value_descr = {
      dx = tab_data.all[#tab_data.all].dx + tab_data.all[#tab_data.all].image.w + 15,
      dy = tab_data.all[#tab_data.all].dy,
      image = value_img,
    }
    max_label_x = math.max(max_label_x, value_descr.dx)
    table.insert(all, value_descr)
    table.insert(tab_data.r_aligned, value_descr)
  end

  -- unit definition info
  add_row('ui.unit-info.size', engine:translate('db.unit.size.' .. unit.definition.data.size))
  add_row('ui.unit-info.class', engine:translate('db.unit-class.' .. unit.definition.unit_class.id))
  add_row('ui.unit-info.spotting', tostring(unit.definition.data.spotting))
  -- unit info
  add_row('ui.unit-info.experience', tostring(unit.data.experience))
  if (unit.definition.unit_class['type'] == 'ut_land') then
    add_row('ui.unit-info.entrenchement', tostring(unit.data.entr))
  end
  add_row('ui.unit-info.state', engine:translate('db.unit.state.' .. unit.data.state))
  add_row('ui.unit-info.orientation', engine:translate('db.unit.orientation.' .. unit.data.orientation))

  -- re-allign r-aligned labels (values) to the same right-most border
  _.each(tab_data.r_aligned, function(idx, e)
    e.dx = max_label_x
  end)

  return tab_data
end

function UnitInfoWindow:_construct_attachments_tab()
  local engine = self.engine
  local unit = self.unit
  if (#unit.data.attached > 0) then
    local font = engine.renderer.theme:get_font('default', DEFAULT_FONT_SIZE)
    local all = {}
    local tab_data = {
      all       = all,
      active    = all,
      r_aligned = {},
      icon      = {
        hint    = engine:translate('ui.unit-info.tab.attachments.hint'),
        current = 'available',
        states  = engine.renderer.theme.tabs.attachments,
      },
      mouse_click = function(event) end,
      mouse_move = function(event) end,
    }
    local dx, dy = 0, 0
    for idx, attached_unit in ipairs(unit.data.attached) do
      local definition_name = self:_render_string(attached_unit.name, DEFAULT_COLOR)
      table.insert(tab_data.all, {
        dx = dx,
        dy = dy,
        image = definition_name,
      })
      local unit_flag = attached_unit.definition.nation.unit_flag
      table.insert(tab_data.all, {
        dx = dx + definition_name.w + 5,
        dy = dy + math.modf(definition_name.h/2 - unit_flag.h/2),
        image = unit_flag,
      })
      dy = dy + definition_name.h + 5
    end
    return tab_data
  end
end

function UnitInfoWindow:_construct_management_tab()
  local engine = self.engine
  local unit = self.unit
  local k, manage_level = unit:is_capable('MANAGE_LEVEL')
  if (not manage_level) then
    local font = engine.renderer.theme:get_font('default', DEFAULT_FONT_SIZE)
    local all = {}
    local tab_data = {
      all       = all,
      active    = all,
      r_aligned = {},
      icon      = {
        hint    = engine:translate('ui.unit-info.tab.management.hint'),
        current = 'available',
        states  = engine.renderer.theme.tabs.attachments,
      },
      mouse_click = function(event) end,
      mouse_move = function(event) end,
    }
    -- create list of manager units, the top-level managers come last
    local manager_units = {}
    local manager_unit = unit
    while (manager_unit.data.managed_by and (manager_unit.id ~= manager_unit.data.managed_by)) do
      manager_unit = engine:get_unit(manager_unit.data.managed_by)
      table.insert(manager_units, manager_unit)
    end
    -- table.remove(manager_units, #manager_unit)

    local dx, dy = 0, 0
    for idx, manager_unit in ipairs(manager_units) do
      local definition_name = self:_render_string(manager_unit.name, DEFAULT_COLOR)
      table.insert(tab_data.all, {
        dx = dx,
        dy = dy,
        image = definition_name,
      })
      local unit_flag = manager_unit.definition.nation.unit_flag
      table.insert(tab_data.all, {
        dx = dx + definition_name.w + 5,
        dy = dy + math.modf(definition_name.h/2 - unit_flag.h/2),
        image = unit_flag,
      })
      dy = dy + definition_name.h + 5
    end
    return tab_data
  end
end

function UnitInfoWindow:_construct_weapon_tabs()
  local engine = self.engine
  local font = engine.renderer.theme:get_font('default', DEFAULT_FONT_SIZE)
  local class_presents = {} -- k: class_id, value: boolean
  local unit = self.unit

  local wi_for_class = {} -- k: class_id, v: array of weapon instances
  -- fetch available classes & related weapon instances
  _.each(unit.data.staff, function(idx, wi)
    local class = wi:get_class()
    class_presents[class.id] = true
    local wi_list = wi_for_class[class.id] or {}
    table.insert(wi_list, wi)
    wi_for_class[class.id] = wi_list
  end)

  -- get classes in the correct order
  local classes = _.select(engine.unit_lib.weapons.classes.list, function(idx, class)
    return class_presents[class.id]
  end)

  local tabs = _.map(classes, function(idx, class)
    local icon_states = {}
    _.each({'active', 'available', 'hilight'}, function(idx, style)
      icon_states[style] = class:get_icon(style)
    end)
    local all = {}
    local tab_data = {
      all       = all,
      active    = all,
      r_aligned = {},
      icon      = {
        hint    = engine:translate('db.weapon-class.' .. class.id),
        current = 'available',
        states  = icon_states,
      },
      mouse_click = function(event) end,
      mouse_move = function(event) end,
    }
    -- render per weapon instance: weapon name and available quantity
    local dx, dy = 0, 0
    local weapon_instances = wi_for_class[class.id]
    for idx, wi in ipairs(weapon_instances) do
      local name = self:_render_string(wi.weapon.name, DEFAULT_COLOR)
      table.insert(tab_data.all, {
        dx = dx,
        dy = dy,
        image = name,
      })
      local quantity = self:_render_string(tostring(wi.data.quantity), DEFAULT_COLOR)
      local quantity_desc = {
        dx = dx + name.w + 5,
        dy = dy,
        image = quantity,
      }
      table.insert(tab_data.all, quantity_desc)
      table.insert(tab_data.r_aligned, quantity_desc)
      dy = dy + name.h + 5
    end
    return tab_data
  end)


  return tabs
end


function UnitInfoWindow:_construct_gui()
  local engine = self.engine
  local unit = self.unit

  local elements = {}

  --[[ header start ]]--
  -- flag
  local flag = unit.definition.nation.flag
  table.insert(elements, {
    dx    = 5,
    dy    = 0,
    image = flag,
  })

  -- title (unit name)
  local title_font = engine.renderer.theme:get_font('default', TTILE_FONT_SIZE)
  local title = Image.create(
    engine.renderer.sdl_renderer,
    title_font:renderUtf8(unit.name, "solid", DEFAULT_COLOR)
  )
  table.insert(elements, {
    dx    = elements[#elements].dx + elements[#elements].image.w + 5,
    dy    = 0,
    image = title,
  })

  local max_w = elements[#elements].dx + elements[#elements].image.w + 5
  local max_h = math.max(title.h, flag.h)
  -- reposition title/flag to be on the same Y-center
  _.each(elements, function(idx, e)
    e.dy = math.modf((max_h - e.image.h) / 2)
  end)

  local dy = max_h + 10
  local dx = 10
  --[[ header end ]]--

  local padding = dx -- l and r padding
  local tabs = {}
  local max_tab_w, max_tab_h = 0, 0
  local add_tab = function(tab)
    if (tab) then
      table.insert(tabs, tab)
      local w = _.max(tab.all, function(e)
        return e.dx + e.image.w
      end)
      local h = _.max(tab.all, function(e)
        return e.dy + e.image.h
      end)
      max_tab_w = math.max(max_tab_w, (w or 0) + padding * 2)
      max_tab_h = math.max(max_tab_h, h or 0)
    end
  end

  add_tab(self:_construct_info_tab())
  add_tab(self:_construct_attachments_tab())
  add_tab(self:_construct_management_tab())
  _.each(self:_construct_weapon_tabs(), function(idx, tab)
    add_tab(tab)
  end)

  -- post-process tabs: adjust tab icons, dx, dy for all elements,
  local tab_icon_dx, tab_icon_dy = dx, dy
  local tab_line = 4 + tabs[1].icon.states[tabs[1].icon.current].h
  dy = dy + tab_line
  _.each(tabs, function(idx, tab)
    tab.icon.dx = tab_icon_dx
    tab.icon.dy = tab_icon_dy
    tab_icon_dx = tab_icon_dx + tab.icon.states[tab.icon.current].w + 2
    _.each(tab.all, function(idx, e)
      e.dx = e.dx + dx
      e.dy = e.dy + dy
    end)
  end)

  -- it might be that tabs icon line is the most wide
  max_w = math.max(max_tab_w, max_w, tab_icon_dx + 10)

  -- post-process tabs: adjust r-aligned items
  _.each(tabs, function(idx, tab)
    _.each(tab.r_aligned, function(idx, e)
      e.dx = max_w - e.image.w - 10
    end)
  end)

  local tabs_region = {
    x_min = dx,
    y_min = dy,
    x_max = max_w,
    y_max = dy + max_tab_h,
  }

  local active_tab = 1
  tabs[active_tab].icon.current = 'active'
  local gui = {
    tabs         = tabs,
    tabs_region  = tabs_region,
    active_tab   = active_tab,
    elements     = elements,
    content_size = {
      w = max_w,
      h = dy + max_tab_h,
    },
  }
  return gui
end

function UnitInfoWindow:bind_ctx(context)
  local engine = self.engine
  local theme = assert(context.renderer.theme)
  engine.state.mouse_hint = ''
  local gui = self:_construct_gui();

  local unit_info_ctx = _.clone(context, true)

  local content_w = gui.content_size.w
  local content_h = gui.content_size.h
  local x, y = context.layout_fn(self, content_w, content_h)

  local content_x, content_y = x + self.contentless_size.dx, y + self.contentless_size.dy

  unit_info_ctx.x = x
  unit_info_ctx.y = y
  unit_info_ctx.content_size = {
    w = content_w,
    h = content_h,
  }
  local window_region = {
    x_min = x,
    y_min = y,
    x_max = x + self.contentless_size.w + content_w,
    y_max = y + self.contentless_size.h + content_h,
  }
  local tab_content_region = {
    x_min = content_x + gui.tabs_region.x_min,
    y_min = content_y + gui.tabs_region.y_min,
    x_max = content_x + gui.tabs_region.x_max,
    y_max = content_y + gui.tabs_region.y_max,
  }

  local is_over = function(mx, my, region)
    local over = ((mx >= region.x_min) and (mx <= region.x_max)
              and (my >= region.y_min) and (my <= region.y_max))
    return over
  end
  local tab_icon_regions = _.map(gui.tabs, function(idx, tab)
    local icon_data = tab.icon
    local tab_image = icon_data.states[icon_data.current]
    return {
      x_min = content_x + icon_data.dx,
      x_max = content_x + icon_data.dx + tab_image.w,
      y_min = content_y + icon_data.dy,
      y_max = content_y + icon_data.dy + tab_image.h,
    }
  end)

  local is_over_tab_icons_region = function(x,y)
    for idx, tab_icon_area in ipairs(tab_icon_regions) do
      if (is_over(x, y, tab_icon_area)) then
        return idx
      end
    end
  end


  local sdl_renderer = assert(context.renderer.sdl_renderer)
  self.drawing.content_fn = function()
    -- background
    assert(sdl_renderer:copy(theme.window.background.texture, nil,
      {x = content_x, y = content_y, w = content_w, h = content_h}
    ))

    local element_drawer = function(idx, e)
      local image = e.image
      assert(sdl_renderer:copy(image.texture, nil,
        {x = content_x + e.dx, y = content_y + e.dy, w = image.w, h = image.h}
      ))
    end
    -- header
    _.each(gui.elements, element_drawer)

    -- draw active tab active elements
    local tab_elements = gui.tabs[gui.active_tab].active
    _.each(tab_elements, element_drawer)

    -- draw all tab labels
    _.each(gui.tabs, function(idx, tab)
      local icon_data = tab.icon
      local tab_image = icon_data.states[icon_data.current]
      assert(sdl_renderer:copy(tab_image.texture, nil,
        {x = content_x + icon_data.dx, y = content_y + icon_data.dy, w = tab_image.w, h = tab_image.h}
      ))
    end)

  end

  local mouse_click = function(event)
    if (is_over(event.x, event.y, window_region)) then
      local idx = is_over_tab_icons_region(event.x, event.y)
      if (idx) then -- swithing tab
        local prev_tab = gui.tabs[gui.active_tab]
        local new_tab = gui.tabs[idx]
        prev_tab.icon.current = 'available'
        new_tab.icon.current = 'active'
        gui.active_tab = idx
      else -- some action inside tab content, delegate
        gui.tabs[gui.active_tab]:mouse_click(event)
      end
    else
      -- just close the window
      engine.interface:remove_window(self)
    end
    return true -- stop further event propagation
  end

  context.state.action = 'default'
  local mouse_move = function(event)
    engine.state.mouse_hint = ''
    -- remove hilight from all tab icons, except the active one
    for idx, tab in ipairs(gui.tabs) do
      local icon = tab.icon
      if (idx ~= gui.active_tab) then
        icon.current = 'available'
      end
    end
    local idx = is_over_tab_icons_region(event.x, event.y)
    if (idx) then
      engine.state.mouse_hint = gui.tabs[idx].icon.hint
      if (idx ~= gui.active_tab) then
        gui.tabs[idx].icon.current = 'hilight'
      end
    end
    if (not(idx) and  is_over(event.x, event.y, tab_content_region)) then
      gui.tabs[gui.active_tab].mouse_move(event)
    end
    return true -- stop further event propagation
  end

  context.events_source.add_handler('mouse_click', mouse_click)
  context.events_source.add_handler('mouse_move', mouse_move)
  self.content.mouse_click = mouse_click
  self.content.mouse_move = mouse_move

  HorizontalPanel.bind_ctx(self, unit_info_ctx)
end

function UnitInfoWindow:unbind_ctx(context)
  context.events_source.remove_handler('mouse_click', self.content.mouse_click)
  context.events_source.remove_handler('mouse_move', self.content.mouse_move)
  self.content.mouse_click = nil
  self.content.mouse_move = nil
  self.drawing.content_fn = nil
  HorizontalPanel.unbind_ctx(self, context)
end

function UnitInfoWindow:draw()
  self.drawing.content_fn()
  HorizontalPanel.draw(self)
end

return UnitInfoWindow
