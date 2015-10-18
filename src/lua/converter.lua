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

local json = require ("dkjson")
local Converter = require 'polkovodets.Converter'

local show_help = (#arg ~= 3)
   or ((arg[1] ~= 'definitions') and (arg[1] ~= 'scenario'))

if (show_help) then
   local usage = [[
usage: %s type input_dir output_dir
where,
  type       -- is ether definitions or scenario
  input_dir  -- directory with csv files
  output_dir -- directory where conveted files will be stored
                 ]]
   print(string.format(usage, arg[0]))
   return
end

local input_for = {
   definitions = {
      'nations.csv', 'weather-types.csv', 'terrain-types.csv', 'landscape.csv',
      'weapon-types.csv', 'weapon-categories.csv', 'weapon-target-types.csv',
      'weapon-classes.csv', 'weapon-movement-types.csv', 'weapons.csv',
      'unit-types.csv', 'unit-classes.csv', 'unit-definitions.csv',
      'armed-forces.csv',
   },
   scenario = {
      'players.csv', 'objectives.csv', 'army.csv', 'scenario.csv',
   },
}

local kind, in_dir, out_dir = arg[1], arg[2], arg[3]
for k, name in pairs(input_for[kind]) do
   local in_path = in_dir .. '/' .. name
   local in_file = assert(io.open(in_path, 'r'))
   local out_path = out_dir .. '/' .. string.gsub(name, '.csv', '.json')
   local iterator = function() return in_file:read('*l') end
   local converter = Converter.create(iterator)
   print(string.format("converting %s => %s", in_path, out_path))
   local items = converter:convert()
   local out_file = io.open(out_path , "wb")
   local serialized_data = json.encode(#items == 1 and items[1] or items, {indent = true})
   out_file:write(serialized_data)
   out_file:write("\n")
end
