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

local HorizontalPanel = {}
HorizontalPanel.__index = HorizontalPanel

function HorizontalPanel.create(engine)
  local theme = assert(engine.renderer.theme)
  local o = {
    engine           = engine,
    contentless_size = {
      dx = theme.panel.corner.tl.w,
      dy = theme.panel.corner.tl.h,
      w  = theme.panel.corner.tl.w + theme.panel.corner.tr.w,
      h  = theme.panel.corner.tl.h + theme.panel.corner.bl.h,
    },
    drawing          = {
      fn          = nil,
      mouse_click = nil,
      objects     = {},
    }
  }
  return setmetatable(o, HorizontalPanel)
end

function HorizontalPanel:bind_ctx(context)
  local theme = assert(context.theme)
  local parts = theme.panel

  local x = assert(context.x)
  local y = assert(context.y)
  local content_size = assert(context.content_size)

  local sdl_renderer = assert(context.renderer.sdl_renderer)

  local draw_fn  = function()
    -- top left corner
    assert(sdl_renderer:copy(parts.corner.tl.texture, nil,
      {x = x, y = y, w = parts.corner.tl.w, h = parts.corner.tl.h}
    ))
    -- left mid
    assert(sdl_renderer:copy(parts.mid.l.texture, nil,
      {x = x, y = y + parts.corner.tl.h, w = parts.mid.l.w, h = content_size.h}
    ))
    -- bottom left corner
    assert(sdl_renderer:copy(parts.corner.bl.texture, nil,
      {x = x, y = y + parts.corner.tl.h + content_size.h, w = parts.corner.bl.w, h = parts.corner.bl.h}
    ))
    -- top mid
    assert(sdl_renderer:copy(parts.mid.t.texture, nil,
      {x = x + parts.corner.tl.h, y = y, w = content_size.w, h = parts.mid.t.h}
    ))
    -- bottom mid
    assert(sdl_renderer:copy(parts.mid.b.texture, nil,
      {x = x + parts.corner.tl.h, y = y + parts.corner.tl.h + content_size.h, w = content_size.w, h = parts.mid.b.h}
    ))
    -- top right corner
    assert(sdl_renderer:copy(parts.corner.tr.texture, nil,
      {x = x + parts.corner.tl.h + content_size.w, y = y, w = parts.corner.tr.w, h = parts.corner.tr.h}
    ))
    -- right mid
    assert(sdl_renderer:copy(parts.mid.r.texture, nil,
      {x = x + parts.corner.tl.h + content_size.w, y = y + parts.corner.tr.h, w = parts.mid.r.w, h = content_size.h}
    ))
    -- bottom right corner
    assert(sdl_renderer:copy(parts.corner.br.texture, nil,
      {x = x + parts.corner.tl.h + content_size.w, y = y + parts.corner.tl.h + content_size.h, w = parts.corner.br.w, h = parts.corner.br.h}
    ))
  end
  self.drawing.fn = draw_fn
end


function HorizontalPanel:unbind_ctx(context)
  self.drawing.fn = nil
end

function HorizontalPanel:draw()
  self.drawing.fn()
end

return HorizontalPanel
