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

local ttf = require "SDL.ttf"

local Theme = {}
Theme.__index = Theme

function Theme.create(engine, data)
   assert(data.name)
   assert(data.active_hex)
   assert(data.cursors.path)
   assert(data.cursors.size)

   local cursors_file = data.cursors.path
   local theme_dir = engine:get_themes_dir() .. '/' .. data.name
   local cursors_path =  theme_dir .. '/' .. cursors_file
   local renderer = engine.renderer
   local cursor_size = data.cursors.size

   local iterator_factory = function(surface) return renderer:create_simple_iterator(surface, cursor_size, 0) end
   renderer:load_joint_texture(cursors_path, iterator_factory)

   local active_hex_font = theme_dir .. '/' .. data.active_hex.font
   local active_hex_size = assert(data.active_hex.font_size)
   local active_hex_ttf = assert(ttf.open(active_hex_font, active_hex_size))

   local unit_states = {}

   for idx, size in pairs({'L', 'M', 'S'}) do
      for idx2, efficiency in pairs({'high', 'avg', 'low'}) do
         local icon_name = size .. '-' .. efficiency .. '.png'
         local icon_path = theme_dir .. '/unit-state-icons/' .. icon_name
         local image = renderer:load_texture(icon_path)
         local key = size .. '-' .. efficiency
         unit_states[key] = image
      end
   end

   local o = {
      engine   = engine,
      renderer = renderer,
      data     = data,
      cursors  = cursors_path,
      history  = {
        move           = renderer:load_texture(theme_dir .. '/arrow-movement.png'),
        battle         = renderer:load_texture(theme_dir .. '/battle-icon.png'),
        battle_hilight = renderer:load_texture(theme_dir .. '/battle-icon-hilighted.png'),
      },
      fonts    = {
         active_hex = active_hex_ttf,
      },
      unit_states = unit_states,
   }
   setmetatable(o,Theme)
   return o
end

function Theme:get_unit_state_icon(size, efficiency)
   local key = size .. '-' .. efficiency
   local icon = assert(self.unit_states[key], 'unit state ' .. key .. ' is n/a')
   return icon
end

function Theme:get_cursor(kind)
   local idx = assert(self.data.cursors.actions[kind], "cursor " .. kind .. " not found")
   return self.renderer:get_joint_texture(self.cursors, idx)
end

return Theme
