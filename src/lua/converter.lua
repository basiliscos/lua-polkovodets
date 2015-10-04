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
local hashes_exist = false
local has_hash = false
for h in string.gmatch(header, '[^;]+') do
   if (string.find(h, '<') == 1) then
      h = string.sub(h, 2)
      structure_at[column] = { command = 'zoom-in', to = h }
   elseif (h == '/>') then
      structure_at[column] = { command = 'zoom-out' }
   elseif (string.find(h, '_') == 1) then
      structure_at[column] = { command = 'ignore'}
   elseif (string.find(h, '!') == 1) then
      h = string.sub(h, 2)
      structure_at[column] = { command = 'hash.start', to = h}
      has_hash = true
      hashes_exist = true
   elseif (h == '/!') then
      structure_at[column] = { command = 'hash.finish' }
      has_hash = false
   else
      if (has_hash) then
         assert(structure_at[column -1].command == 'hash.start' or structure_at[column -2].command == 'hash.start')
         local cmd = structure_at[column -1].command == 'hash.start'
            and 'put.key'
             or 'put.value'
         structure_at[column] = {command = cmd}
      else
         structure_at[column] = {command = 'put', to = h}
      end
   end
   column = column + 1
   -- print(h)
end

-- print(inspect(structure_at))

local items = {}
local current_item
local last_key
local hash_started = false
local start_line = function(force)
   if (force or (not hashes_exist)) then
      current_item = {}
   end
end

local end_line = function(force)
   if (force or (not hashes_exist)) then
      table.insert(items, current_item)
      current_item = nil
   end
end

local push_value = function(value, column)
   local cmd = structure_at[column]
   if (hashes_exist and column == 1 and #value > 0) then
      -- close hash
      if (current_item) then
         c = current_item
         current_item = current_item._parent
         c._parent = nil
         hash_started = false
         end_line(true)
      end
      start_line(true)
   end

   if (cmd.command == 'put' and #value > 0) then
      -- print(string.format("put %s -> %s", value, cmd.to))
      current_item[cmd.to] = value
   elseif (cmd.command == 'put.key') then
      -- print(string.format("put key %s", value))
      last_key = value
   elseif (cmd.command == 'put.value') then
      -- print(string.format("put value %s", value))
      current_item[last_key] = value
      last_key = nil
   elseif (cmd.command == 'zoom-in') then
      local embedded_obj = { _parent = current_item }
      current_item[cmd.to] = embedded_obj
      current_item = embedded_obj
   elseif (cmd.command == 'hash.start') then
      if (not hash_started) then
         local embedded_obj = { _parent = current_item }
         current_item[cmd.to] = embedded_obj
         current_item = embedded_obj
         hash_started = true
      end
   elseif (cmd.command == 'zoom-out') then
      c = current_item
      current_item = current_item._parent
      c._parent = nil
   end
end


local line = in_file:read('*l')
while (line) do
   local column = 1
   start_line()
   for value in string.gmatch(line, '[^;]*;?') do
      --  remove the last ;
      if (column < #structure_at) then
         value = string.sub(value, 1, -2)
      end
      if (column <= #structure_at) then
         -- print("v: " .. column .. " " .. (value or 'nil'))
         push_value(value, column)
         column = column + 1
      end
   end
   end_line()
   line = in_file:read('*l')
end
-- flush last item
if (hashes_exist) then
   c = current_item
   current_item = current_item._parent
   c._parent = nil
   current_item._parent = nil
   end_line(true)
end


-- print(inspect(items))
local serialized_data = json.encode(items, {indent = true})
out_file:write(serialized_data)
out_file:write("\n")
