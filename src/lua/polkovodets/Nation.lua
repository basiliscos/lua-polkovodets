--[[

Copyright (C) 2015, 2016 Ivan Baidakou

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

local Nation = {}
Nation.__index = Nation

function Nation.create(engine, nation_data)
  return setmetatable({ drawing = { } }, Nation)
end

function Nation:initialize(renderer, nation_data, data_dirs)
  assert(nation_data.id)
  assert(nation_data.name)
  assert(nation_data.icon_path)

  local load_flag = function(short_path)
    local image_path = data_dirs.gfx .. '/' .. short_path
    return renderer:load_texture(image_path)
  end

  self.id        = nation_data.id
  self.name      = nation_data.name
  self.flag      = load_flag(nation_data.icon_path)
  self.unit_flag = load_flag(nation_data.unit_icon_path)
end


return Nation
