--[[

Copyright (C) 2015,2016 Ivan Baidakou

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
local WeaponClass = require 'polkovodets.WeaponClass'
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

function UnitLib:generate(weapons_data, units_data, battle_scheme)
  local engine = self.engine
  local process_hash = function(parent, key, constructor)
    local data_list = assert(parent[key])
    local hash = {}
    local list = {}
    local order = 1
    for k, data in pairs(data_list) do
      local id = assert(data.id)
      if (data.flags) then
        if (type(data.flags) == 'string') then data.flags = {data.flags} end
      else
        data.flags = {}
      end
      data.order = order
      order = order + 1
      local object = constructor and constructor(data) or data
      hash[id] = object
      table.insert(list, object)
    end
    return {hash = hash, list = list}
  end

  ----------------------
  --  weapons section --
  ----------------------
  self.weapons.movement_types = process_hash(weapons_data, 'movement_types')
  self.weapons.target_types = process_hash(weapons_data, 'target_types')
  self.weapons.classes = process_hash(weapons_data, 'classes', function(data) return WeaponClass.create(engine, data) end)
  self.weapons.categories = process_hash(weapons_data, 'categories')
  self.weapons.types = process_hash(weapons_data, 'types')

  -- validate movement types
  local map = engine:get_map()
  local terrain_types = map.terrain.terrain_types
  for i, movement_type in pairs(self.weapons.movement_types.list) do
    for j, terrain_type in pairs(terrain_types) do
      local mt_id = movement_type.id
      local tt_id = terrain_type.id
      assert(terrain_type.move_cost[mt_id],
        "no '" .. mt_id .. "' movement type costs defined on terrain type '" .. tt_id .. "'")
    end
  end

  -- make unit_lib available via engine
  engine.unit_lib = self

  -- load main weapon definitions
  local weapon_definitions = {}
  for k, data in pairs(weapons_data.weapons) do
    data.movement = tonumber(data.movement)
    local w = Weapon.create(engine, data)
    weapon_definitions[w.id] = w
  end
  self.weapons.definitions = weapon_definitions

  -----------------------------------
  -- load unit definitions section --
  -----------------------------------
  local units = {
    types   = process_hash(units_data, 'types'),
    classes = process_hash(units_data, 'classes'),
  }
  -- validate classes by types
  for idx, class in pairs(units.classes.hash) do
    local t = class.type
    assert(units.types.hash[t], "unknown unit type " .. t .. " for unit class " .. idx)
  end

  -- make types & classes be accessible for units
  self.units = units

  -- create & validate unit definitions
  local unit_definitions = {}
  for k, data in pairs(units_data.definitions) do
    local id = assert(data.id)
    local nation = assert(data.nation, "no nation for unit definition " .. id)
    local class = assert(data.unit_class)
    local staff = assert(data.staff)

    assert(units.classes.hash[class], "no class '" .. class .. "' found for unit definition " .. id)
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

  ----------------------------------------------------
  -- finalize: setup battle formula & battle scheme --
  ----------------------------------------------------

  local battle_formula = BattleFormula.create(engine)
  engine.battle_formula = battle_formula

  engine.battle_scheme = battle_scheme
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
    return parser:get_raw_data()
  end

  --------------------------
  -- load weapons section --
  --------------------------
  local weapons_data = assert(parser:get_value('weapons'))
  local weapons_file = assert(weapons_data.list)
  local weapons = {
    target_types   = load_hash(weapons_data, 'target_types'),
    movement_types = load_hash(weapons_data, 'movement_types'),
    classes        = load_hash(weapons_data, 'classes'),
    categories     = load_hash(weapons_data, 'categories'),
    types          = load_hash(weapons_data, 'types'),
    weapons        = Parser.create(definitions_dir .. '/' .. weapons_file):get_raw_data(),
  }

  -----------------------------------
  -- load unit definitions section --
  -----------------------------------
  local units_data = assert(parser:get_value('units'))
  local units_file = assert(units_data.definitions)
  local units = {
    types       = load_hash(units_data, 'types'),
    classes     = load_hash(units_data, 'classes'),
    definitions = Parser.create(definitions_dir .. '/' .. units_file):get_raw_data(),
  }

  -- load battle schema
  local battle_scheme_file = parser:get_value('battle_scheme')
  local battle_scheme = BattleScheme.create(engine)
  battle_scheme:load(definitions_dir .. '/' .. battle_scheme_file)
  self:generate(weapons, units, battle_scheme)
end

return UnitLib
