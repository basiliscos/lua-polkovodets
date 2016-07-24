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

local Map = {}
Map.__index = Map

local _ = require ("moses")
local Tile = require 'polkovodets.Tile'
local inspect = require('inspect')


function Map.create()
   local m = {
    engine = nil,
    united_spotting = {
      map = {},          -- k: tile_id, v: max spot (number)
      addons = {},       -- k: tile_id, v: map of unit_ids, which participate in tile spotting
      participants = {}, -- k: unit_id, v: spotting map
    },
  }
  setmetatable(m, Map)
  return m
end

function Map:initialize(engine, renderer, terrain, map_data, hex_names)
  self.engine   = engine
  self.renderer = renderer
  self.terrain = terrain
  assert(map_data.width)
  assert(map_data.height)
  self.width  = tonumber(map_data.width)
  self.height = tonumber(map_data.height)
  self:_fill_tiles(terrain, map_data, hex_names)

  local reactor = self.engine.reactor

  reactor:subscribe("turn.end", function() self:_reset_spotting_map() end)
  reactor:subscribe("turn.start", function() self:_on_start_of_turn() end)
  reactor:subscribe("unit.change-spotting", function(event, unit) self:_update_spotting_map(unit) end)

end

function Map:_update_spotting_map(unit)

  local united_spotting = self.united_spotting

  local updated_tiles = {}
  -- step 1: remove prevous unit spot influence (if any)
  if (united_spotting.participants[unit.id]) then
    for tile_id, spot_value  in pairs(united_spotting.participants[unit.id]) do
      local spot_components = united_spotting.addons[tile_id]
      if (spot_components[unit.id]) then
        spot_components[unit.id] = nil
        updated_tiles[tile_id] = 1
      end
    end
    -- remove unit (may be updated one will be added later)
    united_spotting.participants[unit.id] = nil
  end

  -- step 2: add unit spotting map (if any)
  if (unit.tile) then
    for tile_id, spot_value in pairs(unit.data.spotting_map) do
      local spot_components = united_spotting.addons[tile_id] or {}
      spot_components[unit.id] = 1
      updated_tiles[tile_id] = 1
      united_spotting.addons[tile_id] = spot_components
    end
    united_spotting.participants[unit.id] = _.clone(unit.data.spotting_map, true)
  end

  -- step 3: recalculate max visibility (spot) in the updated tiles
  for tile_id, _ in pairs(updated_tiles) do
    local max_spot = -1
    local spot_components = united_spotting.addons[tile_id]
    if (spot_components) then
      for unit_id, _ in pairs(spot_components) do
        local spot_value = united_spotting.participants[unit_id][tile_id]
        max_spot = math.max(max_spot, spot_value)
      end
    end
    if (max_spot == -1) then max_spot = nil end
    united_spotting.map[tile_id] = max_spot
  end
  -- print(inspect(united_spotting))

  self:_update_units_visibility(unit)
end

function Map:_reset_spotting_map()
  print("_reset_spotting_map")
  self.united_spotting = {
    map          = {},
    addons       = {},
    participants = {},
  }
end

function Map:_on_start_of_turn()
  print("Map:_on_start_of_turn")

  self.turn_started = false
  local player = self.engine.state:get_current_player()
  local units_for_player = self.engine.gear:get("player/units::map")
  local units = self.engine.gear:get("units")

  for _, unit in pairs(units) do
    if(unit.tile) then
      unit.data.visible_to_current_player = false
    end
  end

  -- block event, as we'll update whole picture via
  -- _update_units_visibility() instead of updating it on per-unit basis
  self.engine.reactor.ignoring["unit.change-spotting"] = true
  for _, unit in pairs(units_for_player[player.id]) do
    unit:refresh()
    if(unit.tile) then
      unit:update_spotting_map()
      self:_update_spotting_map(unit)
    end
  end
  self.engine.reactor.ignoring["unit.change-spotting"] = nil


  self:_update_units_visibility()
