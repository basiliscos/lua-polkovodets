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

local UnitDefinition = {}
UnitDefinition.__index = UnitDefinition

function UnitDefinition.create(engine, data)
   local unit_lib = engine.unit_lib

   assert(data.id)
   assert(data.name)
   assert(data.unit_class)
   assert(data.staff)
   assert(data.size)
   assert(data.nation)
   assert(data.flags)
   assert(string.find(data.size, '[LMS]'))

   local unit_class = assert(unit_lib.units.classes[data.unit_class])
   local unit_type_id = unit_class['type']
   local unit_type = assert(unit_lib.units.types[unit_type_id], "type " .. unit_type_id .. " not found")

   assert(data.icons)
   local state_icons = {}
   for state, path in pairs(data.icons) do
      local full_path = engine:get_gfx_dir() .. '/' .. path
      local texture = engine.renderer:load_texture(full_path)
      state_icons[state] = texture
   end
   if (unit_type_id == 'ut_land') then
      assert(state_icons.attacking, 'land unit must have "attacking" icon')
      assert(state_icons.defending, 'land unit must have "defending" icon')
      assert(state_icons.marching, 'land unit must have "marching" icon')
   elseif (unit_type_id == 'ut_air') then
      assert(state_icons.flying, 'air unit must have "flying" icon')
      assert(state_icons.landed, 'air unit must have "landed" icon')
   end

   local nation = assert(engine.nation_for[data.nation])

   local o = {
      engine      = engine,
      data        = data,
      state_icons = state_icons,
      unit_type   = unit_type,
      unit_class  = unit_class,
      nation      = nation,
   }
   setmetatable(o, UnitDefinition)
   return o
end

function UnitDefinition:get_icon(state)
   assert(state)
   local texture = assert(self.state_icons[state], "no icon for " .. state .. " for unit defintion " .. self.data.id)
   return texture
end


function UnitDefinition:is_capable(flag_mask)
   for flag, value in pairs(self.data.flags) do
      if (string.find(flag, flag_mask)) then return flag, value end
   end
end


return UnitDefinition
