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

local UnitLib = {}
UnitLib.__index = UnitLib

local Parser = require 'polkovodets.Parser'
local UnitDefinition = require 'polkovodets.UnitDefinition'

function UnitLib.create(engine)
   local o = {
      engine = engine,
      icons = {
      }
   }
   setmetatable(o, UnitLib)
   return o
end

function UnitLib:load(unit_file)
   local engine = self.engine
   local path = engine.get_units_dir() .. '/' .. unit_file
   print('loading units ' .. path)
   local parser = Parser.create(path)
   local icon_file = parser:get_value('icons')
   local icons_dir = engine:get_unit_icons_dir()
   local icon_path = icons_dir .. '/' .. icon_file
   self.icons.units = icon_path

   local iterator_factory = function(surface)
      local w,h = surface:getSize()
      local x,y = 0, 0

      -- probes (0,0) as marker and finds x and y markers
      -- of the frame
      local iterator = function(state, value) -- ignored
         local marker = surface:getRawPixel(x, y)
         local x_endpoint = x + 1
         while (x_endpoint <= w) do
            local pixel = surface:getRawPixel(x_endpoint, y)
            if (pixel == marker) then
               break
            end
            x_endpoint = x_endpoint + 1
         end
         assert(x_endpoint <= w, "cannot find x-marker")

         local y_endpoint = y + 1
         while (y_endpoint <= h) do
            local pixel = surface:getRawPixel(0, y_endpoint)
            if (pixel == marker) then
               break
            end
            y_endpoint = y_endpoint + 1
         end
         if ( y_endpoint <= h ) then
            local frame = { x = 0, y = y + 1, w = x_endpoint, h = y_endpoint - y - 1}
            y = y_endpoint + 1
            return frame
         end
      end

      local first_frame = iterator()
      return function() return iterator, nil, first_frame end
   end

   engine.renderer:load_joint_texture(icon_path, iterator_factory)

   -- target types
   local target_types_data = assert(parser:get_value('target_types'))
   local target_types = {}
   for id, data in pairs(target_types_data) do
      target_types[id] = {
         id   = id,
         name = assert(data.name)
      }
   end
   self.target_types = target_types

   -- unit classes
   local classes_data = assert(parser:get_value('unit_classes'))
   local classes_list = {} -- keep order as in database
   local classes = {}
   for id, data in pairs(classes_data) do
      data.id = id
      assert(data.name)
      assert(data.purchase)
      table.insert(classes_list, data)
      classes[id] = data
   end
   self.classes_list = classes_list
   self.classes = classes

   -- unit movement types
   local move_types_data = assert(parser:get_value('move_types'))
   local move_types = {}
   for id, data in pairs(move_types_data) do
      data.id = id
      assert(data.name)
      assert(data.sound)
      move_types[id] = data
   end
   self.move_types = move_types

   -- make unit_lib available via engine
   engine.unit_lib = self

   local units_data = assert(parser:get_value('unit_lib'))
   local unit_definitions = {}
   for id, data in pairs(units_data) do
      data.id = id
      data.initiative = tonumber(data.initiative)
      data.spotting = tonumber(data.spotting)
      data.movement = tonumber(data.movement)
      data.fuel = tonumber(data.fuel)
      data.range = tonumber(data.range)
      data.ammo = tonumber(data.ammo)
      data.attack.count = tonumber(data.attack.count)
      local unit_def = UnitDefinition.create(engine, data)
      table.insert(unit_definitions, unit_def)
   end
   self.unit_definitions = unit_definitions
end

return UnitLib
