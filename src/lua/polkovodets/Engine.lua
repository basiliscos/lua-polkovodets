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


local Engine = {}
Engine.__index = Engine

local inspect = require('inspect')
-- plural rules: http://unicode.org/repos/cldr-tmp/trunk/diff/supplemental/language_plural_rules.html
local i18n = require 'i18n'
local Tile = require 'polkovodets.Tile'
local History = require 'polkovodets.History'
local Reactor = require 'polkovodets.utils.Reactor'
local State = require 'polkovodets.State'


function Engine.create(language)

  local lang = language or 'ru'
  local messages = require('polkovodets.i18n.' .. lang)
  i18n.load(messages)
  i18n.setLocale(lang)

  local reactor = Reactor.create({
    'mouse-hint.change', 'map.active_tile.change',
    'action.change', 'mouse-position.change',
    'map.update', 'history.update', 'ui.update',
    'full.refresh'
  })

  local e = {
    turn               = 0,
    messages           = messages,
    language           = lang,
    current_player_idx = nil,
    history_layer      = false,
    total_players      = 0,
    active_layer       = 'surface',
    reactor            = reactor,
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
    },
    state          = State.create(reactor)
    --[[
    state          = {
      landscape_only = false,
    },
    ]]
  }
  setmetatable(e,Engine)
  e.history = History.create(e)

  e.reactor:subscribe("history.update", function(event, records)
    if (#records > 0) then
      e.reactor:publish("map.update")
    end
  end)
  return e
end

function Engine:translate(key, values)
  assert(key)
  local value = i18n.translate(key, values)
  return value or ('?' .. key .. '?')
end

function Engine:set_map(map)
  assert(self.renderer)
  assert(map)
  self.map = map
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
  self.reactor:publish("map.update")
end


function Engine:get_map() return self.map end


function Engine:get_scenarios_dir() return 'data/db/scenarios' end
function Engine:get_definitions_dir() return 'data/db' end
function Engine:get_gfx_dir() return 'data/gfx' end
function Engine:get_themes_dir() return 'data/gfx/themes/' end

function Engine:set_renderer(renderer)
   self.renderer = renderer
end

function Engine:set_scenario(scenario)
  self.turn = 1
  self.scenario = scenario
  self:update_shown_map()
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
   local player_for = {}
   local total_players = 0
   for i, p in pairs(players) do
      player_for[p.id] = p
      total_players = total_players + 1
   end
   self.player_for = player_for
   self.total_players = total_players
   self:_set_current_player(1)
end

function Engine:set_units(units)
  self.all_units = units
  local unit_for = {}
  for idx, unit in pairs(units) do
    unit_for[unit.id] = unit
  end
  self.unit_for = unit_for
end

function Engine:get_unit(id)
  local u = self.unit_for[id]
  assert(u, "unit with id " .. id .. " not found")
  return u
end

function Engine:set_weapon_instances(hash)
  self.weapon_instance_for = hash
end

function Engine:_set_current_player(order)
   local player
   for i, p in pairs(self.player_for) do
      if (p.data.order == order) then
         player = p
      end
   end
   assert(player)
   self.current_player = player
   self.current_player_idx = order
   print(string.format("current player: %s(%d)",  player.id, player.data.order))
end

function Engine:get_current_player()
  return self.current_player
end


function Engine:current_turn() return self.turn end
function Engine:end_turn()
  self.state:set_selected_unit(nil)
  if (self.current_player_idx == self.total_players) then
    self.turn = self.turn + 1
    for k, unit in pairs(self.all_units) do
      unit:refresh()
    end
    print("current turm: " .. self.turn)
    self:_set_current_player(1)
  else
    self:_set_current_player(self.current_player_idx + 1)
  end
  self.history_layer = true
  self.reactor:publish("full.refresh");
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
   -- print("starting from " .. tile.id)
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
         -- print("found: " .. tile.id .. " ( " .. near_tile .. " ) ")
         found = false -- allow further iterations
         return tile
      end
   end
   return iterator, nil, true
end

function Engine:pointer_to_tile(x,y)
   local map = self.map
   local terrain = map.terrain
   local hex_h = terrain.hex_height
   local hex_w = terrain.hex_width
   local hex_x_offset = terrain.hex_x_offset
   local hex_y_offset = terrain.hex_y_offset

   local hex_x_delta = hex_w - hex_x_offset
   local tile_x_delta = self.gui.map_x

   local left_col = (math.modf((x - hex_x_delta) / hex_x_offset) + 1) + (tile_x_delta % 2)
   local right_col = left_col + 1
   local top_row = math.modf(y / hex_h) + 1
   local bot_row = top_row + 1
   -- print(string.format("mouse [%d:%d] ", x, y))
   -- print(string.format("[l:r] [t:b] = [%d:%d] [%d:%d] ", left_col, right_col, top_row, bot_row))
   local adj_tiles = {
      {left_col, top_row},
      {left_col, bot_row},
      {right_col, top_row},
      {right_col, bot_row},
   }
   -- print("adj-tiles = " .. inspect(adj_tiles))
   local tile_center_off = {(tile_x_delta % 2 == 0) and math.modf(hex_w/2) or math.modf(hex_w/2 - hex_x_offset), math.modf(hex_h/2)}
   local get_tile_center = function(tx, ty)
      local top_x = (tx - 1) * hex_x_offset
      local top_y = ((ty - 1) * hex_h) - ((tx % 2 == 1) and hex_y_offset or 0)
      return {top_x + tile_center_off[1], top_y + tile_center_off[2]}
   end
   local tile_centers = {}
   for idx, t_coord in pairs(adj_tiles) do
      local center = get_tile_center(t_coord[1], t_coord[2])
      table.insert(tile_centers, center)
   end
   -- print(inspect(tile_centers))
   local nearest_idx, nearest_distance = -1, math.maxinteger
   for idx, t_center in pairs(tile_centers) do
      local dx = x - t_center[1]
      local dy = y - t_center[2]
      local d = math.sqrt(dx*dx + dy*dy)
      if (d < nearest_distance) then
         nearest_idx = idx
         nearest_distance = d
      end
   end
   local active_tile = adj_tiles[nearest_idx]
   -- print("active_tile = " .. inspect(active_tile))
   local tx = active_tile[1] + ((tile_x_delta % 2 == 0) and 1 or 0 ) + tile_x_delta
   local ty = active_tile[2] + ((tx % 2 == 1) and 1 or 0) + self.gui.map_y

   if (tx > 0 and tx <= map.width and ty > 0 and ty <= map.height) then
      return {tx, ty}
      -- print(string.format("active tile = %d:%d", tx, ty))
   end
end


function Engine:toggle_landscape()
  local value = not self.state.landscape_only
  self.state.landscape_only = value
  self.state:set_selected_unit(nil)
  self.reactor:publish("map.update");
end

function Engine:toggle_layer()
  local current = self.active_layer
  current = (current == 'air') and 'surface' or 'air'
  print("active layer " .. current)
  self.active_layer = current
  self.reactor:publish("map.update");
end

function Engine:toggle_attack_priorities()
  local u = self.state:get_selected_unit()
  if (u) then
    u:switch_attack_priorities()
    self.reactor:publish("map.update");
  end
end

function Engine:toggle_history()
  self.history_layer = not self.history_layer
  self:_update_history_records()
end

function Engine:show_history()
  return self.history_layer
end


return Engine
