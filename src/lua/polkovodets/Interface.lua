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

local Inteface = {}
Inteface.__index = Inteface

function Inteface.create(engine)
  local o = {
    engine = engine,
    drawing = {
      fn          = nil,
      mouse_click = nil,
      objects     = {},
    }
  }
  return setmetatable(o, Inteface)
end

function Inteface:bind_ctx(context)

  local font = context.theme.fonts.active_hex
  local outline_color = context.theme.data.active_hex.outline_color
  local color = context.theme.data.active_hex.color

  local w,h = context.renderer.window:getSize()
  local sdl_renderer = context.renderer.sdl_renderer
  local render_label = function(surface)
    assert(surface)
    local texture = assert(sdl_renderer:createTextureFromSurface(surface))
    local sw, sh = surface:getSize()
    local label_x = math.modf(w/2 - sw/2)
    local label_y = 25 - math.modf(sh/2)
    assert(sdl_renderer:copy(texture, nil , {x = label_x, y = label_y, w = sw, h = sh}))
  end

  local draw_fn = function()
    local hint = context.state.mouse_hint
    if (hint) then
      font:setOutline(context.theme.data.active_hex.outline_width)
      render_label(font:renderUtf8(hint, "solid", outline_color))
      font:setOutline(0)
      render_label(font:renderUtf8(hint, "solid", color))
    end
  end

  self.drawing.fn = draw_fn
end

function Inteface:unbind_ctx(context)
  self.drawing.fn = nil
end

function Inteface:draw()
  self.drawing.fn()
end

return Inteface
