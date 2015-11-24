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

local Nation = {}
Nation.__index = Nation

local Parser = require 'polkovodets.Parser'

function Nation.create(engine, nation_data)
   assert(nation_data.id)
   assert(nation_data.name)
   assert(nation_data.icon_path)

   local load_flag = function(short_path)
      local image_path = engine:get_gfx_dir() .. '/' .. short_path
      return engine.renderer:load_texture(image_path)
   end

   local o = {
	  engine    = engine,
	  data      = nation_data,
      flag      = load_flag(nation_data.icon_path),
      unit_flag = load_flag(nation_data.unit_icon_path),
   }

   setmetatable(o, Nation)
   return o
end

function Nation:draw_flag(sdl_renderer, x, y, objective)
   local engine = self.engine

   local dst = {x = x, y = y, w = self.flag.w, h = self.flag.h}
   assert(sdl_renderer:copy(self.flag.texture, nil, dst))
end

return Nation
