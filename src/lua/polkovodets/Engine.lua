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

local inspect = require('inspect')
local Tile = require 'polkovodets.Tile'


function Engine.create()
   local e = {
	  turn = 0,
      selected_unit = nil,
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


function Engine:get_scenarios_dir() return 'data/db/scenarios' end
function Engine:get_definitions_dir() return 'data/db' end
function Engine:get_gfx_dir() return 'data/gfx' end
function Engine:get_theme_dir() return 'data/gfx/themes/' .. self.theme.name end

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
	  local id = nation.data.id
	  nation_for[id] = nation
   end
   self.nation_for = nation_for
end

function Engine:set_objectives(objectives) self.objectives = objectives end

function Engine:set_players(players)
   self.players = players
   local player_for = {}

   for i, p in pairs(players) do
      player_for[p.id] = p
   end
   self.player_for = player_for
end


function Engine:current_turn() return self.turn end
function Engine:end_turn()
   self.turn = self.turn + 1
   print("current turm: " .. self.turn)
   for k, unit in pairs(self.all_units) do
      unit:_refresh_movements()
   end
   self:unselect_unit()
end

function Engine:current_weather()
   local turn = self.turn
   return self.scenario.weather[turn]
end

function Engine:get_adjastent_tiles(tile, skip_tiles)
   local map = self.map
   local visited_tiles = skip_tiles or {}
   local x, y = tile.data.x, tile.data.y
   local corrections = (x % 2) == 0
      and {
         {-1, 0},
         {0, -1},
         {1, 0},
         {1, 1},
         {0, 1},
         {-1, 1}, }
      or {
         {-1, -1},
         {0, -1},
         {1, -1},
         {1, 0},
         {0, 1},
         {-1, 0}, }

   local near_tile = 0
   -- print("starting from " .. tile.uniq_id)
   local iterator = function(state, value) -- ignored
      local found = false
      local nx, ny
      while (not found and near_tile < 6) do
         near_tile = near_tile + 1
         local dx, dy = table.unpack(corrections[near_tile])
         nx = x + dx
         ny = y + dy
         -- boundaries check
         found = (near_tile <= 6)
            and (nx > 1 and nx < map.width)
            and (ny > 1 and ny < map.height)
            and not visited_tiles[Tile.uniq_id(nx, ny)]
      end
      if (found) then
         local tile = map.tiles[nx][ny]
         -- print("found: " .. tile.uniq_id .. " ( " .. near_tile .. " ) ")
         found = false -- allow further iterations
         return tile
      end
   end
   return iterator, nil, true
end


function Engine:select_unit(u)
   u.data.selected = true
   self.selected_unit = u
   u:update_actions_map()
end


function Engine:unselect_unit()
   if (self.selected_unit) then
      self.selected_unit.data.selected = false
   end
   self.selected_unit = nil
end

function Engine:get_selected_unit()
   return self.selected_unit
end


function Engine:click_on_tile(x,y)
   local tile = self.map.tiles[x][y]
   if (tile.unit) then
      self:unselect_unit()
      self:select_unit(tile.unit)
   elseif (self.selected_unit) then
      local u = self.selected_unit
      local actions_map = u.data.actions_map
      local move_map = actions_map.move
      if (move_map[tile.uniq_id]) then
         u:move_to(tile)
      end
   end
end

return Engine
