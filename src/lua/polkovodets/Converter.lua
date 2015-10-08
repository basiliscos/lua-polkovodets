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

local inspect = require('inspect')

local Converter = {}
Converter.__index = Converter

function Converter.create(line_iterator)
   assert(line_iterator)
   local o = {
      line_iterator = line_iterator
   }
   setmetatable(o, Converter)
   return o
end


function Converter:_analyze_header()
   local iterator = self.line_iterator
   local header = assert(iterator(), "error reading header")
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
   self.columns = column - 1
   self.structure_at = structure_at
   -- print(inspect(structure_at))
end

function Converter:_convert_csv()
   local columns = self.columns
   local structure_at = self.structure_at
   local iterator = self.line_iterator


   local items = {}
   local stack = {}

   -- local current_item
   -- local last_hash
   -- local last_key

   local push_out = function()
      if (#stack) then
         table.insert(items, table.remove(stack))
      end
   end


   local push_value = function(value, column)
      local cmd = structure_at[column]

      -- print("value (" .. column .. ") " .. value)
      if (column == 1 and #value >0 ) then
         push_out()       -- push the current one (if exists)
         table.insert(stack, {}) -- start new item
      elseif (column == 1  and not (#value >0)) then
         -- ignore empty column
         return
      end

      if (cmd.command == 'put' and #value > 0) then
         stack[#stack][cmd.to] = value
         -- print(string.format("put %s -> %s", value, cmd.to))
      elseif (cmd.command == 'put.key') then
         table.insert(stack, value)
         -- print(string.format("put key %s", value))
      elseif (cmd.command == 'put.value') then
         -- print(string.format("put value %s", value))
         local key = table.remove(stack)
         stack[#stack][key] = value
      elseif ((cmd.command == 'zoom-in') or (cmd.command == 'hash.start')) then
         local value = stack[#stack][cmd.to] or {}
         stack[#stack][cmd.to] = value
         table.insert(stack, value)
      elseif ((cmd.command == 'zoom-out') or (cmd.command == 'hash.finish')) then
         table.remove(stack)
      end
   end


   local line = iterator()
   while (line) do
      local column = 1
      for value in string.gmatch(line, '[^;]*;?') do
         --  remove the last ;
         if (column < #structure_at) then
            value = string.sub(value, 1, -2)
         end
         if (column <= columns) then
            -- print("v: " .. column .. " " .. (value or 'nil'))
            push_value(value, column)
            column = column + 1
         end
      end
      line = iterator()
   end
   -- push the current item into list of items
   push_out()
   return items
end

function Converter:convert()
   self:_analyze_header()
   return self:_convert_csv()
end

return Converter
