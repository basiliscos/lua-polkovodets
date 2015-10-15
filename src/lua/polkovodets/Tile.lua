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


local Tile = {}
Tile.__index = Tile

local inspect = require('inspect')

function Tile.create(engine, data)
   assert(data.image_idx)
   assert(data.x)
   assert(data.y)
   assert(data.name)
   assert(data.terrain_type)
   assert(data.terrain_name)

   -- use adjusted tiles (hex) coordinates
   local tile_x = data.x
   local tile_y = data.y + math.modf((tile_x - 2) * 0.5)

   data.tile_x = tile_x
   data.tile_y = tile_y

   local o = {
      uniq_id = Tile.uniq_id(data.x, data.y),
	  engine = engine,
	  data = data,
   }
   setmetatable(o, Tile)
   return o
end

function Tile.uniq_id(x,y)
   return string.format("tile[%d:%d]", x, y)
end


function Tile:draw(sdl_renderer, x, y)
   assert(sdl_renderer)
   local sx, sy = self.data.x, self.data.y
   -- print(inspect(self.data))
   -- print("drawing tile [" .. sx .. ":" .. sy .. "] at (" .. x .. ":" .. y .. ")")

   local engine = self.engine
   local map = engine:get_map()
   local terrain = map.terrain
   local weather = engine:current_weather()
   -- print(inspect(weather))
   -- print(inspect(self.data.terrain_type.image))

   local hex_h = terrain.hex_height
   local hex_w = terrain.hex_width

   local dst = {x = x, y = y, w = hex_w, h = hex_h}
   local texture = terrain:get_hex_image(self.data.terrain_name, weather, self.data.image_idx)

   -- draw terrain
   assert(sdl_renderer:copy(texture, {x = 0, y = 0, w = hex_w, h = hex_h} , dst))
   local u = engine:get_selected_unit()
   if (u) then
      local movement_area = u.data.actions_map.move
      if ((not movement_area[self.uniq_id]) and (u.tile.uniq_id ~= self.uniq_id)) then
         local fog_texture = terrain:get_icon('fog')
         assert(sdl_renderer:copy(fog_texture, {x = 0, y = 0, w = hex_w, h = hex_h} , dst))
      end
   end

   local show_grid = engine.options.show_grid

   -- draw nation flag
   local nation = self.data.nation
   if (nation) then
	  -- print("flag for " .. nation.data.name)
	  local nation_flag_width = nation.flag.w
	  local nation_flag_height = nation.flag.h
	  local flag_x = x  + math.modf((hex_w - nation_flag_width) / 2)
	  local flag_y = y + math.modf((hex_h - nation_flag_height - 2))
	  local objective = self.data.objective
	  nation:draw_flag(sdl_renderer, flag_x, flag_y, objective)
   end

   -- draw grid
   if (show_grid) then
      local icon_texture = terrain:get_icon('grid')
      assert(sdl_renderer:copy(icon_texture, self.grid_rectange, dst))
   end

   -- draw unit
   if (self.unit) then
      self.unit:draw(sdl_renderer, x, y)
   end
end

function Tile:distance_to(other_tile)
   --[[
      calculate the distance in tile coordinates, see hex grid geometry
      http://playtechs.blogspot.com.by/2007/04/hex-grids.html
   --]]
   local dx = self.data.tile_x - other_tile.data.tile_x
   local dy = self.data.tile_y - other_tile.data.tile_y
   local value = (math.abs(dx) + math.abs(dy) + math.abs(dy - dx)) / 2

   return value;
end

return Tile
