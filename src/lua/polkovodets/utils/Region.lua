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

local Region = {}
Region.__index = Region

function Region.create(x_min, y_min, x_max, y_max)
  local o = {
    x_min = x_min,
    y_min = y_min,
    x_max = x_max,
    y_max = y_max,
  }
  return setmetatable(o, Region)
end

function Region:is_over(mx, my)
  local over = ((mx >= self.x_min) and (mx <= self.x_max)
            and (my >= self.y_min) and (my <= self.y_max))
  return over
end

return Region
