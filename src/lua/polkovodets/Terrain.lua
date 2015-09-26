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

local Terrain = {}
Terrain.__index = Terrain

local Parser = require 'polkovodets.Parser'


function Terrain.create(engine)
   local o = {
      engine = engine,
      icons = {
      }
   }
   setmetatable(o, Terrain)
   return o
end


function Terrain:load(terrain_file)
   local engine = self.engine
   local path = engine.get_terrains_dir() .. '/' .. terrain_file
   print('loading terrain ' .. path)
   local parser = Parser.create(path)
   self.parser = parser

   -- hex tile geometry
   self.hex_width = tonumber(parser:get_value('hex_width'))
   self.hex_height = tonumber(parser:get_value('hex_height'))
   self.hex_x_offset = tonumber(parser:get_value('hex_x_offset'))
   self.hex_y_offset = tonumber(parser:get_value('hex_y_offset'))

   -- load icons
   local icons_dir = self.engine:get_terrain_icons_dir()
   local load_icon = function(key)
      local icon_file = parser:get_value(key)
      assert(icon_file, "cannot find icon for '" .. key .. "' in " .. path)
      local path = icons_dir .. '/' .. icon_file
      self.icons[key] = path
      engine.renderer:load_texture(path)
   end
   load_icon('grid')

   -- load terrain hexes
   local terrain_images = {} -- key: terrain key, value - table[weather key:icon_path]
   local terrains_for = self.parser:get_value('terrain')
   local renderer = engine.renderer
   local iterator_factory = function(surface) return renderer:create_simple_iterator(surface, self.hex_width, 0) end

   for key,terrain_data in pairs(terrains_for) do
      local images_for = assert(terrain_data.image)
      local weather_images = {}
      for weather, image_file in pairs(images_for) do
         local path = icons_dir .. '/' .. image_file
         renderer:load_joint_texture(path, iterator_factory)
         weather_images[weather] = path
      end
      terrain_images[key] = weather_images
   end
   self.terrain_images = terrain_images
end

function Terrain:get_type(name)
   -- name 1-symbol
   local terrains_for = self.parser:get_value('terrain')
   assert(terrains_for)

   local terrain_type = terrains_for[name]
   assert(terrain_type, "terrain " .. name .. " not found")
   return terrain_type
end


function Terrain:get_hex_image(terrain_key, weather, index)
   local weather_images = assert(self.terrain_images[terrain_key], "no terrain for " .. terrain_key)
   local texture_path = assert(weather_images[weather])
   return self.engine.renderer:get_joint_texture(texture_path, index + 1)
end


function Terrain:get_icon(name)
   local icon_path = assert(self.icons[name], "no terrain icon for " .. name)
   return self.engine.renderer:load_texture(icon_path)
end

return Terrain
