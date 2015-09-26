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
local UnitLib = require 'polkovodets.UnitLib'
local Parser = require 'polkovodets.Parser'

function Scenario.create(engine)
   local o = { engine = engine }
   setmetatable(o, Scenario)
   return o
end


function Scenario:load(file)
   local engine = self.engine

   local path = self.engine.get_scenarios_dir() .. '/' .. file
   print('loading scenario at ' .. path)
   local parser = Parser.create(path)
   self.name = assert(parser:get_value('name'))
   self.description = assert(parser:get_value('desc'))
   self.authors = assert(parser:get_value('authors'))
   self.start_date = assert(parser:get_value('date'))
   self.turns = assert(tonumber(parser:get_value('turns')))
   self.days_per_turn = assert(tonumber(parser:get_value('days_per_turn')))

   local weather_data = parser:get_list_value('weather')
   self.weather = weather_data


   -- load nations
   local nations_file = assert(parser:get_value('nation_db'))
   local nations_path = engine:get_nations_dir()  .. '/' .. nations_file
   print('loading nations database at ' .. nations_path)
   local nations_parser = Parser.create(nations_path)
   local nations_shared_data = {
	  icon_width = tonumber(nations_parser:get_value('icon_width')),
	  icon_height = tonumber(nations_parser:get_value('icon_height')),
	  icons_image = assert(nations_parser:get_value('icons')),
   }
   local nation_definitions = assert(nations_parser:get_value('nations'))
   -- print(inspect(nation_definitions))

   local nations = {}
   for key, nation_data in pairs(nation_definitions) do
	  nation_data.key = key
	  local nation = Nation.create(engine, nations_shared_data, nation_data)
	  nations[ #nations +1 ] = nation
   end
   engine:set_nations(nations)

   -- load map
   local map_file = assert(parser:get_value('map'))
   local map = Map.create(engine)
   map:load(map_file)
   engine:set_map(map)


   -- setup flags
   local flags_data = (parser:get_value('flags'))['flag']
   local flags = {}
   -- print(inspect(flags_data))
   for key, flag in pairs(flags_data) do
	  local nation = assert(engine.nation_for[flag.nation])
	  local x = tonumber(flag.x) + 1
	  local y = tonumber(flag.y) + 1
	  local objective = tonumber(flag.objective)
	  local tile = map.tiles[x][y]
	  --- print(inspect(tile.data.name))
	  tile.data.nation = nation
	  tile.data.objective = objective
	  table.insert(flags, {x = x, y = y, objective = objective})
   end
   engine:set_flags(flags)

   -- load units db
   local unit_db = assert(parser:get_value('unit_db'))
   local unit_files = {}
   for k, file in pairs(unit_db) do
      table.insert(unit_files, file)
   end
   local unit_lib = UnitLib.create(engine)
   unit_lib:load(unit_files[1]) -- hard-code, support only 1 unit file for now

   engine:set_scenario(self)
end

return Scenario
