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

local Scenario = {}
Scenario.__index = Scenario

local inspect = require('inspect')
local Map = require 'polkovodets.Map'
local Nation = require 'polkovodets.Nation'
local Player = require 'polkovodets.Player'
local Unit = require 'polkovodets.Unit'
local UnitLib = require 'polkovodets.UnitLib'
local WeaponInstance = require 'polkovodets.WeaponInstance'
local Parser = require 'polkovodets.Parser'

function Scenario.create(engine)
   local o = { engine = engine }
   setmetatable(o, Scenario)
   return o
end


function Scenario:load(file)
   local engine = self.engine
   local scenario_file = 'scenario.json'
   local scenarios_dir = self.engine.get_scenarios_dir() ..  '/' .. file

   local path =  scenarios_dir .. '/' .. scenario_file
   print('loading scenario at ' .. path)
   local parser = Parser.create(path)
   self.name = assert(parser:get_value('name'))
   self.description = assert(parser:get_value('description'))
   self.authors = assert(parser:get_value('authors'))
   self.start_date = assert(parser:get_value('date'))
   self.weather = assert(parser:get_value('weather'))

   local files = assert(parser:get_value('files'))

   -- load nations
   local nations_file = assert(files.nations)
   local nations_path = engine:get_definitions_dir() .. '/' .. nations_file
   local nations_parser = Parser.create(nations_path)
   local nation_definitions = nations_parser:get_raw_data()
   -- print(inspect(nation_definitions))
   local nations = {}
   for k, nation_data in pairs(nation_definitions) do
      local id = nation_data.id
	  nation_data.id = id
	  local nation = Nation.create(engine, nation_data)
	  nations[ #nations +1 ] = nation
   end
   engine:set_nations(nations)

   -- load map
   local map_file = assert(files.map, "scenario files has map")
   local map = Map.create(engine)
   map:load(scenarios_dir .. '/' .. map_file)
   engine:set_map(map)

   -- validate weathers
   for idx, weather_id in pairs(self.weather) do
      assert(map.terrain.weather[weather_id], "wrong weather " .. weather_id)
   end

   -- load & setup objectives
   local objectives_file = assert(files.objectives)
   local objectives_parser = Parser.create(scenarios_dir .. '/' .. objectives_file)
   local objectives = {}
   for k, obj_data in pairs(objectives_parser:get_raw_data()) do
      local nation_id = obj_data.nation
	  local nation = assert(engine.nation_for[nation_id], "no nation " .. nation_id .. ' is available')
	  local x = tonumber(obj_data.x) + 1
	  local y = tonumber(obj_data.y) + 1
      table.insert(objectives, obj_data)
	  local tile = map.tiles[x][y]
	  tile.data.nation = nation
	  tile.data.objective = objective
   end
   engine:set_objectives(objectives)

   -- load armed forces (unit lib) db
   local armed_forces_file = assert(files.armed_forces)
   local unit_lib = UnitLib.create(engine)
   unit_lib:load(armed_forces_file)

   -- load players
   local players_file = assert(files.players, "scenario should have players file")
   local players = {}

   local nation_for_player = {} -- used for lookup player
   for order, data in pairs(Parser.create(scenarios_dir .. '/' .. players_file):get_raw_data()) do
      local id = assert(data.id)
      data.order = order
      local nation_id = assert(data.nations)
      assert(engine.nation_for[nation_id])
      data.nations = {nation_id}
      local player = Player.create(engine, data)
      players[id] = player
      for k,nation_id in pairs(player.data.nations) do
         nation_for_player[nation_id] = player
      end
   end
   engine:set_players(players)

   -- 1st pass: load units
   local army_file = assert(files.army)
   local all_units = {}
   local unit_for = {}
   for k, data in pairs(Parser.create(scenarios_dir .. '/' .. army_file):get_raw_data()) do
      local id = assert(data.id)
      assert(data.name)
      local definition_id = assert(data.unit_definition_id)
      local x = tonumber(assert(data.x))
      local y = tonumber(assert(data.y))
      data.entr = tonumber(assert(data.entr))
      data.exp = tonumber(assert(data.exp))
      local staff = assert(data.staff)
      local unit_definition = assert(unit_lib.units.definitions[definition_id],
                                     "unit definiton " .. definition_id .. " not found for unit " .. id
      )
      local staff_instances = {}
      for weapon_id, quantity in pairs(staff) do
         quantity = tonumber(quantity)
         staff_instances[weapon_id] = WeaponInstance.create(engine, weapon_id, id, quantity)
      end
      data.staff = staff_instances
      local nation_id = unit_definition.data.nation
      local player = nation_for_player[nation_id]
      local unit = Unit.create(engine, data, player)
      table.insert(all_units, unit)
      unit_for[id] = unit
   end
   -- 2nd pass: bind hq
   for idx, unit in pairs(all_units) do
      local managed_by = unit.data.managed_by
      if (managed_by) then
         local manager_unit = assert(unit_for[managed_by], "no manager " .. managed_by)
         manager_unit:subordinate(unit)
      end
   end


   engine:set_units(all_units)
   engine:set_scenario(self)
end

return Scenario
