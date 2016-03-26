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

local Theme = {}
Theme.__index = Theme

function Theme.create()
  return setmetatable({}, Theme)
end


function Theme:initialize(theme_data, renderer, data_dirs)
   assert(theme_data.name)
   assert(theme_data.active_hex)
   assert(theme_data.cursors.path)
   assert(theme_data.cursors.size)

   local cursors_file = theme_data.cursors.path
   local theme_dir = data_dirs.themes .. '/' .. theme_data.name
   local cursors_path =  theme_dir .. '/' .. cursors_file
   local cursor_size = theme_data.cursors.size

   local iterator_factory = function(surface) return renderer:create_simple_iterator(surface, cursor_size, 0) end
   renderer:load_joint_texture(cursors_path, iterator_factory)

   local active_hex_font = theme_dir .. '/' .. theme_data.active_hex.font
   local active_hex_size = assert(theme_data.active_hex.font_size)
   local active_hex_ttf = renderer:ttf(active_hex_font, active_hex_size)

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

   self.engine   = engine
   self.renderer = renderer
   self.data     = theme_data
   self.cursors  = cursors_path
   self.history  = {
        move           = renderer:load_texture(theme_dir .. '/arrow-movement.png'),
        battle         = renderer:load_texture(theme_dir .. '/battle-icon.png'),
        battle_hilight = renderer:load_texture(theme_dir .. '/battle-icon-hilighted.png'),
   }
   self.unit_flag_hilight =  renderer:load_texture(theme_dir .. '/unit-flag-hilight.png')
   self.change_attack_type = {
        available = renderer:load_texture(theme_dir .. '/change-attack-type.png'),
        hilight   = renderer:load_texture(theme_dir .. '/change-attack-type-hilighted.png'),
      }
   self.panel    = {
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
      }

   self.buttons = {
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
      }
  self.tabs = {
        info = {
          available = renderer:load_texture(theme_dir .. '/tabs/info.png'),
          hilight   = renderer:load_texture(theme_dir .. '/tabs/info-hilight.png'),
          active    = renderer:load_texture(theme_dir .. '/tabs/info-active.png'),
        },
        problems = {
          available = renderer:load_texture(theme_dir .. '/tabs/problems.png'),
          hilight   = renderer:load_texture(theme_dir .. '/tabs/problems-hilight.png'),
          active    = renderer:load_texture(theme_dir .. '/tabs/problems-active.png'),
        },
        attachments = {
          available = renderer:load_texture(theme_dir .. '/tabs/attachments.png'),
          hilight   = renderer:load_texture(theme_dir .. '/tabs/attachments-hilight.png'),
          active    = renderer:load_texture(theme_dir .. '/tabs/attachments-active.png'),
        },
        management = {
          available = renderer:load_texture(theme_dir .. '/tabs/management.png'),
          hilight   = renderer:load_texture(theme_dir .. '/tabs/management-hilight.png'),
          active    = renderer:load_texture(theme_dir .. '/tabs/management-active.png'),
        },
      }
   self.window = {
        background = renderer:load_texture(theme_dir .. '/window/background.png'),
      }
   self.font = {
        default = active_hex_font,
    }
   self.fonts    = {
         active_hex = active_hex_ttf,
    }
   self.font_cache = {}
   self.unit_states = unit_states
end

function Theme:get_font(name, size)
  local cache_key = name .. size
  local font = self.font_cache[cache_key]
  if (font) then return font end

  local path = self.font[name]
  font = self.renderer:ttf(path, size)
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
