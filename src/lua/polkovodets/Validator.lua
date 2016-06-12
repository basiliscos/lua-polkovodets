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

local Validator = {}
Validator.__index = Validator

local _ = require ("moses")
local inspect = require('inspect')

function Validator.declare(gear)

  gear:declare("validators/terrain/flags", {
    dependencies = {"terrain"},
    constructor  = function() return { name = "terrain type flags"} end,
    initializer  = function(gear, instance, terrain)
      instance.fn = function()
        for id, terrain_type in pairs(terrain.terrain_types) do
          for flag, value in pairs(terrain_type) do
            if (flag == 'ATTACK_CHANGES_TO' or flag == 'BUILD_CHANGES_TO') then
              assert(terrain.terrain_types[value], "flag value '" .. value .. "' for flag" ..  flag .. " for terrain type " .. id .. " is invalid")
            end
          end
        end
        print("terrain type flags are valid")
      end
    end,
  })

  gear:declare("validators/weapons/movement_types", {
    dependencies = {"data/weapons/movement_types", "data/terrain"},
    constructor  = function() return { name = "weapon movement types"} end,
    initializer  = function(gear, instance, movement_types, terrain_data)
      instance.fn = function()
        for _, movement_type in pairs(movement_types) do
          for j, terrain_type in pairs(terrain_data.terrain_types) do
            local mt_id = movement_type.id
            local tt_id = terrain_type.id
            assert(terrain_type.move_cost[mt_id],
              "no '" .. mt_id .. "' movement type costs defined on terrain type '" .. tt_id .. "'")
          end
        end
        print("weapon movement types are valid")
      end
    end,
  })

  gear:declare("validators/units/classes", {
    dependencies = {"data/units/classes", "data/units/types::map"},
    constructor  = function() return { name = "unit classes"} end,
    initializer  = function(gear, instance, classes, type_for)
      instance.fn = function()
        for _, class in pairs(classes) do
          local t = class["type"]
          assert(type_for[t], "unknown unit type " .. t .. " for unit class " .. class.id)
        end
        print("unit classes are valid")
      end
    end,
  })

  gear:declare("validators/units/definitions", {
    dependencies = {"units", "weapons/types::map"},
    constructor  = function() return { name = "unit definitions"} end,
    initializer  = function(gear, instance, units, type_for)
      instance.fn = function()

        local land_unit_marching = function(unit)
          local has
          if (unit.definition.unit_type.id  == 'ut_land') then
            for _, wi in pairs(unit.staff) do
              if (not wi.weapon.movement_type.id ~= 'static') then
                has = true
                break
              end
            end
          end
          return has
        end

        local land_unit_attacking = function(unit)
          local has
          if (unit.definition.unit_type.id  == 'ut_land') then
            for _, wi in pairs(unit.staff) do
              if (not wi.weapon:is_capable("NON_ATTACKING") ) then
                has = true
                break
              end
            end
          end
          return has
        end

        -- k: state_name, value: functons, which determines, whether state should present,
        local state_definitions = {
          -- land units should have attacking state, if there is at least one weapon type
          -- without NON_ATTACKING flag
          attacking = land_unit_attacking,

          -- land units, if there is at least one weapon without ORIENTED_ONLY flag
          -- Example of orinented only weapon: barricade
          circular_defending = function(unit)
            local has
            if (unit.definition.unit_type.id  == 'ut_land') then
              for _, wi in pairs(unit.staff) do
                if (not wi.weapon:is_capable("ORIENTED_ONLY") ) then
                  has = true
                  break
                end
              end
            end
            return has
          end,

          -- land units, if there is at least one weapon without NON_ORIENTED_ONLY flag
          -- example of non orinented only weapon: landed mines
          defending = function(unit)
            local has
            if (unit.definition.unit_type.id  == 'ut_land') then
              for _, wi in pairs(unit.staff) do
                if (not wi.weapon:is_capable("NON_ORIENTED_ONLY") ) then
                  has = true
                  break
                end
              end
            end
            return has
          end,

          -- land units, if there is at least one movable unit
          retreating = land_unit_marching,

          -- land units, if there is at least one movable unit
          escaping = land_unit_marching,

          -- land units, if there is at least one weapon without NON_CAPTURABLE flag
          -- example of non capturable weapon: landed mines
          captured = function(unit)
            local has
            if (unit.definition.unit_type.id  == 'ut_land') then
              for _, wi in pairs(unit.staff) do
                if (not wi.weapon:is_capable("NON_CAPTURABLE") ) then
                  has = true
                  break
                end
              end
            end
            return has
          end,

          -- any unit (not land only) should have marching (moving) state
          marching = function(unit)
            local has
            for _, wi in pairs(unit.staff) do
              if (not wi.weapon.movement_type.id ~= 'static') then
                has = true
                break
              end
            end
            return has
          end,

          patroling = function(unit)
            return unit.definition.state_icons.patroling and land_unit_attacking(unit)
          end,

          raiding = function(unit)
            return unit.definition.state_icons.raiding and land_unit_attacking(unit)
          end,

          -- any moveable unit can be refuelled
          refuelling = function(unit)
            local has
            for _, wi in pairs(unit.staff) do
              if (not wi.weapon.movement_type.id ~= 'static') then
                has = true
                break
              end
            end
            return has
          end,


          -- land units, with weapon with CAN_ASSULT capabilities
          assulting = function(unit)
            local has
            if (unit.definition.unit_type.id  == 'ut_land') then
              for _, wi in pairs(unit.staff) do
                if (wi.weapon:is_capable("CAN_ASSULT") ) then
                  has = true
                  break
                end
              end
            end
            return has
          end,

          -- land units, with weapon with BUILD_CAPABILITIES capabilities
          constructing = function(unit)
            local has
            if (unit.definition.unit_type.id  == 'ut_land') then
              for _, wi in pairs(unit.staff) do
                if (wi.weapon:is_capable("BUILD_CAPABILITIES") ) then
                  has = true
                  break
                end
              end
            end
            return has
          end,

          -- land units, with weapon with CAN_BRIDGE capabilities
          bridging = function(unit)
            local has
            if (unit.definition.unit_type.id  == 'ut_land') then
              for _, wi in pairs(unit.staff) do
                if (wi.weapon:is_capable("CAN_BRIDGE") ) then
                  has = true
                  break
                end
              end
            end
            return has
          end,

          -- land units, with weapon with CAN_FAKING capabilities
          faking = function(unit)
            local has
            if (unit.definition.unit_type.id  == 'ut_land') then
              for _, wi in pairs(unit.staff) do
                if (wi.weapon:is_capable("CAN_FAKING") ) then
                  has = true
                  break
                end
              end
            end
            return has
          end,

        }
        for _, unit in pairs(units) do
          for possible_state, detect_fn in pairs(state_definitions) do
            if (detect_fn(unit)) then
              -- print("unit " .. unit.id .. " should have state " .. possible_state)
              if (not unit.definition.state_icons[possible_state]) then
                local msg = string.format("unit definition %s should have state icon for state '%s', triggered by unit %s",
                  unit.definition.id, possible_state, unit.id)
                  error(msg)
              end
            end
          end
        end
        print("unit definitions are valid")
      end
    end,
  })

  gear:declare("validator", {
    dependencies = { "validators/weapons/movement_types", "validators/units/classes", "validators/terrain/flags",
      "validators/units/definitions",
    },
    constructor  = function() return { } end,
    initializer  = function(gear, instance, ...)
      local validators = { ... }
      instance.fn = function()
        _.each(validators, function(_, v) v.fn() end)
        print("all data seems to be valid")
      end
    end,
  })

end

return Validator
