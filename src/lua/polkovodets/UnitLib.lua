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

local inspect = require('inspect')
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
   local definitions_dir = engine.get_definitions_dir()
   local path = definitions_dir .. '/' .. unit_file
   print('loading armed forces ' .. path)
   local parser = Parser.create(path)

   local load_hash = function(parent, key)
      local file = assert(parent[key])
      local parser = Parser.create(definitions_dir .. '/' .. file)
      local hash = {}
      for k, data in pairs(parser:get_raw_data()) do
         local id = assert(data.id)
         hash[id] = data
      end
      return hash
   end
   --------------------------
   -- load weapons section --
   --------------------------
   local weapons_data = assert(parser:get_value('weapons'))

   -- load all simple definitions
   local movement_types = load_hash(weapons_data, 'movement_types')
   local target_types = load_hash(weapons_data, 'target_types')
   local classes = load_hash(weapons_data, 'classes')
   local categories = load_hash(weapons_data, 'categories')
   local types = load_hash(weapons_data, 'types')

   -- load main weapon definitions
   local weapons_file = assert(weapons_data.list)
   local weapon_definitions = {}
   for k, data in pairs(Parser.create(definitions_dir .. '/' .. weapons_file):get_raw_data()) do
      local id = assert(data.id)
      local w_class = assert(data.weap_class)
      local w_type = assert(data.weap_type)
      local w_category = assert(data.weap_category)
      local movement_type = assert(data.move_type)
      local target_type = assert(data.target_type)
      data.movement = assert(tonumber(data.movement))
      data.range = assert(tonumber(data.range) >= 0)
      local nation = assert(data.nation)
      local attacks = assert(data.attack)

      assert(classes[w_class])
      assert(types[w_type])
      assert(categories[w_category], "category " .. w_category .. " is not available")
      assert(movement_types[movement_type])
      assert(target_types[target_type])
      assert(engine.nation_for[nation], "nation " .. nation .. " not availble")

      for attack_type, v in pairs(target_types) do
         local exists = attacks[attack_type] or attacks[attack_type] == 0
         assert(exists, "attack " .. attack_type .. " isn't present in unit " .. id)
      end
      weapon_definitions[id] = data
   end

   self.weapons = {
      movement_types = movement_types,
      target_types   = target_types,
      classes        = classes,
      categories     = categories,
      types          = types,
      definitions    = weapon_definitions,
   }

   -----------------------------------
   -- load unit definitions section --
   -----------------------------------
   local units_data = assert(parser:get_value('units'))
   local unit_classes = load_hash(units_data, 'classes')
   local units_file = assert(units_data.definitions)
   local unit_definitions = {}
   for k, data in pairs(Parser.create(definitions_dir .. '/' .. units_file):get_raw_data()) do
      local id = assert(data.id)
      local nation = assert(data.nation)
      local class = assert(data.unit_class)
      local staff = assert(data.staff)

      assert(unit_classes[class])
      assert(engine.nation_for[nation], "nation " .. nation .. " not availble")
      for weapon_type, quantity in ipairs(staff) do
         assert(quantity)
         assert(types[weapon_type])
         quantity = tonumber(quantity)
         assert(quantity >= 0)
         staff[weapon_type] = quantity
      end
      local unit_definition = UnitDefinition.create(engine, data)
      unit_definitions[id] = unit_definition
   end

   self.units = {
      classes     = unit_classes,
      definitions = unit_definitions,
   }

   -- make unit_lib available via engine
   engine.unit_lib = self
end

return UnitLib
