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

function UnitInfoWindow:_construct_info_tab()
  local engine = self.engine
  local unit = self.unit
  local font = engine.renderer.theme:get_font('default', DEFAULT_FONT_SIZE)
  local tab_data = {
    all       = {},
    r_aligned = {},
    icon      = {
      current = 'available',
      states  = engine.renderer.theme.tabs.info,
    }
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
    local value_img = Image.create(
      engine.renderer.sdl_renderer,
      font:renderUtf8(value, "solid", DEFAULT_COLOR)
    )
    local value_descr = {
      dx = tab_data.all[#tab_data.all].dx + tab_data.all[#tab_data.all].image.w + 15,
      dy = tab_data.all[#tab_data.all].dy,
      image = value_img,
    }
    table.insert(tab_data.all, value_descr)
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
  return tab_data
end

function UnitInfoWindow:_construct_gui()
  local engine = self.engine
  local unit = self.unit

  local max_w = 100
  local max_h = 100
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

  max_w = elements[#elements].dx + elements[#elements].image.w + 5
  max_h = math.max(title.h, flag.h)
  -- reposition title/flag to be on the same Y-center
  _.each(elements, function(idx, e)
    e.dy = math.modf((max_h - e.image.h) / 2)
  end)

  local dy = max_h + 10
  local dx = 10
  --[[ header end ]]--

  local tabs = {}
  local max_tab_w, max_tab_h = 0, 0
  local add_tab = function(tab)
    table.insert(tabs, tab)
    local w = _.max(tab.all, function(e)
      return e.dx + e.image.w
    end)
    local h = _.max(tab.all, function(e)
      return e.dy + e.image.h
    end)
    max_tab_w = math.max(max_tab_w, w)
    max_tab_h = math.max(max_tab_h, h)
  end

  add_tab(self:_construct_info_tab())

  max_w = math.max(max_tab_w, max_w)

  -- post-process tabs: adjust r-aligned items, icons, dx, dy for all elements
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
    _.each(tab.r_aligned, function(idx, e)
      e.dx = max_w - e.image.w - 10
    end)
  end)

  local active_tab = 1
  tabs[active_tab].icon.current = 'active'
  local gui = {
    tabs         = tabs,
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
  local window = assert(context.window)
  local x = math.modf(window.w/2 - content_w/2)
  local y = math.modf(window.h/2 - content_h/2)

  local content_x, content_y = x + self.contentless_size.dx, y + self.contentless_size.dy

  unit_info_ctx.x = x
  unit_info_ctx.y = y
  unit_info_ctx.content_size = {
    w = content_w,
    h = content_h,
  }

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

    -- active tab
    local tab_elements = gui.tabs[gui.active_tab].all
    _.each(tab_elements, element_drawer)
    local icon_data = gui.tabs[gui.active_tab].icon
    local tab_image = icon_data.states[icon_data.current]
    assert(sdl_renderer:copy(tab_image.texture, nil,
      {x = content_x + icon_data.dx, y = content_y + icon_data.dy, w = tab_image.w, h = tab_image.h}
    ))

  end
  HorizontalPanel.bind_ctx(self, unit_info_ctx)
end

function UnitInfoWindow:unbind_ctx(context)
  self.drawing.content_fn = nil
  HorizontalPanel.unbind_ctx(self, context)
end

function UnitInfoWindow:draw()
  self.drawing.content_fn()
  HorizontalPanel.draw(self)
end

return UnitInfoWindow
