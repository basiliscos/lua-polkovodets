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
local BattleFormula = require 'polkovodets.BattleFormula'
local BattleScheme = require 'polkovodets.BattleScheme'
local Parser = require 'polkovodets.Parser'
local Weapon = require 'polkovodets.Weapon'
local UnitDefinition = require 'polkovodets.UnitDefinition'


function UnitLib.create(engine)
   local o = {
      engine = engine,
      weapons = {},
      units = {},
      icons = {},
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
         if (data.flags) then
            if (type(data.flags) == 'string') then data.flags = {data.flags} end
         else
            data.flags = {}
         end
      end
      return hash
   end
   --------------------------
   -- load weapons section --
   --------------------------
   local weapons_data = assert(parser:get_value('weapons'))

   -- load all simple definitions
   self.weapons.movement_types = load_hash(weapons_data, 'movement_types')
   self.weapons.target_types = load_hash(weapons_data, 'target_types')
   self.weapons.classes = load_hash(weapons_data, 'classes')
   self.weapons.categories = load_hash(weapons_data, 'categories')
   self.weapons.types = load_hash(weapons_data, 'types')

   -- make unit_lib available via engine
   engine.unit_lib = self

   -- load main weapon definitions
   local weapons_file = assert(weapons_data.list)
   local weapon_definitions = {}
   for k, data in pairs(Parser.create(definitions_dir .. '/' .. weapons_file):get_raw_data()) do
      data.movement = tonumber(data.movement)
      local w = Weapon.create(engine, data)
      weapon_definitions[w.id] = w
   end
   self.weapons.definitions = weapon_definitions;

   -----------------------------------
   -- load unit definitions section --
   -----------------------------------
   local units_data = assert(parser:get_value('units'))
   local unit_types = load_hash(units_data, 'types')
   local unit_classes = load_hash(units_data, 'classes')
   -- validate classes by types
   for idx, class in pairs(unit_classes) do
      local t = class.type
      assert(unit_types[t], "unknown unit type " .. t .. " for unit class " .. idx)
   end

   -- make types & classes be accessible for units
   self.units = {
      types       = unit_types,
      classes     = unit_classes,
   }

   local units_file = assert(units_data.definitions)
   local unit_definitions = {}
   for k, data in pairs(Parser.create(definitions_dir .. '/' .. units_file):get_raw_data()) do
      local id = assert(data.id)
      local nation = assert(data.nation, "no nation for unit definition " .. id)
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
   self.units.definitions = unit_definitions

   -- load battle schema
   local battle_scheme_file = parser:get_value('battle_scheme')
   local battle_scheme = BattleScheme.create(engine)
   battle_scheme:load(definitions_dir .. '/' .. battle_scheme_file)

   local battle_formula = BattleFormula.create(engine)
   engine.battle_formula = battle_formula
end

return UnitLib
