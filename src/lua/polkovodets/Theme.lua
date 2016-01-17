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
      unit_flag_hilight =  renderer:load_texture(theme_dir .. '/unit-flag-hilight.png'),
      change_attack_type = {
        available = renderer:load_texture(theme_dir .. '/change-attack-type.png'),
        hilight   = renderer:load_texture(theme_dir .. '/change-attack-type-hilighted.png'),
      },
      panel    = {
        corner = {
          bl = renderer:load_texture(theme_dir .. '/panel/corner-bl.png'),
          br = renderer:load_texture(theme_dir .. '/panel/corner-br.png'),
          tl = renderer:load_texture(theme_dir .. '/panel/corner-tl.png'),
          tr = renderer:load_texture(theme_dir .. '/panel/corner-tr.png'),
        },
        mid    = {
          b = renderer:load_texture(theme_dir .. '/panel/mid-b.png'),
          t = renderer:load_texture(theme_dir .. '/panel/mid-t.png'),
          l = renderer:load_texture(theme_dir .. '/panel/mid-l.png'),
          r = renderer:load_texture(theme_dir .. '/panel/mid-r.png'),
        },
      },
      buttons = {
        end_turn = {
          normal   = renderer:load_texture(theme_dir .. '/buttons/end-turn.png'),
        },
        toggle_layer = {
          surface = renderer:load_texture(theme_dir .. '/buttons/layer-surface.png'),
          air     = renderer:load_texture(theme_dir .. '/buttons/layer-air.png'),
        },
        toggle_history = {
          active   = renderer:load_texture(theme_dir .. '/buttons/history-active.png'),
          inactive = renderer:load_texture(theme_dir .. '/buttons/history-inactive.png'),
        },
        toggle_landscape = {
          active   = renderer:load_texture(theme_dir .. '/buttons/landscape-active.png'),
          inactive = renderer:load_texture(theme_dir .. '/buttons/landscape-inactive.png'),
        },
        change_orientation = {
          available = renderer:load_texture(theme_dir .. '/buttons/change-orientation-available.png'),
          disabled  = renderer:load_texture(theme_dir .. '/buttons/change-orientation-disabled.png'),
        },
        information = {
          available = renderer:load_texture(theme_dir .. '/buttons/information-available.png'),
          disabled  = renderer:load_texture(theme_dir .. '/buttons/information-disabled.png'),
        },
        detach = {
          available = renderer:load_texture(theme_dir .. '/buttons/detach-available.png'),
          disabled  = renderer:load_texture(theme_dir .. '/buttons/detach-disabled.png'),
          multiple  = {
            renderer:load_texture(theme_dir .. '/buttons/detach-1.png'),
            renderer:load_texture(theme_dir .. '/buttons/detach-2.png'),
          },
        },
      },
      tabs = {
        info = {
          available = renderer:load_texture(theme_dir .. '/tabs/info.png'),
          hilight   = renderer:load_texture(theme_dir .. '/tabs/info-hilight.png'),
          active    = renderer:load_texture(theme_dir .. '/tabs/info-active.png'),
        },
        attachments = {
          available = renderer:load_texture(theme_dir .. '/tabs/attachments.png'),
          hilight   = renderer:load_texture(theme_dir .. '/tabs/attachments-hilight.png'),
          active    = renderer:load_texture(theme_dir .. '/tabs/attachments-active.png'),
        },
      },
      window = {
        background = renderer:load_texture(theme_dir .. '/window/background.png'),
      },
      font = {
        default = active_hex_font,
      },
      fonts    = {
         active_hex = active_hex_ttf,
      },
      font_cache = {},
      unit_states = unit_states,
   }
   setmetatable(o,Theme)
   return o
end

function Theme:get_font(name, size)
  local cache_key = name .. size
  local font = self.font_cache[cache_key]
  if (font) then return font end

  local path = self.font[name]
  font = assert(ttf.open(path, size))
  self.font_cache[cache_key] = font
  return font
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
