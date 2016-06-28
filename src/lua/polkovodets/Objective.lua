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

local Objective = {}
Objective.__index = Objective

local inspect = require('inspect')

function Objective.create()
  local o = {
    drawing = {}
  }
  return setmetatable(o, Objective)
end

function Objective:initialize(data, nation_for, map, renderer, hex_geometry)

  local nation_id = assert(data.nation)
  local x = assert(data.x)
  local y = assert(data.y)
  local nation = assert(nation_for[nation_id], "no nation " .. nation_id .. ' is available')
  local tile = assert(map.tiles[x][y], " tile " .. x  .. ":" .. y .. " does not exist")

  -- all OK, set members
  self.nation = nation
  self.renderer = renderer
  self.hex_geometry = hex_geometry
  tile.data.objective = self
end

function Objective:bind_ctx(context)
  local hex_geometry = self.hex_geometry

  local nation = self.nation
  local nation_flag_width = nation.flag.w
  local nation_flag_height = nation.flag.h
  local hex_w = hex_geometry.width
  local hex_h = hex_geometry.height
  local x = context.tile.virtual.x + context.screen.offset[1]
  local y = context.tile.virtual.y + context.screen.offset[2]
  local flag_x = x + math.modf((hex_w - nation_flag_width) / 2)
  local flag_y = y + math.modf((hex_h - nation_flag_height - 2))
  local dst = {x = flag_x, y = flag_y, w = nation.flag.w, h = nation.flag.h}

  local sdl_renderer = assert(context.renderer.sdl_renderer)
  self.drawing.fn = function()
    assert(sdl_renderer:copy(nation.flag.texture, nil, dst))
  end

end


function Objective:draw()
  assert(self.drawing.fn)
  self.drawing.fn()
end

function Objective:unbind_ctx()
  self.drawing.fn = nil
end


return Objective
