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
   local tile = assert(engine.map.tiles[x][y])
   
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

return Unit
