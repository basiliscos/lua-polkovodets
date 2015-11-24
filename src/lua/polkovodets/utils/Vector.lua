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

local Vector = {}
Vector.__index = Vector

function Vector.create(values)
   assert(type(values) == 'table', "vector values must be presented as table")
   for idx, v in pairs(values) do
      assert(type(v) == 'number', "value at " .. idx .. " (" .. v .. ") isn't a number")
   end
   local o = {data = values}
   setmetatable(o, Vector)
   return o
end

function Vector.__le(a, b)
   local r = true
   assert(#a.data == #b.data, "vectors should be the same size")
   for idx, a_value in pairs(a.data) do
      local b_value = b.data[idx]
      r = r and (a_value <= b_value)
   end
   return r
end

function Vector.__add(a,b)
   local r = {}
   -- print("a = " .. inspect(a))
   -- print("b = " .. inspect(b))
   assert(#a.data == #b.data, "vectors should be the same size")
   for idx, a_value in pairs(a.data) do
      local b_value = b.data[idx]
      r[idx] = (a_value == math.maxinteger or b_value == math.maxinteger)
         and math.maxinteger
         or a_value + b_value
   end
   return Vector.create(r)
end

function Vector.__sub(a,b)
   local r = {}
   -- print("a = " .. inspect(a))
   -- print("b = " .. inspect(b))
   assert(#a.data == #b.data, "vectors should be the same size")
   for idx, a_value in pairs(a.data) do
      local b_value = b.data[idx]
      r[idx] = (a_value == math.mininteger or b_value == math.mininteger)
         and math.mininteger
         or a_value - b_value
   end
   return Vector.create(r)
end

function Vector:min()
   if (self._min ~= nil) then return self._min end
   local m = math.maxinteger
   for idx, v in pairs(self.data) do
      if (m > v) then m = v end
   end
   self._min = m
   return m
end



return Vector