end

function Map:_update_units_visibility(unit)
  local united_spotting = self.united_spotting

  -- do update only for unit, or for whole map
  local tiles_map = unit and (unit.tile and unit.data.spotting_map)
    or (united_spotting.map)

  -- print(inspect(tiles_map))
  local units_filter = function(unit) return unit.player ~= player end
  for tile_id in pairs(tiles_map) do
    local tile = self.tile_for[tile_id]
    local non_my_units = tile:get_all_units(units_filter)
    for _, u in pairs(non_my_units) do
      local visible = united_spotting.map[tile_id] ~= nil
      u.data.visible_to_current_player = visible
      -- print("making unit on" .. tile_id .. " visible : " .. tostring(visible))
    end
  end
  -- print(inspect(united_spotting))
end

function Map:get_adjastent_tiles(tile, skip_tiles)
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
            and (nx > 1 and nx < self.width)
            and (ny > 1 and ny < self.height)
            and not visited_tiles[Tile.uniq_id(nx, ny)]
      end
      if (found) then
         local tile = self.tiles[nx][ny]
         -- print("found: " .. tile.id .. " ( " .. near_tile .. " ) ")
         found = false -- allow further iterations
         return tile
      end
   end
   return iterator, nil, true
end

function Map:pointer_to_tile(x,y, geometry, map_dx, map_dy)
   local hex_h = geometry.height
   local hex_w = geometry.width
   local hex_x_offset = geometry.x_offset
   local hex_y_offset = geometry.y_offset

   local hex_x_delta = hex_w - hex_x_offset
   local tile_x_delta = map_dx

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
   local my_tile = adj_tiles[nearest_idx]
   local tx = my_tile[1] + ((tile_x_delta % 2 == 0) and 1 or 0 ) + tile_x_delta
   local ty = my_tile[2] + ((tx % 2 == 1) and 1 or 0) + map_dy

   if (tx > 0 and tx <= self.width and ty > 0 and ty <= self.height) then
      return {tx, ty}
      -- print(string.format("my_tile = %d:%d", tx, ty))
   end
end


function Map:_fill_tiles(terrain, map_data, hex_names)
  local engine = self.engine

  local map_w = map_data.width
  local map_h = map_data.height
  local map_path = map_data.path
  local tiles_data = map_data.tiles_data

  local terrain_names_cache = {}
  local get_terrain_name = function(terrain_id)
    if (not terrain_names_cache[terrain_id]) then
      terrain_names_cache[terrain_id] = engine:translate('db.terrain.' .. terrain_id)
    end
    return terrain_names_cache[terrain_id];
  end

  -- 2 dimentional array, [x:y]
  local tiles = {}
  local tile_for = {} -- key: tile_id, value: tile object
  for x = 1, self.width do
    local column = {}
    for y = 1, self.height do
      local idx = (y-1) * map_w + x
      local tile_id = x .. ":" .. y
      local datum = assert(tiles_data[idx], map_path .. " don't have data for tile " .. tile_id)
      local terrain_id = assert(string.sub(datum,1,1), "cannot extract terrain id for tile " .. tile_id)
      local image_idx = assert(string.sub(datum,2, -1), "cannot extract image index for tile " .. tile_id)
      image_idx = tonumber(image_idx)
      local name = hex_names[tile_id] or get_terrain_name(terrain_id)
      local terrain_type = terrain:get_type(terrain_id)
      local tile_data = {
        x            = x,
        y            = y,
        name         = name,
        terrain_id   = terrain_id,
        image_idx    = image_idx,
        terrain_type = terrain_type,
      }
      local tile = Tile.create(self.engine, tile_data)
      column[ y ] = tile
      tile_for[tile.id] = tile
    end
    tiles[x] = column
  end
  self.tiles = tiles
  self.tile_for = tile_for
end

function Map:lookup_tile(id)
  local tile = assert(self.tile_for[id])
  return tile
end

return Map
