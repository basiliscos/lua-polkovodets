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

local WeaponClass = {}
WeaponClass.__index = WeaponClass

function WeaponClass.create()
  return setmetatable({}, WeaponClass)
end

function WeaponClass:initialize(renderer, weapon_class_data, dirs_data)
  self.id    = assert(weapon_class_data.id, "weapon class should have id")
  self.flags = assert(weapon_class_data.flags)

  local icon_path = assert(weapon_class_data.icon)

  local icon_path = dirs_data.gfx .. '/' .. icon_path
  local icon_for_style = {}
  for idx, style in pairs({"active", "available", "hilight"}) do
    local full_path = icon_path .. "-" .. style .. ".png"
    icon_for_style[style] = renderer:load_texture(full_path)
  end
  self.icons = icon_for_style
end

function WeaponClass:get_icon(style)
  assert(style)
  local icon = assert(self.icons[style], "icon of style " .. style .. " n/a for weapon class " .. self.id)
  return icon
end

return WeaponClass
