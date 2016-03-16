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
local _ = require ("moses")

local BattleFormula = {}
BattleFormula.__index = BattleFormula

function BattleFormula.create(engine)
  local o = { }
  return setmetatable(o, BattleFormula)
end

function BattleFormula:initialize(engine)
  self.engine = engine
end


local HIT_PROBABILITY_MAX = 0.98
local HIT_PROBABILITY_MIN = 0.02

local _probability = function(v)
  local p = 0.1 * (v^2.2)
  if (p > HIT_PROBABILITY_MAX) then return HIT_PROBABILITY_MAX end
  if (p < HIT_PROBABILITY_MIN) then return HIT_PROBABILITY_MIN end
  return p
end

local _perform_shot = function(p, shots, targets_per_shot, targets)
  local initial_targets, initial_shots = targets, shots
  local end_value =  ((targets_per_shot < 1) and 1 or targets_per_shot)
  while((shots > 0) and (targets > 0)) do
    shots = shots - 1
    for h = 1,end_value do
      local r = math.random()
      if ((r <= p) and (targets > 0)) then targets = targets - 1 end
    end
  end
  return initial_targets - targets, shots
end


function BattleFormula:perform_battle(pair)
  print("performing " .. pair.action)

  local available_active = _.clone(pair.a.weapons, true)
  local available_passive = _.clone(pair.p.weapons, true)

  local select_weapons = function()
    local iterator = function(state, value) -- ignored
      if (#available_active > 0 and #available_passive > 0) then
        local a_idx = math.random(#available_active)
        local p_idx = math.random(#available_passive)
        return a_idx, p_idx
      end
    end
    return iterator, nil, true
  end

  local update_availabiliy = function(a_idx, p_idx)
    local wi_a = available_active[a_idx]
    local wi_p = available_passive[p_idx]
    if ((wi_a.data.quantity > 0) or (pair.a.shots[wi_a.id])) then
      table.remove(available_active, a_idx)
    end

    if (wi_p.data.quantity > 0) then
      table.remove(available_passive, p_idx)
    end
  end

  local perform_shot = function(wi_a, wi_p, a_side, p_side)
    -- get attack/defence ration
    local p_target_type = wi_p.weapon.target_type
    local a_taret_type = wi_a.weapon.target_type
    local attack = wi_a.weapon.attacks[p_target_type]
    local unit_a = self.engine:get_unit(wi_a.unit_id)
    local unit_p = self.engine:get_unit(wi_p.unit_id)
    local attacks_from_layer = unit_a:get_layer()
    local defence = wi_p.weapon.defends[attacks_from_layer]
    local attack = wi_a.weapon.attacks[p_target_type]

    -- do not simulat shoots
    if (attack == 0) then return end
    local ad = attack/defence
    print("ad = " .. ad .. " for " .. wi_a.id.. " vs " .. wi_p.id)
    print("a = " .. attack .. ", d = " .. defence)
    local targets = math.modf(ad)
    local p = _probability(ad)
    print(wi_a.id .. " hits " .. targets .. " target(s) with probability " .. p)

    -- active shoots to passive
    local casualities, remained_shots = _perform_shot(
      p,
      a_side.shots[wi_a.id],
      targets,
      wi_p.data.quantity
    )
    p_side.casualities[wi_p.id] = (p_side.casualities[wi_p.id] or 0) + casualities
    wi_p.data.quantity = wi_p.data.quantity - casualities
    a_side.shots[wi_a.id] = remained_shots
  end

  for a_idx, p_idx in select_weapons() do
    local wi_a = available_active[a_idx]
    local wi_p = available_passive[p_idx]
    perform_shot(wi_a, wi_p, pair.a, pair.p)

    -- in case of battle passive side shoots into active too
    if (pair.action == 'battle') then
      perform_shot(wi_p, wi_a, pair.p, pair.a)
    end

    update_availabiliy(a_idx, p_idx)
  end
  print("casualities results a:" .. inspect(pair.a.casualities)
        .. ", p:" .. inspect(pair.p.casualities))
  print("remaining shots a:" .. inspect(pair.a.shots)
        .. ", p:" .. inspect(pair.p.shots))
  print(inspect(pair.a.weapons[1].data))
end

return BattleFormula
