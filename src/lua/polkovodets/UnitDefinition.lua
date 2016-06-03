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

local UnitDefinition = {}
UnitDefinition.__index = UnitDefinition

function UnitDefinition.create()
  return setmetatable({}, UnitDefinition)
end

function UnitDefinition:initialize(renderer, definition_data, unit_classes_for, unit_types_for, nation_for, weapon_types_for, data_dirs)
   assert(definition_data.id)
   assert(definition_data.unit_class)
   assert(definition_data.spotting)
   assert(definition_data.nation)
   assert(string.find(definition_data.size, '[LMS]'))

   local unit_class_id = definition_data.unit_class
   local unit_class = assert(unit_classes_for[unit_class_id], "no class '" .. unit_class_id .. "' found for unit definition " .. definition_data.id)
   local unit_type_id = unit_class['type']
   local unit_type = assert(unit_types_for[unit_type_id], "type " .. unit_type_id .. " not found")

   assert(definition_data.icons)
   local state_icons = {}
   for state, path in pairs(definition_data.icons) do
      local full_path = data_dirs.gfx .. '/' .. path
      local texture = renderer:load_texture(full_path)
      state_icons[state] = texture
   end

   local nation_id = definition_data.nation
   local nation = assert(nation_for[nation_id], "nation '" .. nation_id .. "' not availble for unit definition " .. definition_data.id)
   local staff_size = 0
   for k, v in pairs(definition_data.staff) do staff_size = staff_size + 1 end
   assert(staff_size > 0, "unit definition " .. definition_data.id .. " cannot be without weapons")

   -- validate staff
   local staff = {}
   --print("staff =" .. inspect(definition_data.staff))
   for weapon_type, quantity in pairs(definition_data.staff) do
    assert(quantity)
    quantity = tonumber(quantity)
    assert(quantity >= 0)
    assert(weapon_types_for[weapon_type], "no weapon type " .. weapon_type)
    staff[weapon_type] = quantity
   end

   self.id          = definition_data.id
   self.unit_class  = unit_class
   self.state_icons = state_icons
   self.unit_type   = unit_type
   self.nation      = nation
   self.staff       = staff
   self.name        = assert(definition_data.name)
   self.spotting    = tonumber(definition_data.spotting)
   self.size        = assert(definition_data.size)
   self.flags       = assert(definition_data.flags)
end

function UnitDefinition:get_icon(state)
   assert(state)
   local texture = assert(self.state_icons[state], "no icon for " .. state .. " for unit defintion " .. self.id)
   return texture
end


function UnitDefinition:is_capable(flag_mask)
   for flag, value in pairs(self.flags) do
      if (string.find(flag, flag_mask)) then return flag, value end
   end
end


return UnitDefinition
