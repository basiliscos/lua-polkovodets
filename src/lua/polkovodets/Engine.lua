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


local Engine = {}
Engine.__index = Engine


function Engine.create()
   local e = {
	  turn = 0,
      theme = {
         name = 'default',
         active_hex = {
            outline_color = 0x0,
            outline_width = 2,
            color = 0xFFFFFF,
            font_size = 15,
            font = 'DroidSansMono.ttf'
         },
      },
	  gui = {
		 map_x = 0,
		 map_y = 0,
		 -- number of tiles drawn to screen
		 map_sw = 0,
		 map_sh = 0,
		 -- position where to draw first tile
		 map_sx = 0,
		 map_sy = 0,

	  },
	  options = {
		 show_grid = true,
	  }
   }
   setmetatable(e,Engine)
   return e
end


function Engine:set_map(map)
   assert(self.renderer)
   assert(map)
   self.map = map

   self:update_shown_map()
end

function Engine:update_shown_map()
   local map = self.map
   local gui = self.gui
   gui.map_sx = -map.terrain.hex_x_offset
   gui.map_sy = -map.terrain.hex_height

   -- calculate drawn number of tiles
   local w, h = self.renderer:get_size()
   local step = 0
   local ptr = gui.map_sx
   while(ptr < w) do
	  step = step + 1
	  ptr = ptr + map.terrain.hex_x_offset
   end
   gui.map_sw = step

   step = 0
   ptr = gui.map_sy
   while(ptr < h) do
	  step = step + 1
	  ptr = ptr + map.terrain.hex_height
   end
   gui.map_sh = step
   print(string.format("visible hex frame: (%d, %d, %d, %d)", gui.map_x, gui.map_y, gui.map_x + gui.map_sw, gui.map_y + self.gui.map_sh))
end


function Engine:get_map() return self.map end


function Engine:get_scenarios_dir() return 'data/scenarios' end
function Engine:get_maps_dir() return 'data/maps' end
function Engine:get_units_dir() return 'data/units' end
function Engine:get_unit_icons_dir() return 'data/gfx/units' end
function Engine:get_terrains_dir() return 'data/maps' end
function Engine:get_terrain_icons_dir() return 'data/gfx/terrain' end
function Engine:get_nations_icons_dir() return 'data/gfx/flags' end
function Engine:get_nations_dir() return 'data/nations' end
function Engine:get_theme_dir() return 'data/themes/' .. self.theme.name end

function Engine:set_renderer(renderer)
   self.renderer = renderer
end

function Engine:set_scenario(scenario)
   self.turn = 1
   self.scenario = scenario
end
function Engine:get_scenario(scenario) return self.scenario end

function Engine:set_nations(nations)
   self.nations = nations
   -- nations hash
   local nation_for = {}
   for _,nation in pairs(nations) do
	  local key = nation.data.key
	  nation_for[key] = nation
   end
   self.nation_for = nation_for
end

function Engine:set_flags(flags) self.flags = flags end

function Engine:set_players(players)
   self.players = players
   local player_for = {}

   for i, p in pairs(players) do
      player_for[p.id] = p
   end
   self.player_for = player_for
end


function Engine:current_turn() return self.turn end

return Engine
