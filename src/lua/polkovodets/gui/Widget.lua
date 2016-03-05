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

local Widget = {}
Widget.__index = Widget

function Widget.create(engine, floating)
  local theme = assert(engine.renderer.theme)
  local o = {
    engine           = engine,
    properties       = {
      floating = floating,
    },
    contentless_size = {
      dx = theme.panel.corner.tl.w,
      dy = theme.panel.corner.tl.h,
      w  = theme.panel.corner.tl.w + theme.panel.corner.tr.w,
      h  = theme.panel.corner.tl.h + theme.panel.corner.bl.h,
    },
    drawing          = {
      fn      = nil,
      objects = {},
    }
  }
  return setmetatable(o, Widget)
end

function Widget:update_drawer(x, y, content_w, content_h)
  local renderer = self.engine.renderer
  local theme = renderer.theme
  local parts = theme.panel

  local sdl_renderer = renderer.sdl_renderer

  local tl_corner_box = {x = x, y = y, w = parts.corner.tl.w, h = parts.corner.tl.h}
  local left_mid_box  = {x = x, y = y + parts.corner.tl.h, w = parts.mid.l.w, h = content_h}
  local bl_corner_box = {x = x, y = y + parts.corner.tl.h + content_h, w = parts.corner.bl.w, h = parts.corner.bl.h}
  local top_mid_box   = {x = x + parts.corner.tl.h, y = y, w = content_w, h = parts.mid.t.h}
  local bot_mid_box   = {x = x + parts.corner.tl.h, y = y + parts.corner.tl.h + content_h, w = content_w, h = parts.mid.b.h}
  local tr_corner_box = {x = x + parts.corner.tl.h + content_w, y = y, w = parts.corner.tr.w, h = parts.corner.tr.h}
  local right_mid_box = {x = x + parts.corner.tl.h + content_w, y = y + parts.corner.tr.h, w = parts.mid.r.w, h = content_h}
  local br_corner_box = {x = x + parts.corner.tl.h + content_w, y = y + parts.corner.tl.h + content_h, w = parts.corner.br.w, h = parts.corner.br.h}

  self.drawing.fn = function()
    -- top left corner
    assert(sdl_renderer:copy(parts.corner.tl.texture, nil, tl_corner_box))
    -- left mid
    assert(sdl_renderer:copy(parts.mid.l.texture, nil, left_mid_box))
    -- bottom left corner
    assert(sdl_renderer:copy(parts.corner.bl.texture, nil, bl_corner_box))
    -- top mid
    assert(sdl_renderer:copy(parts.mid.t.texture, nil, top_mid_box))
    -- bottom mid
    assert(sdl_renderer:copy(parts.mid.b.texture, nil, bot_mid_box))
    -- top right corner
    assert(sdl_renderer:copy(parts.corner.tr.texture, nil, tr_corner_box))
    -- right mid
    assert(sdl_renderer:copy(parts.mid.r.texture, nil, right_mid_box))
    -- bottom right corner
    assert(sdl_renderer:copy(parts.corner.br.texture, nil, br_corner_box))
  end
end

function Widget:draw()
  self.drawing.fn()
end

return Widget
