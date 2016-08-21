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

   local theme_dir = data_dirs.themes .. '/' .. theme_data.name

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
   self.history  = {
        move           = renderer:load_texture(theme_dir .. '/arrow-movement.png'),
        battle         = renderer:load_texture(theme_dir .. '/battle-icon.png'),
        battle_hilight = renderer:load_texture(theme_dir .. '/battle-icon-hilighted.png'),

   }
   self.cursor = renderer:load_texture(theme_dir .. '/cursor.png')
   self.radial_menu = {
    inner_buttons = {
      up   = {
        available = renderer:load_texture(theme_dir .. '/radial-menu/hex-available.png'),
        hilight   = renderer:load_texture(theme_dir .. '/radial-menu/hex-hilight.png'),
        active    = renderer:load_texture(theme_dir .. '/radial-menu/hex-active.png'),
      },
      down = {
        available = renderer:load_texture(theme_dir .. '/radial-menu/general-available.png'),
        hilight   = renderer:load_texture(theme_dir .. '/radial-menu/general-hilight.png'),
        active    = renderer:load_texture(theme_dir .. '/radial-menu/general-active.png'),
      },
    },
    background = renderer:load_texture(theme_dir .. '/radial-menu/background.png'),
    sectors = {
      renderer:load_texture(theme_dir .. '/radial-menu/01.png'),
      renderer:load_texture(theme_dir .. '/radial-menu/02.png'),
      renderer:load_texture(theme_dir .. '/radial-menu/03.png'),
      renderer:load_texture(theme_dir .. '/radial-menu/04.png'),
      renderer:load_texture(theme_dir .. '/radial-menu/05.png'),
      renderer:load_texture(theme_dir .. '/radial-menu/06.png'),
      renderer:load_texture(theme_dir .. '/radial-menu/07.png'),
      renderer:load_texture(theme_dir .. '/radial-menu/08.png'),
      renderer:load_texture(theme_dir .. '/radial-menu/09.png'),
      renderer:load_texture(theme_dir .. '/radial-menu/10.png'),
      renderer:load_texture(theme_dir .. '/radial-menu/11.png'),
      renderer:load_texture(theme_dir .. '/radial-menu/12.png'),
    },
   }
   self.actions = {
      end_turn = {
        available = renderer:load_texture(theme_dir .. '/actions/end-turn.png'),
        hilight   = renderer:load_texture(theme_dir .. '/actions/end-turn-hilight.png'),
      },
      strategical_map = {
        available = renderer:load_texture(theme_dir .. '/actions/strategical-map.png'),
        hilight   = renderer:load_texture(theme_dir .. '/actions/strategical-map-hilight.png'),
      },
      switch_layer = {
        air  = renderer:load_texture(theme_dir .. '/actions/layer-air.png'),
        land = renderer:load_texture(theme_dir .. '/actions/layer-land.png'),
      },
      toggle_history = {
        on  = renderer:load_texture(theme_dir .. '/actions/history-on.png'),
        off = renderer:load_texture(theme_dir .. '/actions/history-off.png'),
      },
      toggle_landscape = {
        on  = renderer:load_texture(theme_dir .. '/actions/landscape-on.png'),
        off = renderer:load_texture(theme_dir .. '/actions/landscape-off.png'),
      },
      select_unit = {
        available = renderer:load_texture(theme_dir .. '/actions/select-unit.png'),
        hilight   = renderer:load_texture(theme_dir .. '/actions/select-unit-hilight.png'),
      },
      information = {
        available = renderer:load_texture(theme_dir .. '/actions/information.png'),
        hilight   = renderer:load_texture(theme_dir .. '/actions/information-hilight.png'),
      },
      move = {
        available = renderer:load_texture(theme_dir .. '/actions/move.png'),
        hilight   = renderer:load_texture(theme_dir .. '/actions/move-hilight.png'),
      },
      merge = {
        available = renderer:load_texture(theme_dir .. '/actions/merge.png'),
        hilight   = renderer:load_texture(theme_dir .. '/actions/merge-hilight.png'),
      },
      detach = {
        available = renderer:load_texture(theme_dir .. '/actions/detach.png'),
        hilight   = renderer:load_texture(theme_dir .. '/actions/detach-hilight.png'),
      },
      change_orientation = {
        available = renderer:load_texture(theme_dir .. '/actions/change-orientation.png'),
        hilight   = renderer:load_texture(theme_dir .. '/actions/change-orientation-hilight.png'),
      },
      construction = {
        available = renderer:load_texture(theme_dir .. '/actions/construction.png'),
        hilight   = renderer:load_texture(theme_dir .. '/actions/construction-hilight.png'),
      },
      defence = {
        available = renderer:load_texture(theme_dir .. '/actions/defending.png'),
        hilight   = renderer:load_texture(theme_dir .. '/actions/defending-hilight.png'),
      },
      retreat = {
        available = renderer:load_texture(theme_dir .. '/actions/retreating.png'),
        hilight   = renderer:load_texture(theme_dir .. '/actions/retreating-hilight.png'),
      },
      refuel = {
        available = renderer:load_texture(theme_dir .. '/actions/refuelling.png'),
        hilight   = renderer:load_texture(theme_dir .. '/actions/refuelling-hilight.png'),
      },
      raid = {
        available = renderer:load_texture(theme_dir .. '/actions/raid.png'),
        hilight   = renderer:load_texture(theme_dir .. '/actions/raid-hilight.png'),
      },
      patrol = {
        available = renderer:load_texture(theme_dir .. '/actions/patroling.png'),
        hilight   = renderer:load_texture(theme_dir .. '/actions/patroling-hilight.png'),
      },
      circular_defence = {
        available = renderer:load_texture(theme_dir .. '/actions/circular-defending.png'),
        hilight   = renderer:load_texture(theme_dir .. '/actions/circular-defending-hilight.png'),
      },
      battle = {
        available = renderer:load_texture(theme_dir .. '/actions/attack.png'),
        hilight   = renderer:load_texture(theme_dir .. '/actions/attack-hilight.png'),
      },
      bridge = {
        available = renderer:load_texture(theme_dir .. '/actions/bridge.png'),
        hilight   = renderer:load_texture(theme_dir .. '/actions/bridge-hilight.png'),
      },
      battle_history = {
        available = renderer:load_texture(theme_dir .. '/actions/battle-history.png'),
        hilight   = renderer:load_texture(theme_dir .. '/actions/battle-history-hilight.png'),
      },
   }
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

return Theme
