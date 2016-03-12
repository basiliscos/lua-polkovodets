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

local Nation = {}
Nation.__index = Nation

local Parser = require 'polkovodets.Parser'

function Nation.create(engine, nation_data)
  assert(nation_data.id)
  assert(nation_data.name)
  assert(nation_data.icon_path)

  local load_flag = function(short_path)
    local image_path = engine:get_gfx_dir() .. '/' .. short_path
    return engine.renderer:load_texture(image_path)
  end

  local o = {
    id        = nation_data.id,
    name      = nation_data.name,
    engine    = engine,
    flag      = load_flag(nation_data.icon_path),
    unit_flag = load_flag(nation_data.unit_icon_path),
    drawing   = {
      fn = nil
    }
  }

  setmetatable(o, Nation)
  return o
end

function Nation:bind_ctx(context)
  -- print("nation drawing context has been bounded")
  local nation_flag_width = self.flag.w
  local nation_flag_height = self.flag.h
  local hex_w = context.tile_geometry.w
  local hex_h = context.tile_geometry.h
  local x = context.tile.virtual.x + context.screen.offset[1]
  local y = context.tile.virtual.y + context.screen.offset[2]
  local flag_x = x + math.modf((hex_w - nation_flag_width) / 2)
  local flag_y = y + math.modf((hex_h - nation_flag_height - 2))
  local dst = {x = flag_x, y = flag_y, w = self.flag.w, h = self.flag.h}

  local sdl_renderer = assert(context.renderer.sdl_renderer)
  self.drawing.fn = function()
    assert(sdl_renderer:copy(self.flag.texture, nil, dst))
  end
end


function Nation:draw()
  assert(self.drawing.fn)
  self.drawing.fn()
end

function Nation:unbind_ctx()
  self.drawing.fn = nil
end


return Nation
