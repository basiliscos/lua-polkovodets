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

local Probability = {}
Probability.__index = Probability

local _ = require ("moses")

function Probability.fn(list, accessor)
    -- 1st pass: select total for normalisation
    local total = _.reduce(list, function(state, item) return state + accessor(item) end, 0)
    -- 2nd pass: calculate probabilities, based on quantities
    local vector = _.map(list, function(idx, item)
        return {
            prob  = accessor(item) / total,
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

return Probability
