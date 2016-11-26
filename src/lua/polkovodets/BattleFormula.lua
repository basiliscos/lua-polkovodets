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

local _DEBUG_FORMULA = true

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
  local p = 0.3 * (v^2.2)
  if (p > HIT_PROBABILITY_MAX) then return HIT_PROBABILITY_MAX end
  if (p < HIT_PROBABILITY_MIN) then return HIT_PROBABILITY_MIN end
  return p
end

function BattleFormula:_perform_shot(a_item, p_item)
    local wi_a, wi_p = a_item.weapon_instance, p_item.weapon_instance
    local p_target_type = wi_p.weapon.target_type
    local a_taret_type = wi_a.weapon.target_type
    local attack = wi_a.weapon.attacks[p_target_type.id]
    local unit_a = self.engine:get_unit(wi_a.unit_id)
    local unit_p = self.engine:get_unit(wi_p.unit_id)
    local attacks_from_layer = unit_a:get_layer()
    local defence = wi_p.weapon.defends[attacks_from_layer]
    local attack = wi_a.weapon.attacks[p_target_type.id]

    if (attack == 0) then return 0 end
    assert(defence > 0, "defence is zero for weapon instance " .. wi_p.id)
    local ad = attack/defence
    local ad_coef = (1 + unit_a.data.experience) / (1 + unit_p.data.experience)
    local attempts = math.modf(ad)
    -- at least one attempt
    if (attempts == 0) then attempts = 1 end
    local total_attempts = attempts
    local p = _probability(ad_coef * ad)

    local hit_points = wi_p.data.quantity - p_item.casualities

    while ((attempts > 0) and (hit_points > 0)) do
        local dice = math.random()
        -- print(string.format("p: %f, dice: %f", p, dice))
        if (dice <= p) then
            hit_points = hit_points - 1
        end
        attempts = attempts - 1
    end

    local casualities = (wi_p.data.quantity - p_item.casualities) - hit_points

    if (_DEBUG_FORMULA) then
        print(string.format("a/d = %f, ad_coef = %f p = %f, attempts = %d, casualities = %d, Details %s (attack: %d) shots at %s (defence: %d), target = %s",
                            ad, ad_coef, p, total_attempts, casualities, wi_a.id, attack, wi_p.id, defence, p_target_type.id))
    end

    return casualities
end

--- randomy selects share weapons from list
function _prepare_participants(item)
    local list = item.weapons
    local multiplier = item.multiplier
    assert((multiplier > 0) and (multiplier <= 1), "multiplier " .. multiplier ..  " should be in range (0; 1]")
    local cloned_list = _.clone(list, true)

    local participants = {}
    for idx, wi in pairs(list) do
        local quantity, remainder = math.modf(wi.data.quantity * multiplier)
        if (remainder >= 0.5) then quantity = quantity + 1 end
        local shots = item.shots[wi.id]
        table.insert(participants, {
            weapon_instance = wi,
            quantity        = quantity,
            shots           = shots,
            casualities     = 0,
        })
        if (_DEBUG_FORMULA) then
            print(string.format("prepared weapon %s, quantity = %d, shots = %d", wi.id, quantity, shots))
        end
    end
    return participants
end

function _probability_fn(list)
    -- 1st pass: select total for normalisation
    local total = _.reduce(list, function(state, item) return state + (item.quantity - item.casualities) end, 0)
    -- 2nd pass: calculate probabilities, based on quantities
    local vector = _.map(list, function(idx, item)
        return {
            prob  = (item.quantity - item.casualities) / total,
            index = idx
        }
    end)
    -- 3rd pass: unstable sort by probabilities
    table.sort(vector, function(a, b)
        return a.prob < b.prob
    end)
    -- 4th pass: build increasing probability function
    for idx = 2, #vector do
        vector[idx].prob = vector[idx].prob + vector[idx - 1].prob
    end
    return vector
end

function _somebody_can_shoot(list)
    for _, item in pairs(list) do
        if ( ((item.quantity - item.casualities) > 0)
            and (item.shots > 0 )) then
                return true
        end
    end
end

function _somebody_is_alive(list)
    for _, item in pairs(list) do
        if ( (item.quantity - item.casualities) > 0 ) then
            return true
        end
    end
end

function _select_shooting_pair(active, passive)
    local a_prob = _probability_fn(active)
    local p_prob = _probability_fn(passive)

    local prob_stringizer = function(vector, list)
        return table.concat(
            _.map(vector, function(_, item)
                local wi = list[item.index].weapon_instance
                return wi.id .. " -> " .. item.prob
            end),
            "\n"
        )
    end

    if (_DEBUG_FORMULA) then
        local a_prob_str = prob_stringizer(a_prob, active)
        local p_prob_str = prob_stringizer(p_prob, passive)
        print(string.format("active weapons selector: probabilities:\n%s", a_prob_str))
        print(string.format("passive weapons selector: probabilities:\n%s",p_prob_str))
    end

    local random_pick = function(vector)
        local dice = math.random()
        local idx = 1
        while(vector[idx].prob <= dice) do
            idx = idx + 1
        end
        return vector[idx].index
    end

    local a_idx = random_pick(a_prob)
    local p_idx = random_pick(p_prob)

    return a_idx, p_idx
end

function commit_results(from, to)
    for _, item in pairs(from) do
        local wi = item.weapon_instance
        wi.data.quantity = wi.data.quantity - item.casualities
        to.casualities[wi.id] = to.casualities[wi.id] + item.casualities
        to.shots[wi.id] = item.shots
    end
end

function BattleFormula:perform_battle(pair)
    print("performing " .. pair.action)

    local active  = _prepare_participants(pair.a)
    local passive = _prepare_participants(pair.p)

    while(_somebody_can_shoot(active) and _somebody_is_alive(passive)) do
        local a_idx, p_idx = _select_shooting_pair(active, passive)
        -- print(string.format("a_idx = %s, p_idx = %s", a_idx, p_idx))
        local a_item, p_item = active[a_idx], passive[p_idx]
        local a_shots, a_casualities, p_shots = 1, 0, 0
        local p_casualities = self:_perform_shot(a_item, p_item)

        -- retalitaion. Computed before casualities applied
        if ((pair.action == 'battle') and (passive[p_idx].shots > 0)) then
            a_casualities = self:_perform_shot(a_item, p_item)
            p_shots = 1
        end

        -- commit the shot results
        a_item.casualities = a_item.casualities + a_casualities
        p_item.casualities = p_item.casualities + p_casualities
        a_item.shots = math.max(0, a_item.shots - math.max(a_casualities, 1))
        p_item.shots = math.max(0, p_item.shots - math.max(p_casualities, 0))
    end

    -- commit summaries
    commit_results(active, pair.a)
    commit_results(passive, pair.p)

    if (_DEBUG_FORMULA) then
        local dump = function(list)
            local strings = _.map(list, function(idx, item)
                return item.weapon_instance.id .. " => " .. item.casualities
            end)
            return table.concat(strings, "\n")
        end
        print("block casualities results a:\n" .. dump(active) .. "\n, for p:\n " .. dump(passive))
        print("casualities results a:" .. inspect(pair.a.casualities) .. ", p:" .. inspect(pair.p.casualities))
        print("remaining shots a:" .. inspect(pair.a.shots)  .. ", p:" .. inspect(pair.p.shots))
    end
end

return BattleFormula
