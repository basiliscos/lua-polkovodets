--[[

Copyright (C) 2015, 2016 Ivan Baidakou

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

local WeaponInstance = {}
WeaponInstance.__index = WeaponInstance

function WeaponInstance.create(engine, weapon_id, unit_id, quantity)
   assert(weapon_id)
   assert(unit_id)
   local id = "u:" .. unit_id .. "/w:" .. weapon_id
   local unit_lib = engine.unit_lib
   local weapon = assert(unit_lib.weapons.definitions[weapon_id], " weapon " .. weapon_id .. " is not available")
   local movement = weapon.data.movement
   local o = {
      id      = id,
      weapon  = weapon,
      unit_id = unit_id,
      data = {
         can_attack = true,
         movement   = movement,
         quantity   = quantity,
      }
   }
   setmetatable(o, WeaponInstance)
   return o
end

function WeaponInstance:quantity() return self.data.quantity end

function WeaponInstance:refresh()
   self.data.movement = self.weapon.data.movement
   self.data.can_attack = true
end

function WeaponInstance:is_capable(flag_mask)
   return self.weapon:is_capable(flag_mask)
end

function WeaponInstance:update_state(new_state)
   local attacks_first = self:is_capable('ATTACKS_FIRST')
   if (new_state == 'marching' and attacks_first) then
      self.data.can_attack = false
   end
end

function WeaponInstance:get_class()
  return self.weapon.class
end

return WeaponInstance
