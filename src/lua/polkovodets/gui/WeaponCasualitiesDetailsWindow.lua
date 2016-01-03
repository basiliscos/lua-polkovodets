--[[

Copyright (C) 2015 Ivan Baidakou

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

local WeaponCasualitiesDetailsWindow = {}
WeaponCasualitiesDetailsWindow.__index = WeaponCasualitiesDetailsWindow
setmetatable(WeaponCasualitiesDetailsWindow, HorizontalPanel)

local FONT_SIZE = 12
local AVAILABLE_COLOR = 0xAAAAAA
local HILIGHT_COLOR = 0xFFFFFF


function WeaponCasualitiesDetailsWindow.create(engine, data)
  local o = HorizontalPanel.create(engine)
  setmetatable(o, WeaponCasualitiesDetailsWindow)
  o.drawing.content_fn = nil
  o.content = {}

  o.font = engine.renderer.theme:get_font('default', FONT_SIZE)

  o.participants = assert(data.participants)
  o.casualities = assert(data.casualities)
  o.initial_position = assert(data.position)

  return o
end

function WeaponCasualitiesDetailsWindow:bind_ctx(context)
  local engine = self.engine
  local theme = assert(context.renderer.theme)
  engine.state.mouse_hint = ''

  local wcdw_ctx = _.clone(context, true)

  local font = self.font
  local wi_ids = _.keys(self.participants)
  -- print(inspect(wi_ids))

  local create_image = function(str, color)
    local surface = font:renderUtf8(tostring(str), "solid", color)
    return Image.create(engine.renderer.sdl_renderer, surface)
  end

  local content_x, content_y = self.contentless_size.dx, self.contentless_size.dy
  local max_w = 0

  -- 1st pass: draw weapon names
  local dx = content_x + 5
  local lines = _.map(wi_ids, function(idx, wi_id)
    local wi = assert(engine.weapon_instance_for[wi_id])
    local name = wi.weapon.name
    local label = create_image(name, AVAILABLE_COLOR)
    -- just 1st element of line, i.e. weapon name
    local line = {
      {
        dx    = dx,
        label = label,
      }
    }
    max_w = math.max(max_w, label.w)
    return line
  end)

  -- 2nd pass: draw header
  local was_label = create_image(engine:translate('ui.window.battle_details.header.was'), HILIGHT_COLOR)
  local casualities_label = create_image(engine:translate('ui.window.battle_details.header.casualities'), HILIGHT_COLOR)

  local dx = content_x + 10 + max_w
  local headers = {}
  table.insert(headers, {
    label = was_label,
    dx    = dx,
    dy    = content_y,
    mid_x = dx + math.modf(was_label.w/2),
  })
  dx = dx + headers[1].label.w + 10
  table.insert(headers, {
    label = casualities_label,
    dx    = dx,
    dy    = content_y,
    mid_x = dx + math.modf(casualities_label.w/2),
  })

  -- 3rd pass: calculate dy
  local dy = headers[1].dy + headers[1].label.h + 5
  for idx, labels in pairs(lines) do
    for idx2, label_data in pairs(labels) do
      label_data.dy = dy
    end
    dy = dy + labels[1].label.h
  end

  -- 4th pass: draw numbers
  _.each(wi_ids, function(idx, wi_id)
    local line = lines[idx]
    -- participants
    local p_label = create_image(tonumber(self.participants[wi_id]), AVAILABLE_COLOR)
    table.insert(line, {
      dy    = line[1].dy,
      dx    = math.modf(headers[1].mid_x - p_label.w/2),
      label = p_label,
    })
    -- casualities
    local c_label = create_image(tonumber(self.casualities[wi_id]), AVAILABLE_COLOR)
    table.insert(line, {
      dy    = line[1].dy,
      dx    = math.modf(headers[2].mid_x - c_label.w/2),
      label = c_label,
    })
  end)

  local content_w = dx + headers[#headers].label.w + 10
  local content_h = dy

  -- the window content could be drawn outside of the system window,
  -- make shoure, that this will not happen
  local x, y = self.initial_position.x, self.initial_position.y
  local offscreen_dx = x + content_w + self.contentless_size.w - context.window.w
  local offscreen_dy = y + content_h + self.contentless_size.h - context.window.h

  if (offscreen_dx > 0) then x = x - offscreen_dx end
  if (offscreen_dy > 0) then y = y - offscreen_dy end

  -- provide details for parent widget
  wcdw_ctx.content_size = {
    w = content_w,
    h = content_h,
  }
  wcdw_ctx.x = x
  wcdw_ctx.y = y

  -- print(inspect(lines))
  -- print(inspect(headers))

  local sdl_renderer = assert(context.renderer.sdl_renderer)
  local draw_fn = function()
    -- background
    assert(sdl_renderer:copy(theme.window.background.texture, nil,
      {x = x + content_x, y = y + content_y, w = content_w, h = content_h}
    ))

    -- headers
    for idx, header in pairs(headers) do
      local label = header.label
      assert(sdl_renderer:copy(label.texture, nil,
        {x = x + header.dx, y = y + header.dy, w = label.w, h = label.h}
      ))
    end

    -- labels
    for idx, labels in pairs(lines) do
      for idx2, label in pairs (labels) do
        assert(sdl_renderer:copy(label.label.texture, nil,
          {x = x + label.dx, y = y + label.dy, w = label.label.w, h = label.label.h}
        ))
      end
    end
  end

  -- just to prevent scrolling / hints update
  local mouse_move = function(event)
    return true -- stop further event propagation
  end

  -- just dispose current window
  local mouse_click = function(event)
    engine.interface:remove_window(self)
    return true -- stop further event propagation
  end

  context.events_source.add_handler('mouse_click', mouse_click)
  context.events_source.add_handler('mouse_move', mouse_move)

  self.content.mouse_move = mouse_move
  self.content.mouse_click = mouse_click

  self.drawing.content_fn = draw_fn
  HorizontalPanel.bind_ctx(self, wcdw_ctx)
end

function WeaponCasualitiesDetailsWindow:unbind_ctx(context)
  context.events_source.remove_handler('mouse_click', self.content.mouse_click)
  context.events_source.remove_handler('mouse_move', self.content.mouse_move)
  self.content.mouse_click = nil
  self.content.mouse_move = nil
  self.drawing.content_fn = nil
  HorizontalPanel.unbind_ctx(self, context)
end

function WeaponCasualitiesDetailsWindow:draw()
  self.drawing.content_fn()
  HorizontalPanel.draw(self)
end

return WeaponCasualitiesDetailsWindow
