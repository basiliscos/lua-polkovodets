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

local Button = {}
Button.__index = Button

local _count = 1

function Button.create(engine, data)
  local o = {
    id     = tostring(_count),
    hint   = assert(data.hint),
    engine = engine,
    drawing = {
      fn          = nil,
      mouse_click = nil,
      mouse_move  = nil,
      objects     = {},
    }
  }
  _count = _count + 1
  return setmetatable(o, Button)
end

function Button:bind_ctx(context)
  local my_ctx = assert(context.button[self.id])
  local x = assert(my_ctx.x)
  local y = assert(my_ctx.y)
  local image = assert(my_ctx.image)

  local sdl_renderer = assert(context.renderer.sdl_renderer)
  local dst = { x = x, y = y,  w = image.w, h = image.h }
  local x_max = x + image.h
  local y_max = y + image.h

  local is_over = function(event)
    return ((event.x >= x) and (event.x <= x_max) and (event.y >= y) and (event.y <= y_max))
  end

  local callback = assert(my_ctx.callback)
  local drawing_fn = function()
    assert(sdl_renderer:copy(image.texture, nil, dst))
  end
  local mouse_move = function(event)
    if (is_over(event)) then
      context.state.mouse_hint = self.hint
      if (context.state.action ~= 'default') then
        context.state.action = 'default'
        self.engine.mediator:publish({ "view.update" })
      end
      return true
    end
  end
  local mouse_click = function(event)
    if (is_over(event)) then return callback() end
  end

  context.events_source.add_handler('mouse_click', mouse_click)
  context.events_source.add_handler('mouse_move', mouse_move)
  self.drawing.mouse_move = mouse_move
  self.drawing.mouse_click = mouse_click
  self.drawing.fn = drawing_fn
end

function Button:unbind_ctx(context)
  context.events_source.remove_handler('mouse_move', self.drawing.mouse_move)
  context.events_source.remove_handler('mouse_click', self.drawing.mouse_click)
  self.drawing.mouse_move = nil
  self.drawing.fn = nil
end

function Button:draw()
  self.drawing.fn()
end

return Button
