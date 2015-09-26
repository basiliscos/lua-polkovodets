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

local UnitLib = {}
UnitLib.__index = UnitLib

local Parser = require 'polkovodets.Parser'


function UnitLib.create(engine)
   local o = {
      engine = engine,
      icons = {
      }
   }
   setmetatable(o, UnitLib)
   return o
end

function UnitLib:load(unit_file)
   local engine = self.engine
   local path = engine.get_units_dir() .. '/' .. unit_file
   print('loading units ' .. path)
   local parser = Parser.create(path)
   local icon_file = parser:get_value('icons')
   local icons_dir = engine:get_unit_icons_dir()
   local icon_path = icons_dir .. '/' .. icon_file
   self.icons.units = icon_path
   -- engine.renderer:load_joint_texture(icon_path, {})
end

return UnitLib
