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

local WeaponClass = {}
WeaponClass.__index = WeaponClass

function WeaponClass.create(engine, data)
  local id = assert(data.id)
  local order = assert(data.order)
  local icon_path = assert(data.icon)

  local gfx_dir = engine:get_gfx_dir()
  local full_path = gfx_dir .. '/' .. icon_path
  -- print("loading weapon class icon " .. full_path)
  local icon = engine.renderer:load_texture(full_path)
  local o = {
    id    = id,
    order = order,
    icon  = icon,
  }
  return setmetatable(o, WeaponClass)
end

function WeaponClass:get_icon()
  return self.icon
end

return WeaponClass
