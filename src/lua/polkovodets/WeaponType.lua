--[[

Copyright (C) 2016 Ivan Baidakou

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

local WeaponType = {}
WeaponType.__index = WeaponType

function WeaponType.create()
  return setmetatable({}, WeaponType)
end

function WeaponType:initialize(weapon_type_data, classes_for)
  local id       = assert(weapon_type_data.id, "weapon type should have id")
  local flags    = assert(weapon_type_data.flags, "weapon type " .. id ..  " should have flags")
  local class_id = assert(weapon_type_data.class_id, "weapon type " .. id .. " should have class_id")
  local class    = assert(classes_for[class_id], "weapon class " .. class_id .. " is not available for weapon type " .. id)

  self.id = id
  self.class = class
  self.flags = flags
end

function WeaponType:is_capable(flag_mask)
  for flag, value in pairs(self.flags) do
    if (string.find(flag, flag_mask)) then return flag, value end
  end
end


return WeaponType
