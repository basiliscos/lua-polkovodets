--[[

Copyright (C) 2015,2016 Ivan Baidakou

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
local Region = require 'polkovodets.utils.Region'

local Popup = {}
Popup.__index = Popup

local FONT_SIZE = 12
local AVAILABLE_COLOR = 0xAAAAAA
local HILIGHT_COLOR = 0xFFFFFF


function Popup.create(engine, close_fn, definitions, initial_position)
  assert(initial_position)
  local theme = engine.gear:get("theme")

  local o = {
    -- mimic window properties
    properties  = {
      floating = false,
    },
    engine      = engine,
    close_fn    = close_fn,
    definitions = definitions,
    position    = initial_position,
    font        = theme:get_font('default', FONT_SIZE),
    drawing     = {
      fn          = nil,
      mouse_click = nil,
      objects     = {},
    }
  }

  _.eachi(definitions, function(k, value)
    assert(value.label)
    assert(value.callback)
  end)

  return setmetatable(o, Popup)
end

function Popup:_construct_gui()
  local definitions = self.definitions
  local engine = self.engine
  local font = self.font
  local renderer = engine.gear:get("renderer")

  local create_image = function(text, color)
    local surface = font:renderUtf8(text, "solid", color)
    return Image.create(renderer.sdl_renderer, surface)
  end

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

  return {
    labels = labels,
    w      = content_w,
    h      = content_h,
  }
end


function Popup:_on_ui_update(show)
  local engine = self.engine
  local context = self.drawing.context

  local handlers_bound = self.handlers_bound

  if (show) then
    local gui = self.drawing.gui
    local theme = engine.gear:get("theme")
    local renderer = engine.gear:get("renderer")
    local x, y = self.position.x, self.position.y

    _.each(gui.labels, function(idx, label)
      label.region = Region.create(x, label.dy + y, x + gui.w, label.dy + y + label.image.available.h)
    end)

    local popup_region = Region.create(x, y, x + gui.w, y + gui.h)

    local update_line_styles = function(xx, yy)
      _.each(gui.labels, function(key, label)
        local style = label.region:is_over(xx, yy) and 'hilight' or 'available'
        local image = label.image[style]
        local box = {x = x + label.dx, y = y + label.dy, w = image.w, h = image.h}

        label.box = box
        label.drawn_image = image
      end)
    end

    local mouse = engine.state:get_mouse()
    update_line_styles(mouse.x, mouse.y)

    local sdl_renderer = assert(renderer.sdl_renderer)
    local bg_box = { x = x, y = y, w = gui.w, h = gui.h}
    self.drawing.fn = function()
      -- background
      assert(sdl_renderer:copy(theme.window.background.texture, nil, bg_box))

      -- labels
      for idx, label in pairs(gui.labels) do
        assert(sdl_renderer:copy(label.drawn_image.texture, nil, label.box))
      end
    end

    if (not handlers_bound) then
      self.handlers_bound = true

      local mouse_move = function(event)
        if (popup_region:is_over(event.x, event.y)) then
          update_line_styles(event.x, event.y)
        end
        return true -- stop further event propagation
      end

      local mouse_click = function(event)
        if (popup_region:is_over(event.x, event.y)) then
          for idx, label in ipairs(gui.labels) do
            if (label.region:is_over(event.x, event.y)) then
              return self.definitions[idx].callback(self)
            end
          end
          update_line_styles(event.x, event.y)
        else
          self.close_fn(self)
        end
        return true -- stop further event propagation
      end

      self.drawing.mouse_move = mouse_move
      self.drawing.mouse_click = mouse_click
      context.events_source.add_handler('mouse_move', self.drawing.mouse_move)
      context.events_source.add_handler('mouse_click', self.drawing.mouse_click)
    end
  elseif (handlers_bound) then  -- unbind everything
    self.handlers_bound = false
    context.events_source.remove_handler('mouse_move', self.drawing.mouse_move)
    context.events_source.remove_handler('mouse_click', self.drawing.mouse_click)
    self.drawing.mouse_move = nil
    self.drawing.mouse_click = nil
  end
end

function Popup:bind_ctx(context)
  local engine = self.engine
  local gui = self:_construct_gui()

  local ui_update_listener = function() return self:_on_ui_update(true) end

  self.drawing.context = context
  self.drawing.ui_update_listener = ui_update_listener
  self.drawing.gui = gui

  engine.reactor:subscribe('ui.update', ui_update_listener)

  self.drawing.fn = function() end

  return {gui.w, gui.h}
end

function Popup:unbind_ctx(context)
  self:_on_ui_update(false)
  self.engine.reactor:unsubscribe('ui.update', self.drawing.ui_update_listener)
  self.drawing.ui_update_listener = nil
  self.drawing.context = nil
end

function Popup:set_position(x, y)
  -- ignore values
end


function Popup:draw()
  self.drawing.fn()
end


return Popup
