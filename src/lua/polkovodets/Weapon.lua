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

local Weapon = {}
Weapon.__index = Weapon

function Weapon.create(engine, data)
   local unit_lib = engine.unit_lib

   local id = assert(data.id)
   local w_class = assert(data.weap_class)
   local w_type = assert(data.weap_type)
   local w_category = assert(data.weap_category)
   local movement_type = assert(data.move_type)
   local target_type = assert(data.target_type)
   assert(data.movement >= 0)
   local nation = assert(data.nation)

   assert(data.attack)
   local attacks = {}
   for k, v in pairs(data.attack) do
    attacks[k] = tonumber(v)
   end

   assert(data.defend)
   local defends = {}
   for k, v in pairs(data.defend) do
    defends[k] = tonumber(v)
   end

   assert(data.range)
   local range = {}
   for k, v in pairs(data.range) do
      v = tonumber(v)
      assert(v >= 0, k .. " range should be non-negative")
      range[k] = v
   end

   local class = assert(unit_lib.weapons.classes.hash[w_class], 'no weapon class "' .. w_class .. '" for weapon ' .. id)
   assert(unit_lib.weapons.types.hash[w_type])
   local category = assert(unit_lib.weapons.categories.hash[w_category], "category " .. w_category .. " is not available")
   assert(unit_lib.weapons.movement_types.hash[movement_type])
   assert(unit_lib.weapons.target_types.hash[target_type])
   assert(engine.nation_for[nation], "nation " .. nation .. " not availble")

   for attack_type, v in pairs(unit_lib.weapons.target_types.hash) do
      local exists = attacks[attack_type] or attacks[attack_type] == 0
      assert(exists, "attack " .. attack_type .. " isn't present in unit " .. id)
   end

   -- gather all flags
   local flags = {}
   for flag, value in pairs(category.flags) do flags[flag] = value end
   for flag, value in pairs(data.flags) do flags[flag] = value end
   -- print(inspect(flags))

   local o = {
      id            = id,
      class         = class,
      weapon_type   = w_type,
      category      = w_category,
      movement_type = movement_type,
      target_type   = target_type,
      attacks       = attacks,
      defends       = defends,
      flags         = flags,
      data          = {
         range    = range,
         movement = data.movement,
      },
   }
   setmetatable(o, Weapon)
   return o
end

function Weapon:is_capable(flag_mask)
   for flag, value in pairs(self.flags) do
      if (string.find(flag, flag_mask)) then return flag, value end
   end
end

return Weapon
