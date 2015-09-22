local Parser = {}
Parser.__index = Parser
local inspect = require('inspect')

function Parser.create(path)
   print("opening " .. path)
   local file = io.open(path , "r")
   local signature = file:read('*l')
   if (signature ~= '@') then error("Map file " .. path .. " has wrong signature") end
   local data = {}
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
		 -- unpack array
		 if (data[section_name]["--container--"]) then
			data[section_name] = data[section_name]["--container--"]
		 end
		 child["--section_name--"] = nil
	  elseif (string.find(line,'»', 1, true)) then  -- property
		 local separator_idx = string.find(line,'»', 1, true)
		 if (not separator_idx) then error("cannot find separator in line " .. line_idx) end
		 local key = string.sub(line, 1, separator_idx-1)
		 local value = string.sub(line, separator_idx+1, -1)
		 -- print( key .. ':' .. value)
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
   local v = self.data[key]
   if (not v) then error(key .. " not found in " .. self.path) end
   return v
end

function Parser:get_list_value(key)
   local v = self:get_value(key)
   local list = {}
   -- %.+°?
   for item in string.gmatch(v, '[^°]+') do
	  list[ #list + 1] = item
   end
   return list
end

function Parser:get_raw_data()
   return self.data
end

return Parser
