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

local Image = {}
Image.__index = Image

function Image.create(sdl_renderer, surface)
  local w, h = surface:getSize()
  local texture = assert(sdl_renderer:createTextureFromSurface(surface))
  local o = {
    surface = surface,
    texture = texture,
    w       = w,
    h       = h,
  }
  return setmetatable(o, Image)
end

return Image
