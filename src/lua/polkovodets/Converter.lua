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
   local has_sparse_hash = false
   for h in string.gmatch(header, '[^;]*;?') do
      -- remove the last ;
      if (string.sub(h, -1, #h) == ';') then  h = string.sub(h, 1, -2) end
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
      elseif (string.find(h, '^', 1, true) == 1) then
         structure_at[column] = { command = 'sparse-hash.start', to = string.sub(h, 2) }
         has_sparse_hash = true
      elseif (h == '/^') then
         structure_at[column] = { command = 'sparse-hash.finish' }
         has_sparse_hash = false
      else
         if (has_hash) then
            assert(structure_at[column -1].command == 'hash.start' or structure_at[column -2].command == 'hash.start')
            local cmd = structure_at[column -1].command == 'hash.start'
               and 'put.key'
               or 'put.value'
            structure_at[column] = {command = cmd}
         elseif (has_sparse_hash) then
            structure_at[column] = {command = "sparse-hash.process"}
         elseif (#h > 0) then
            structure_at[column] = {command = 'put', to = h}
          else
            structure_at[column] = { command = 'ignore'}
         end
      end
      column = column + 1
      -- print(h)
   end
   self.columns = column - 1
   self.structure_at = structure_at
   -- print("headers: " .. #structure_at .. " : " .. inspect(structure_at))
end

function Converter:_convert_csv()
   local columns = self.columns
   local structure_at = self.structure_at
   local iterator = self.line_iterator


   local items = {}
   local stack = {}

   local push_out = function()
      if (#stack) then
         table.insert(items, table.remove(stack))
      end
   end


   local push_value = function(value, column)
      local cmd = structure_at[column]

      -- print("value (" .. column .. ") " .. value)
      if (column == 1 and (#value >0 or #stack == 0) ) then
         push_out()       -- push the current one (if exists)
         table.insert(stack, {}) -- start new item
      elseif (column == 1  and not (#value >0)) then
         -- ignore empty column
         return
      end

      if (cmd.command == 'put' and #value > 0) then
         stack[#stack][cmd.to] = value
         -- print(string.format("put %s -> %s", value, cmd.to))
      elseif (cmd.command == 'put.key' and #value > 0) then
         table.insert(stack, value)
         -- print(string.format("put key %s", value))
      elseif (cmd.command == 'put.value' and #value > 0) then
         local key = table.remove(stack)
         -- print(string.format("put value %s ->%s", key, value))
         stack[#stack][key] = value
      elseif ((cmd.command == 'zoom-in') or (cmd.command == 'hash.start')) then
         local value = stack[#stack][cmd.to] or {}
         stack[#stack][cmd.to] = value
         table.insert(stack, value)
      elseif ((cmd.command == 'zoom-out') or (cmd.command == 'hash.finish')) then
         table.remove(stack)
      elseif (cmd.command == 'sparse-hash.start') then
         local value = stack[#stack][cmd.to] or {}
         stack[#stack][cmd.to] = value
         table.insert(stack, value)
         table.insert(stack, '_/EMPTY/_')
      elseif (cmd.command == 'sparse-hash.finish') then
         local value = table.remove(stack)
         assert(value == '_/EMPTY/_', "stack must contain empty marker after end of processing sparse hash")
         -- remove hash itself
         table.remove(stack)
      elseif (cmd.command == 'sparse-hash.process') then
         -- ignore empty values
         if (#value > 0) then
           local top = table.remove(stack)
           if (top == '_/EMPTY/_') then
             -- just put key on the stack
             table.insert(stack, value)
           else
             -- pop key & hash, update hash with key = value, put hash back with empty marker
             local key = top
             local hash = table.remove(stack)
             hash[key] = value
             table.insert(stack, hash)
             table.insert(stack, '_/EMPTY/_')
             -- print (key .. " => " .. value)
           end
         end
      end

   end


   local line = iterator()
   while (line) do
      local success, msg = pcall(function()
        local column = 1
        for value in string.gmatch(line, '[^;]*;?') do
           --  remove the last ;
           if (string.sub(value, -1, #value) == ';') then
              value = string.sub(value, 1, -2)
           end
           if (column <= columns) then
              -- print("v: " .. column .. " " .. (value or 'nil'))
              if (string.find(value, '#', nil, true)) then -- make a list of values
                local array = {}
                for v in string.gmatch(value, '([^#]+)#?') do
                  table.insert(array, v)
                end
                value = array
              elseif (string.find(value, '\\')) then -- windows backslashes => unix slashes
                 value = string.gsub(value, '\\', '/')
              end
              push_value(value, column)
              column = column + 1
           end
        end
      end)
      if (not success) then
        error("cannot convert line " .. line .. " : "  .. msg .. ", stack: " .. inspect(stack))
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
