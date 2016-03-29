--[[

Copyright (C) 2015, 2016 Ivan Baidakou

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

local Terrain = {}
Terrain.__index = Terrain

local Parser = require 'polkovodets.Parser'


function Terrain.create()
   local o = {
      engine = nil,
      icons = { }
   }
   setmetatable(o, Terrain)
   return o
end

function Terrain:initialize(renderer, terrain_data, dirs_data)
  self.renderer = renderer
  local hex_geometry       = assert(terrain_data.hex_geometry)
  local weather_types_data = assert(terrain_data.weather_types)
  local terrain_types_data = assert(terrain_data.terrain_types)
  local icon_for           = assert(terrain_data.icons)

   -- hex tile geometry
  self.hex_width    = tonumber(hex_geometry['width'])
  self.hex_height   = tonumber(hex_geometry['height'])
  self.hex_x_offset = tonumber(hex_geometry['x_offset'])
  self.hex_y_offset = tonumber(hex_geometry['y_offset'])

  -- load generic landscape icons
  local load_icon = function(key)
    local icon_file = icon_for[key]
    assert(icon_file, "cannot find icon for '" .. key .. "'")
    local path = dirs_data.gfx .. '/' .. icon_file
    self.icons[key] = path
    renderer:load_texture(path)
  end
  load_icon('grid')
  load_icon('frame')
  load_icon('fog')
  load_icon('managed')
  load_icon('participant')

  -- hard-coded value
  local fog_image = self:get_icon('fog')
  assert(fog_image.texture:setAlphaMod(40))

   -- weather
   local weather = {}
   for k, data in pairs(weather_types_data) do
      local id = assert(data.id)
      weather[id] = data
   end
   self.weather = weather


   -- terrain types
   local terrain_images = {} -- key: terrain key, value - table[weather key:icon_path]
   local hex_width = self.hex_width
   local iterator_factory = function(surface) return renderer:create_simple_iterator(surface, hex_width, 0) end

   local terrain_types = {}
   for k, data in pairs(terrain_types_data) do
      local id = assert(data.id)
      terrain_types[id] = data
      assert(data.image)
      assert(data.spot_cost)

      local image_for = {}
      for weather_id, image_path in pairs(data.image) do
         assert(weather[weather_id], "weather type " .. weather_id .. " must exist")
         local full_path = dirs_data.gfx .. '/' .. image_path
         renderer:load_joint_texture(full_path, iterator_factory)
         image_for[weather_id] = full_path
      end

      -- validate, that all weather images exist
      for _, weather in pairs(weather) do
        local weather_id = weather.id
        local image_path = assert(data.image[weather_id], "no image for terrain '" .. id .. "' on wheather '" .. weather_id .. "'")
        local full_path = dirs_data.gfx .. '/' .. image_path
        renderer:load_joint_texture(full_path, iterator_factory)
        image_for[weather_id] = full_path
      end

      -- validate, that all spot cost exists for all weather
      for _, weather in pairs(weather) do
        local weather_id = weather.id
        assert(data.spot_cost[weather_id], "no spot cost for terrain '" .. id .. "' on wheather '" .. weather_id .. "'")
      end

      local numerize_weather = function(data)
         for weather_id, value in pairs(data) do
            assert(weather[weather_id])
            assert(value)
            local number_value = tonumber(value)
            assert(number_value or (value == 'A' or value == 'X'),
                   "invalid movement cost " .. value .. " for terrain/weather " .. id .. "/" .. weather_id)
            data[weather_id] = number_value or value
         end
      end

      for movement_type, data in pairs(assert(data.move_cost)) do
         numerize_weather(data)
      end
      numerize_weather(data.spot_cost)
      terrain_images[id] = image_for
   end
   self.terrain_images = terrain_images
   self.terrain_types = terrain_types
end

function Terrain:get_type(name)
   -- name 1-symbol
   local terrains_for = self.terrain_types
   assert(terrains_for)

   local terrain_type = terrains_for[name]
   assert(terrain_type, "terrain " .. name .. " not found")
   return terrain_type
end


function Terrain:get_hex_image(terrain_key, weather, index)
  local weather_images = assert(self.terrain_images[terrain_key], "no terrain for " .. terrain_key)
  local texture_path = assert(weather_images[weather],
                             string.format("no image #%d for terrain/weater %s/%s", index, terrain_key, weather))
  return self.renderer:get_joint_texture(texture_path, index + 1)
end


function Terrain:get_icon(name)
   local icon_path = assert(self.icons[name], "no terrain icon for " .. name)
   return self.renderer:load_texture(icon_path)
end

return Terrain
