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


local Cursor = {}
Cursor.__index = Cursor

function Cursor.create(engine)
  local o = {
    engine = engine,
    drawing = {
      fn = function() end,
      listener = nil
    }
  }
  setmetatable(o, Cursor)
  return o
end

function Cursor:bind_ctx(context)
  local engine = self.engine
  local theme = engine.gear:get("theme")
  local state = engine.state
  local sdl_renderer = engine.gear:get("renderer").sdl_renderer

  local cursor = theme.cursor
  local dst = { x = 0, y = 0, w = cursor.w, h = cursor.h }

  local listener = function()
    local mouse = state:get_mouse()
    dst.x = mouse.x
    dst.y = mouse.y
    self.drawing.fn = function()
      assert(sdl_renderer:copy(cursor.texture, nil, dst))
    end
  end
  listener()

  self.drawing.listener = listener
  engine.reactor:subscribe('mouse-position.change', listener)
  self.listener = listener
end

function Cursor:unbind_ctx(context)
  self.drawing.fn = nil
  self.engine.reactor:unsubscribe('mouse-position.change', self.listener)
end

function Cursor:draw()
  self.drawing.fn()
end


return Cursor
