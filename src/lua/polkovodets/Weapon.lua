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
local _ = require ("moses")

local Weapon = {}
Weapon.__index = Weapon

function Weapon.create()
  return setmetatable({}, Weapon)
end

function Weapon:initialize(renderer, weapon_data, classes_for, types_for, category_for, movement_type_for, target_type_for, nation_for)
  local id              = assert(weapon_data.id)
  local name            = assert(weapon_data.name)
  local w_class         = assert(weapon_data.weap_class)
  local w_type          = assert(weapon_data.weap_type)
  local w_category      = assert(weapon_data.weap_category)
  local w_movement_type = assert(weapon_data.move_type)
  local w_target_type   = assert(weapon_data.target_type)
  assert(weapon_data.movement >= 0)

  local nation = assert(weapon_data.nation)
  assert(weapon_data.attack)
  local attacks = {}
  for k, v in pairs(weapon_data.attack) do
    attacks[k] = tonumber(v)
  end

  assert(weapon_data.defence)
  local defends = {}
  for k, v in pairs(weapon_data.defence) do
    defends[k] = tonumber(v)
    assert(defends[k] > 0,  k .. " defence should be strictly positive for weapon " .. id)
  end

  assert(weapon_data.range)
  local range = {}
  for k, v in pairs(weapon_data.range) do
    v = tonumber(v)
    assert(v >= 0, k .. " range should be non-negative")
    range[k] = v
  end

  local class = assert(classes_for[w_class], 'no weapon class "' .. w_class .. '" for weapon ' .. id)
  local weapon_type = assert(types_for[w_type], 'no weapon type "' .. w_type .. '" for weapon ' .. id)
  local category = assert(category_for[w_category], "category '" .. w_category .. "' is not available for weapon " .. id)
  local movement_type = assert(movement_type_for[w_movement_type], "movement type '" .. w_movement_type .. "' is not available for weapon " .. id)
  local target_type = assert(target_type_for[w_target_type], "target type '" .. w_target_type .. "' is not available for weapon " .. id)

  nation = assert(nation_for[nation], "nation " .. nation .. " not availble for weapon " .. id)

  -- validate attack types
  for attack_type, v in pairs(target_type_for) do
    local exists = attacks[attack_type] or attacks[attack_type] == 0
    assert(exists, "attack " .. attack_type .. " isn't present in weapon " .. id)
  end

  -- gather all flags
  local flags = {}
  _.each({category.flags, class.flags, class.flags, weapon_type.flags, weapon_data.flags},
    function(_, flags_map)
      for flag, value in pairs(flags_map) do
        flags[flag] = value
      end
    end
  )

  self.id            = id
  self.name          = name
  self.class         = class
  self.weapon_type   = weapon_type
  self.category      = category
  self.movement_type = movement_type
  self.movement      = weapon_data.movement
  self.target_type   = target_type
  self.attacks       = attacks
  self.defends       = defends
  self.flags         = flags
  self.range         = range
end

function Weapon:is_capable(flag_mask)
  for flag, value in pairs(self.flags) do
    if (string.find(flag, flag_mask)) then return flag, value end
  end
end

function Weapon:capabilities_iterator(filter)
    local flags = _.keys(self.flags)
    local idx = 0
    local iterator = function()
        idx = idx + 1
        while (idx <= #flags) do
            local flag = flags[idx]
            local value = self.flags[flag]
            if (filter(flag, value)) then
                return flag, value
            end
            idx = idx + 1
        end
    end
    return iterator, nil, true
end

return Weapon
