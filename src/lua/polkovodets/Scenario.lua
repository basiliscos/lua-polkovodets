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

local Scenario = {}
Scenario.__index = Scenario

local inspect = require('inspect')
local Map = require 'polkovodets.Map'
local Nation = require 'polkovodets.Nation'
local Player = require 'polkovodets.Player'
local Unit = require 'polkovodets.Unit'
local WeaponInstance = require 'polkovodets.WeaponInstance'
local Parser = require 'polkovodets.Parser'

function Scenario.create()
  return setmetatable({}, Scenario)
end

function Scenario:initialize(scenario_data, objectives_data, armies_data,
  engine, renderer, map, nations_for, weapon_definitions_for, unit_definitions_for, nation_to_player)
  self.name        = assert(scenario_data.name)
  self.description = assert(scenario_data.description)
  self.authors     = assert(scenario_data.authors)
  self.start_date  = assert(scenario_data.date)

  -- validate weathers
  for idx, weather_id in pairs(scenario_data.weather) do
    assert(map.terrain.weather[weather_id], "wrong weather " .. weather_id)
  end
  self.weather = assert(scenario_data.weather)

  -- set objectives
  self.objectives = objectives

  --[[ create/instantiate army ]]

   -- 1st pass: create units & weapon instances
  local unit_for = {}
  local units = {}
  local weapon_instance_for = {}
  for _, data in pairs(armies_data) do
    local id = assert(data.id)
    assert(data.staff)
    local staff = {}
    local order = 1

    -- create weapon instances
    for weapon_id, quantity in pairs(data.staff) do
      local wi_data = {
        definition_id = weapon_id,
        unit_id       = id,
        quantity      = tonumber(quantity),
        order         = order,
      }
      local wi = WeaponInstance.create()
      wi:initialize(wi_data, weapon_definitions_for)
      staff[weapon_id] = wi
      weapon_instance_for[wi.id] = wi
      order = order + 1
    end

    local unit = Unit.create()
    unit:initialize(engine, renderer, map, data, staff, unit_definitions_for, nation_to_player)
    unit_for[unit.id] = unit
    table.insert(units, unit)
  end

  -- 2nd pass: bind hq
  for idx, data in pairs(armies_data) do
    local id = data.id
    local managed_by = data.managed_by
    if (managed_by) then
      local manager_unit = assert(unit_for[managed_by], "no manager " .. managed_by .. ", defined for unit " .. id)
      local unit = unit_for[id]
      manager_unit:subordinate(unit)
    end
  end

  self.units = units

  return units, unit_for, weapon_instance_for
end

return Scenario
