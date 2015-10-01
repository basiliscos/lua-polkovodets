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

local inspect = require('inspect')
local SDL = require "SDL"


function Unit.create(engine, data)
   assert(data.id)
   assert(data.nation)
   assert(data.x)
   assert(data.y)
   assert(data.str)
   assert(data.entr)
   assert(data.exp)
   assert(data.orientation)

   local definition = assert(engine.unit_lib.unit_definitions[data.id])
   local nation = assert(engine.nation_for[data.nation])
   local x,y = tonumber(data.x), tonumber(data.y)
   local tile = assert(engine.map.tiles[x + 1][y + 1])

   local fuel = data.fuel and tonumber(data.fuel) or tonumber(definition.data.fuel)

   local o = {
      engine = engine,
      nation = nation,
      tile = tile,
      definition = definition,
      data = {
         selected     = false,
         streight     = data.str,
         entrenchment = data.entr,
         experience   = data.exp,
         fuel         = fuel,
         orientation  = data.orientation,
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
   local orientation = self.data.orientation
   assert((orientation == 'left') or (orientation == 'right'), "Unknown unit orientation: " .. orientation)
   local flip = (orientation == 'right') and SDL.rendererFlip.none or
                 (orientation == 'left') and SDL.rendererFlip.Horizontal

   if (self.data.selected) then
      local frame_icon = terrain:get_icon('frame')
      assert(sdl_renderer:copy(frame_icon, nil, {x = x, y = y, w = hex_w, h = hex_h}))
   end

   assert(sdl_renderer:copyEx(
             texture,
             {x = 0 , y = 0, w = w, h = h}, -- src
             dst,
             nil,                           -- no angle
             nil,                           -- no center
             flip
   ))
end

function Unit:move_cost(tile)
   local move_type = self.definition.data.move_type
   local weather = self.engine:current_weather()
   local cost_for = tile.data.terrain_type.move_cost
   local value = cost_for[move_type][weather]
   -- all movement cost
   if (value == 'A') then return self.definition.data.movement
   -- impassable
   elseif (value == 'X') then return math.maxinteger
   else return tonumber(value) end
end

return Unit
