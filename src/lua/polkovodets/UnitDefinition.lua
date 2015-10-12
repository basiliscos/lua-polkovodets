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

local UnitDefinition = {}
UnitDefinition.__index = UnitDefinition

function UnitDefinition.create(engine, data)
   local unit_lib = engine.unit_lib

   assert(data.id)
   assert(data.name)
   assert(data.unit_class)
   assert(data.staff)
   local icon_path = assert(data.icon_path)
   local full_icon_path = engine:get_gfx_dir() .. '/' .. icon_path
   local o = {
      engine = engine,
      data = data,
      icon = engine.renderer:load_texture(full_icon_path),
   }
   setmetatable(o, UnitDefinition)
   return o
end

function UnitDefinition:get_icon()
   return self.icon
end

return UnitDefinition
