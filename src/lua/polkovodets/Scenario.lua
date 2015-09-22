local Scenario = {}
Scenario.__index = Scenario

local Map = require 'polkovodets.Map'
local Parser = require 'polkovodets.Parser'

function Scenario.create(engine)
   local o = { engine = engine }
   setmetatable(o, Scenario)
   return o
end


function Scenario:load(file)
   local engine = self.engine

   local path = self.engine.get_scenarios_dir() .. '/' .. file
   print('scenario map at ' .. path)
   local parser = Parser.create(path)
   self.name = assert(parser:get_value('name'))
   self.description = assert(parser:get_value('desc'))
   self.authors = assert(parser:get_value('authors'))
   self.start_date = assert(parser:get_value('date'))
   self.turns = assert(tonumber(parser:get_value('turns')))
   self.days_per_turn = assert(tonumber(parser:get_value('days_per_turn')))
   local map_file = assert(parser:get_value('map'))

   local map = Map.create(engine)
   map:load(map_file)
   engine:set_map(map)

   local weather_data = parser:get_list_value('weather')
   self.weather = weather_data
   engine:set_scenario(self)

end

return Scenario
