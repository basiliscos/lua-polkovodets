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

local Unit = {}
Unit.__index = Unit

function Unit.create(engine, data)
   assert(data.id)
   assert(data.nation)
   assert(data.x)
   assert(data.y)
   assert(data.str)
   assert(data.entr)
   assert(data.exp)

   local definition = assert(engine.unit_lib.unit_definitions[data.id])
   local nation = assert(engine.nation_for[data.nation])
   local x,y = tonumber(data.x), tonumber(data.y)
   local tile = assert(engine.map.tiles[x + 1][y + 1])
   
   local o = {
      engine = engine,
      nation = nation,
      tile = tile,
      definition = definition,
      data = {
         streight      = data.str,
         entrenchment = data.entr,
         experience   = data.exp,
      }
   }
   setmetatable(o, Unit)
   tile.unit = o
   return o
end

function Unit:draw(sdl_renderer, x, y)
   local terrain = self.engine.map.terrain
   local hex_h = terrain.hex_height
   local hex_w = terrain.hex_width

   local texture = self.definition:get_icon()
   local format, access, w, h = texture:query()
   local dst = {
      x = x + math.modf((hex_w - w)/2),
      y = y + math.modf((hex_h - h)/2),
      w = w,
      h = h,
   }
   assert(sdl_renderer:copy(texture, {x = o , y = 0, w = w, h = h} , dst))
end

return Unit
