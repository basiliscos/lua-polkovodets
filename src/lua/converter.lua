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
-- local inspect = require('inspect')

local in_filename = assert(arg[1], "1st argumnet - intput csv file")
local out_filename = assert(arg[2], "2nd argumnet - output json file")

local in_file = io.open(in_filename , "r")
local out_file = io.open(out_filename , "wb")
local header = assert(in_file:read('*l'), "error reading header")
local structure_at = {}

local column = 1
for h in string.gmatch(header, '[^;]+') do
   if (string.find(h, '<') == 1) then
      h = string.sub(h, 2)
      structure_at[column] = { command = 'zoom-in', to = h }
   elseif (h == '/>') then
      structure_at[column] = { command = 'zoom-out' }
   else
      structure_at[column] = {command = 'put', to = h}
   end
   column = column + 1
   -- print(h)
end

local items = {}
local current_item
local start_item = function()
   current_item = {}
end

local end_item = function()
   table.insert(items, current_item)
   current_item = nil
end

local push_value = function(value, column)
   local cmd = structure_at[column]
   if (cmd.command == 'put') then
      current_item[cmd.to] = value
   elseif (cmd.command == 'zoom-in') then
      local embedded_obj = { _parent = current_item }
      current_item[cmd.to] = embedded_obj
      current_item = embedded_obj
   elseif (cmd.command == 'zoom-out') then
      c = current_item
      current_item = current_item._parent
      c._parent = nil
   end
end

-- print(inspect(structure_at))

local line = in_file:read('*l')
while (line) do
   local column = 1
   start_item()
   for value in string.gmatch(line, '[^;]+') do
      push_value(value, column)
      column = column + 1
   end
   end_item()
   line = in_file:read('*l')
end

local serialized_data = json.encode(items, {indent = true})
out_file:write(serialized_data)
out_file:write("\n")
-- print(inspect(items))
--print(
