local Scenario = {}
Scenario.__index = Scenario

local inspect = require('inspect')
local Map = require 'polkovodets.Map'
local Nation = require 'polkovodets.Nation'
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
	  -- tiles are indexed from 1 in lua, and from 0 in db-files
	  local x = tonumber(flag.x)+1
	  local y = tonumber(flag.y)+1
	  local objective = tonumber(flag.objective)
	  local tile = map.tiles[y][x]
	  -- print(inspect(tile.data))
	  tile.data.nation = nation
	  tile.data.objective = objective
	  table.insert(flags, {x = x, y = y, objective = objective})
   end
   engine:set_flags(flags)

   engine:set_scenario(self)
end

return Scenario
