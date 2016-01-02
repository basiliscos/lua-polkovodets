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

local Image = require 'polkovodets.utils.Image'

local Popup = {}
Popup.__index = Popup

local FONT_SIZE = 12
local AVAILABLE_COLOR = 0xAAAAAA
local HILIGHT_COLOR = 0xFFFFFF


function Popup.create(engine, close_fn)
  local o = {
    engine   = engine,
    close_fn = close_fn,
    font     = engine.renderer.theme:get_font('default', FONT_SIZE),
    drawing  = {
      fn          = nil,
      mouse_click = nil,
      objects     = {},
    }
  }
  return setmetatable(o, Popup)
end

function Popup:bind_ctx(context)
  local definitions = assert(context.definitions)
  local engine = self.engine
  local font = self.font

  engine.state.mouse_hint = ''

  _.eachi(definitions, function(k, value)
    assert(value.label)
    assert(value.callback)
  end)

  local create_image = function(text, color)
    local surface = font:renderUtf8(text, "solid", color)
    return Image.create(engine.renderer.sdl_renderer, surface)
  end

  local x, y = context.initial_position.x, context.initial_position.y

  local margin_x = 5
  local margin_y = 5
  local content_w, content_h = 0, margin_y
  local labels = _.map(definitions, function(key, value)
    local image_available = create_image(value.label, AVAILABLE_COLOR)
    if (content_w < image_available.w) then content_w = image_available.w end
    local data = {
      dx = margin_x,
      dy = content_h,
      style = 'available',
      image = {
        available = image_available,
        hilight   = create_image(value.label, HILIGHT_COLOR)
      }
    }
    content_h = content_h + image_available.h
    return data
  end)

  content_h = content_h + margin_y
  content_w = content_w + margin_x * 2

  _.each(labels, function(idx, label)
    label.region = {
      x_min = x,
      x_max = x + content_w,
      y_min = label.dy + y,
      y_max = label.dy + y + label.image.available.h,
    }
  end)

  local is_over = function(mx, my, region)
    local over = ((mx >= region.x_min) and (mx <= region.x_max)
              and (my >= region.y_min) and (my <= region.y_max))
    return over
  end
  local popup_region = {
    x_min = x,
    x_max = x + content_w,
    y_min = y,
    y_max = y + content_h,
  }

  local update_line_styles = function(x, y)
    _.each(labels, function(key, label)
      label.style = is_over(x, y, label.region) and 'hilight' or 'available'
    end)
  end

  update_line_styles(context.mouse.x, context.mouse.y)

  local sdl_renderer = assert(context.renderer.sdl_renderer)

  local theme = assert(context.renderer.theme)
  local sdl_renderer = assert(context.renderer.sdl_renderer)
  local draw_fn  = function()
    -- background
    assert(sdl_renderer:copy(theme.window.background.texture, nil,
      {x = x, y = y, w = content_w, h = content_h}
    ))

    -- labels
    for idx, label_data in pairs(labels) do
      local style = label_data.style
      local image = label_data.image[style]
      assert(sdl_renderer:copy(image.texture, nil,
        {x = x + label_data.dx, y = y + label_data.dy, w = image.w, h = image.h}
      ))
    end
  end

  local mouse_move = function(event)
    if (is_over(event.x, event.y, popup_region)) then
      update_line_styles(event.x, event.y)
    end
    return true -- stop further event propagation
  end

  local mouse_click = function(event)
    if (is_over(event.x, event.y, popup_region)) then
      for idx, label in ipairs(labels) do
        if (is_over(event.x, event.y, label.region)) then
          return definitions[idx].callback()
        end
      end
      update_line_styles(event.x, event.y)
    else
      self.close_fn(self)
    end
    return true -- stop further event propagation
  end

  context.events_source.add_handler('mouse_move', mouse_move)
  context.events_source.add_handler('mouse_click', mouse_click)
  self.drawing.mouse_move = mouse_move
  self.drawing.mouse_click = mouse_click

  self.drawing.fn = draw_fn
end

function Popup:unbind_ctx(context)
  context.events_source.remove_handler('mouse_move', self.drawing.mouse_move)
  context.events_source.remove_handler('mouse_click', self.drawing.mouse_click)
  self.drawing.fn = nil
  self.drawing.mouse_move = nil
  self.drawing.mouse_click = nil
end

function Popup:draw()
  self.drawing.fn()
end


return Popup
