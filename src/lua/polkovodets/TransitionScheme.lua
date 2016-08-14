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

local TransitionScheme = {}
TransitionScheme.__index = TransitionScheme

local _ = require ("moses")
local inspect = require('inspect')

function TransitionScheme.create()
  local o = {
    action_rules = {},
  }
  return setmetatable(o, TransitionScheme)
end

function TransitionScheme:initialize(transition_rules)
  for _, rule in pairs (transition_rules) do
    table.insert(self.action_rules, {
      action = rule.action,
      from   = rule.from,
      cost   = rule.cost,
    })
  end
end

function TransitionScheme:_is_allowed(action, list, unit)
  assert(unit)
  local from = unit.data.state
  for _, rule in pairs(list) do
    if ((action == rule.action) and ((rule.from == '*') or rule.from == from)) then
      local cost = rule.cost
      local result
      if (cost == 0) then
        result = true
      else
        local united_staff = unit:_united_staff()
        local min_movement = united_staff[1].data.movement
        for _, wi in pairs(united_staff) do
          min_movement = math.min(wi.data.movement, min_movement)
        end
        -- print("cost = " .. cost)
        if (cost == 'A') then
          result = (min_movement > 1)
        else
          result = (cost <= min_movement)
        end
        -- print(string.format("%s costs: %s, min_movement: %d, result: %s", action, cost, min_movement, result))
      end
      return (result and cost)
    end
  end
end

function TransitionScheme:is_action_allowed(action, unit)
  return self:_is_allowed(action, self.action_rules, unit)
end

return TransitionScheme
