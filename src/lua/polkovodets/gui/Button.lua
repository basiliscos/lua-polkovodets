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
local Region = require 'polkovodets.utils.Region'

local Button = {}
Button.__index = Button

local _count = 1

function Button.create(engine, data)
  assert(data.hint)
  assert(data.image)
  assert(data.callback)
  local o = {
    id     = tostring(_count),
    engine = engine,
    data   = data,
    drawing = {
      context     = nil,
      region      = nil,
      fn          = nil,
      mouse_click = nil,
      mouse_move  = nil,
      objects     = {},
    }
  }
  _count = _count + 1
  return setmetatable(o, Button)
end

function Button:update_data(data)
  for _, k in pairs({'hint', 'image', 'callback'}) do
    if (data[k]) then
      self.data[k] = data[k]
    end
  end
  self:_update()
end

function Button:_update()
  local context = self.drawing.context
  local x = assert(context.x)
  local y = assert(context.y)
  local image = assert(self.data.image)
  local state = self.engine.state

  local sdl_renderer = assert(self.engine.gear:get("renderer").sdl_renderer)
  local dst = { x = x, y = y,  w = image.w, h = image.h }
  local region = Region.create(x, y, x + image.h, y + image.h)

  local drawing_fn = function()
    assert(sdl_renderer:copy(image.texture, nil, dst))
  end

  self.drawing.region = region
  self.drawing.fn = drawing_fn

end

function Button:bind_ctx(context)
  local my_ctx = assert(context.button[self.id])
  self.drawing.context = my_ctx

  self:_update()

  local mouse_move = function(event)
    if (self.drawing.region:is_over(event.x, event.y)) then
      local hint = context.state:get_mouse_hint()
      if (hint ~= self.data.hint) then context.state:set_mouse_hint(self.data.hint) end
      if (context.state:get_action() ~= 'default') then
        context.state:set_action('default')
      end
      return true
    end
  end
  local mouse_click = function(event)
    if (self.drawing.region:is_over(event.x, event.y)) then
      return self.data.callback()
    end
  end

  context.events_source.add_handler('mouse_click', mouse_click)
  context.events_source.add_handler('mouse_move', mouse_move)
  self.drawing.mouse_move = mouse_move
  self.drawing.mouse_click = mouse_click
end

function Button:unbind_ctx(context)
  context.events_source.remove_handler('mouse_move', self.drawing.mouse_move)
  context.events_source.remove_handler('mouse_click', self.drawing.mouse_click)
  self.drawing.mouse_move = nil
  self.drawing.mouse_click = nil
  self.drawing.fn = nil
  self.drawing.region = nil
  self.drawing.context = nil
end

function Button:draw()
  self.drawing.fn()
end

return Button
