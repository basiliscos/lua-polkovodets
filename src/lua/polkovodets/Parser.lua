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
local json = require ("dkjson")

local Parser = {}
Parser.__index = Parser

local _JSONParser = {}
_JSONParser.__index = _JSONParser

function _JSONParser.create(path)
   print("opening " .. path)
   local file = assert(io.open(path , "r"))
   local str = file:read('*a')
   local data = json.decode(str)
   local o = { data = data, path = path }
   setmetatable(o, _JSONParser)
   return o
end


function _JSONParser:get_value(key)
   assert(key)
   local v = self.data[key]
   assert(v, key .. " not found in " .. self.path)
   return v
end

function _JSONParser:get_raw_data()
   return self.data
end


function Parser.create(path)
   if (string.find(path, '.json', nil, true)) then
      return _JSONParser.create(path)
   end

   print("opening " .. path)
   local file = io.open(path , "r")
   assert(file, "error opening file at " .. path)
   local signature = file:read('*l')
   if (signature ~= '@') then error("Map file " .. path .. " has wrong signature") end
   local data = {}
   local top_data = data;
   local line = file:read('*l')
   local line_idx = 2
   local depth = 1
   while (line) do

	  if (string.find(line, '<', 1, true) == 1) then  -- section start
		 local section_name = string.sub(line, 2, -1)
		 local section = {["--section_name--"] = section_name, parent = data }
		 depth = depth + 1
		 local prev_data = data[section_name]

		 -- pack as array if we alreay met such a key (section_name)
		 if (prev_data) then
			local container = prev_data["--container--"]
			   and prev_data
			   or { ["--container--"] = { prev_data }}
			data[section_name] = container
			if (not data["--containers--"]) then data["--containers--"] = {} end
			data["--containers--"][section_name] = true
			table.insert(container["--container--"], section)
		 else
			data[section_name] = section
		 end
		 data = section
	  elseif (string.find(line, '>', 1, true) == 1) then  -- section end
	     depth = depth - 10
		 assert(depth)
		 local child = data
		 local section_name = child["--section_name--"]

		 data = child.parent
		 child.parent = nil
		 child["--section_name--"] = nil
		 -- unpack containers
		 if (child["--containers--"]) then
			for container_name,v in pairs(child["--containers--"]) do
			   child[container_name] = child[container_name]["--container--"]
			end
			child["--containers--"] = nil
		 end
	  elseif (string.find(line,'»', 1, true)) then  -- property
		 local separator_idx = string.find(line,'»', 1, true)
		 if (not separator_idx) then error("cannot find separator in line " .. line_idx) end
		 local key = string.sub(line, 1, separator_idx-1)
		 local value = string.sub(line, separator_idx+1, -1)
		 data[key] = value
	  else
		 error("line " .. line_idx .. " is wrong")
	  end

	  line = file:read('*l')
	  line_idx = line_idx + 1
   end
   local p = { data = data, path = path }
   -- print(inspect(data))
   setmetatable(p, Parser)
   return p;
end

function Parser:get_value(key)
   assert(key)
   local v = self.data[key]
   assert(v, key .. " not found in " .. self.path)
   return v
end

function Parser.split_list(value)
   assert(value)
   local list = {}
   for item in string.gmatch(value, '[^°]+') do
	  list[ #list + 1] = item
   end
   return list
end

function Parser:get_list_value(key)
   return Parser.split_list(self:get_value(key))
end

function Parser:get_raw_data()
   return self.data
end

return Parser
