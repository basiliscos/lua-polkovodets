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
local _ = require ("moses")

local BattleFormula = {}
BattleFormula.__index = BattleFormula

function BattleFormula.create(engine)
  local o = { engine = engine}
  return setmetatable(o, BattleFormula)
end

local HIT_PROBABILITY_MAX = 0.98
local HIT_PROBABILITY_MIN = 0.02

local tanh = function(x)
  if x == 0 then return 0.0 end
  local neg = false
  if x < 0 then x = -x; neg = true end
  if x < 0.54930614433405 then
    local y = x * x
    x = x + x * y *
        ((-0.96437492777225469787e0  * y +
          -0.99225929672236083313e2) * y +
          -0.16134119023996228053e4) /
        (((0.10000000000000000000e1  * y +
           0.11274474380534949335e3) * y +
           0.22337720718962312926e4) * y +
           0.48402357071988688686e4)
  else
    x = math.exp(x)
    x = 1.0 - 2.0 / (x * x + 1.0)
  end
  if neg then x = -x end
  return x
end

local probability_fn = function(v)
  local tan_h = tanh(4*v - 4)
  local p = 0.5 + tan_h * 0.5
  if (p > HIT_PROBABILITY_MAX) then return HIT_PROBABILITY_MAX end
  if (p < HIT_PROBABILITY_MIN) then return HIT_PROBABILITY_MIN end
  return p
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
    if ((wi_a.data.quantity > 0) or (pair.a.shots[wi_a.uniq_id])) then
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
    local ad = attack/defence
    -- print("ad = " .. ad)
    local targets = math.modf(ad)
    local p = probability_fn(ad)
    print(wi_a.uniq_id .. " hits " .. targets .. " target(s) with probability " .. p)
    local casualities_p = p_side.casualities[wi_p.uniq_id]
    -- active shoots to passive
    while ((wi_p.data.quantity > 0) and (a_side.shots[wi_a.uniq_id] > 0)) do
      a_side.shots[wi_a.uniq_id] = a_side.shots[wi_a.uniq_id] - 1
      local r = math.random()
      if (r <= p) then
        casualities_p = casualities_p + 1
        wi_p.data.quantity = wi_p.data.quantity - 1
      end
    end
    p_side.casualities[wi_p.uniq_id] = casualities_p
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
