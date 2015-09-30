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

local Player = {}
Player.__index = Player

function Player.create(engine, data)
   assert(data.id)
   assert(data.name)
   assert(data.orientation)
   assert(data.nations)

   for k,nation_id in pairs(data.nations) do
      assert(engine.nation_for[nation_id], "no nation '" .. nation_id .. "' present in scenario")
   end
   
   local o = {
      id = data.id,
      engine = engine,
      data   = data,
      units = {},
   }
   setmetatable(o, Player)
   return o
end

return Player