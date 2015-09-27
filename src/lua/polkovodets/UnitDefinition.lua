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

local UnitDefinition = {}
UnitDefinition.__index = UnitDefinition

function UnitDefinition.create(engine, data)
   local unit_lib = engine.unit_lib

   assert(data.id)
   assert(data.name)
   assert(data.class)
   assert(unit_lib.classes[data.class])
   assert(data.target_type)
   assert(unit_lib.target_types[data.target_type])
   assert(data.move_type)
   assert(unit_lib.move_types[data.move_type])
   assert(data.nation)
   -- if nation is 'none' that it is not allowed to purchase unit
   if (data.nation ~= 'none') then
      assert(engine.nation_for[data.nation], "Unit nation '" .. data.nation .. "' isn't present among scenatio nations")
   end

   assert(data.movement)
   assert(data.initiative)
   assert(data.spotting)
   assert(data.fuel)
   assert(data.range)
   assert(data.ammo)
   assert(data.def_ground)
   assert(data.def_air)
   assert(data.def_close)
   assert(data.flags)
   assert(data.icon_id)
   assert(data.start_year)
   assert(data.start_month)
   assert(data.last_year)
   assert(data.attack)
   assert(data.attack.count)

   for target_id, v in pairs(unit_lib.target_types) do
      assert(data.attack[target_id], "no attack value tor target '" .. target_id .. "'")
   end

   local o = {
      engine = engine,
      data = data,
   }
   setmetatable(o, UnitDefinition)
   return o
end

return UnitDefinition
