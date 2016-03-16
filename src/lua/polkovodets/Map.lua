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
local Parser = require 'polkovodets.Parser'
local Terrain = require 'polkovodets.Terrain'
local Tile = require 'polkovodets.Tile'
local inspect = require('inspect')
local OrderedHandlers = require 'polkovodets.utils.OrderedHandlers'


local SCROLL_TOLERANCE = 5

function Map.create()
   local m = {
    engine = nil,
    active_tile    = {1, 1},
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
    drawing = {
      fn          = nil,
      mouse_move  = nil,
      idle        = nil,
      context     = nil,
      map_context = nil,
      objects     = {},
      -- k: tile_id, value: ordered set of callbacks
      proxy       = {
        mouse_move  = {},
        mouse_click = {},
      },
      drawers_per_tile = {},
    }
  }
  setmetatable(m, Map)
  return m
end

function Map:initialize(engine, renderer, terrain, tiles_generator, map_data)
  self.engine   = engine
  self.renderer = renderer
  self.terrain  = terrain
  self.tile_geometry = {
    w        = terrain.hex_width,
    h        = terrain.hex_height,
    x_offset = terrain.hex_x_offset,
    y_offset = terrain.hex_y_offset,
  }
  self.width  = assert(map_data.width)
  self.height = assert(map_data.height)
  self:_fill_tiles(tiles_generator)
  engine.state:set_active_tile(self.tiles[1][1])

  self.engine.reactor:subscribe("full.refresh", function() self:_update_shown_map() end)
  self:_update_shown_map()
end

function Map:_update_shown_map()
  local gui = self.gui
  gui.map_sx = -self.terrain.hex_x_offset
  gui.map_sy = -self.terrain.hex_height

  -- calculate drawn number of tiles
  local w, h = self.renderer:get_size()
  local step = 0
  local ptr = gui.map_sx
  while(ptr < w) do
    step = step + 1
    ptr = ptr + self.terrain.hex_x_offset
  end
  gui.map_sw = step

  step = 0
  ptr = gui.map_sy
  while(ptr < h) do
    step = step + 1
    ptr = ptr + self.terrain.hex_height
  end
  gui.map_sh = step
  print(string.format("visible hex frame: (%d, %d, %d, %d)", gui.map_x, gui.map_y, gui.map_x + gui.map_sw, gui.map_y + self.gui.map_sh))
  self.engine.reactor:publish("map.update")
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

function Map:pointer_to_tile(x,y)
   local geometry = self.tile_geometry
   local hex_h = geometry.h
   local hex_w = geometry.w
   local hex_x_offset = geometry.x_offset
   local hex_y_offset = geometry.y_offset

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

   if (tx > 0 and tx <= self.width and ty > 0 and ty <= self.height) then
      return {tx, ty}
      -- print(string.format("active tile = %d:%d", tx, ty))
   end
end


function Map:_fill_tiles(tile_generator)
  local engine = self.engine
  local terrain = self.terrain

  -- 2 dimentional array, [x:y]
  local tiles = {}
  local tile_for = {} -- key: tile_id, value: tile object
  for x = 1, self.width do
    local column = {}
    for y = 1, self.height do
      local tile = tile_generator(terrain, x, y)
      column[ y ] = tile
      tile_for[tile.id] = tile
    end
    tiles[x] = column
  end
  self.tiles = tiles
  self.tile_for = tile_for
end

function Map:_get_event_source()
  return {
    add_handler    = function(event_type, tile_id, cb) return self:_add_hanlder(event_type, tile_id, cb) end,
    remove_handler = function(event_type, tile_id, cb) return self:_remove_hanlder(event_type, tile_id, cb) end,
  }
end


function Map:_add_hanlder(event_type, tile_id, cb)
  assert(event_type and tile_id and cb)
  local tile_to_set = assert(self.drawing.proxy[event_type])
  local set = tile_to_set[tile_id] or OrderedHandlers.new()
  set:insert(cb)
  tile_to_set[tile_id] = set
end


function Map:_remove_hanlder(event_type, tile_id, cb)
  assert(event_type and tile_id and cb)
  local tile_to_set = assert(self.drawing.proxy[event_type])
  local set = assert(tile_to_set[tile_id])
  set:remove(cb)
end

function Map:_on_map_update()
  local engine = self.engine
  local terrain = self.terrain
  local context = self.drawing.context

  local start_map_x = self.gui.map_x
  local start_map_y = self.gui.map_y

  local map_sw = (self.gui.map_sw > self.width) and self.width or self.gui.map_sw
  local map_sh = (self.gui.map_sh > self.height) and self.height or self.gui.map_sh

  local visible_area_iterator = function(callback)
    for i = 1,map_sw do
      local tx = i + start_map_x
      for j = 1,map_sh do
        local ty = j + start_map_y
        if (tx <= self.width and ty <= self.height) then
          local tile = assert(self.tiles[tx][ty], string.format("tile [%d:%d] not found", tx, ty))
          callback(tile)
        end
      end
    end
  end

  local tile_visibility_test = function(tile)
    local x, y = tile.data.x, tile.data.y
    local result
      =   (x >= start_map_x and x <= map_sw)
      and (y >= start_map_y and y <= map_sh)
    return result
  end

  local map_context = _.clone(context, true)
  map_context.map = self
  map_context.tile_visibility_test = tile_visibility_test
  map_context.tile_geometry = self.tile_geometry
  map_context.screen = {
    offset = {
      self.gui.map_sx - (self.gui.map_x * terrain.hex_x_offset),
      self.gui.map_sy - (self.gui.map_y * terrain.hex_height),
    }
  }
  local active_layer = engine.state:get_active_layer()
  map_context.active_layer = active_layer
  map_context.events_source = self:_get_event_source()

  _.each(self.drawing.objects, function(k, v) v:unbind_ctx(map_context) end)

  local u = context.state:get_selected_unit()

  local active_x, active_y = table.unpack(self.active_tile)
  local active_tile = self.tiles[active_x][active_y]
  local hilight_unit = u or (active_tile and active_tile:get_unit(active_layer))
  map_context.subordinated = {}
  if (hilight_unit) then
    for idx, subordinated_unit in pairs(hilight_unit:get_subordinated(true)) do
      local tile = subordinated_unit.tile
      -- tile could be nil if unit is attached to some other
      if (tile) then
        map_context.subordinated[tile.id] = true
      end
    end
  end

  local my_unit_movements = function(k, v)
    if (u and v.action == 'unit/move') then
      local unit_id = v.context.unit_id
      return (unit_id and unit_id == u.id)
    end
  end
  local battles_cache = {}
  local battles = function(k, v)
    if ((v.action == 'battle') and (not battles_cache[v.context.tile])) then
      local tile_id = v.context.tile
      battles_cache[tile_id] = true
      local tile = self:lookup_tile(tile_id)
      assert(tile)
      return true
    end
  end

  local opponent_movements = function(k, v)
    if (v.action == 'unit/move') then
      local unit_id = v.context.unit_id
      local unit = engine:get_unit(unit_id)
      local show = unit.player ~= engine:get_current_player()
      return show
    end
  end

  local actual_records = context.state:get_actual_records()

  -- bttles are always shown
  local shown_records = {}

  if (not context.state:get_landscape_only()) then
    shown_records = _.select(actual_records, battles)
    if (u) then
      shown_records = _.append(shown_records, _.select(actual_records, my_unit_movements))
    end

    if (engine.state:get_recent_history()) then
      shown_records = _.append(shown_records, _.select(actual_records, opponent_movements))
    end
    -- print("shown records " .. #shown_records)
  end

  -- propagete drawing context
  local drawers = {}
  local drawers_per_tile = {} -- k: tile_id, v: list of drawers
  local add_drawer = function(tile_id, drawer)
    table.insert(drawers, drawer)
    if (tile_id) then
      local existing_tile_drawers = drawers_per_tile[tile_id] or {}
      table.insert(existing_tile_drawers, drawer)
      drawers_per_tile[tile_id] = existing_tile_drawers
    end
  end
  -- self:bind_ctx(context)
  visible_area_iterator(function(tile) add_drawer(tile.id, tile) end)
  _.each(shown_records, function(k, v)
    local tile_id = (v.action == 'battle') and v.context.tile
    add_drawer(tile_id, v)
  end)

  local sdl_renderer = assert(context.renderer.sdl_renderer)
  local draw_fn = function()
    _.each(drawers, function(k, v) v:draw() end)
  end

  _.each(drawers, function(k, v) v:bind_ctx(map_context) end)

  self.drawing.map_context = map_context
  self.drawing.objects = drawers
  self.drawing.drawers_per_tile = drawers_per_tile
  self.drawing.fn = draw_fn
end


function Map:bind_ctx(context)
  local engine = self.engine
  local terrain = self.terrain

  local mouse_move = function(event)
    local new_tile = self:pointer_to_tile(event.x, event.y)
    if (not new_tile) then return end
    local tile_new = self.tiles[new_tile[1]][new_tile[2]]
    event.tile_id = tile_new.id
    local tile_old = context.state:get_active_tile()
    if (new_tile and ((tile_old.data.x ~= new_tile[1]) or (tile_old.data.y ~= new_tile[2])) ) then
      engine.state:set_active_tile(tile_new)
      -- print("refreshing " .. tile_old.id .. " => " .. tile_new.id)

      local refresh = function(tile)
        local list = self.drawing.drawers_per_tile[tile.id]
        if (list) then
          for idx, drawer in pairs(list) do
            drawer:unbind_ctx(self.drawing.map_context)
            drawer:bind_ctx(self.drawing.map_context)
          end
        end
      end
      refresh(tile_old)
      refresh(tile_new)

      -- apply handlers for old tile
      local ordered_handlers = self.drawing.proxy.mouse_move[tile_old.id]
      if (ordered_handlers) then
        ordered_handlers:apply(function(cb) return cb(event) end)
      end
    end

    -- apply hanlders for the new/current tile
    local ordered_handlers = self.drawing.proxy.mouse_move[tile_new.id]
    if (ordered_handlers) then
      ordered_handlers:apply(function(cb) return cb(event) end)
    end
  end

  local mouse_click = function(event)
    local tile_coord = self:pointer_to_tile(event.x, event.y)
    -- tile coord might be nil, if the shown area is greater than map
    -- i.e. the click has been performed outside of the map
    if (tile_coord) then
      local tile = self.tiles[tile_coord[1]][tile_coord[2]]
      event.tile_id = tile.id
      local ordered_handlers = self.drawing.proxy.mouse_click[tile.id]
      if (ordered_handlers) then
        ordered_handlers:apply(function(cb) return cb(event) end)
      end
    end
  end


  local map_w, map_h = self.width, self.height
  local map_sw, map_sh = self.gui.map_sw, self.gui.map_sh
  local window_w, window_h = context.renderer.window:getSize()

  local idle = function(event)
    local scroll_dy, scroll_dx = 0, 0
    local direction
    local x, y = event.x, event.y
    local map_x, map_y = self.gui.map_x, self.gui.map_y
    if ((y < SCROLL_TOLERANCE or scroll_dy > 0) and map_y > 0) then
      self.gui.map_y = self.gui.map_y - 1
      direction = "up"
    elseif (((y > window_h - SCROLL_TOLERANCE) or scroll_dy < 0) and map_y < map_h - map_sh) then
      self.gui.map_y = self.gui.map_y + 1
      direction = "down"
    elseif ((x < SCROLL_TOLERANCE or scroll_dx < 0)  and map_x > 0) then
      self.gui.map_x = self.gui.map_x - 1
      direction = "left"
    elseif (((x > window_w - SCROLL_TOLERANCE) or scroll_dx > 0) and map_x < map_w - map_sw) then
      self.gui.map_x = self.gui.map_x + 1
      direction = "right"
    end

    if (direction) then
      self:_update_shown_map()
    end
    return true
  end


  local map_update_listener = function()
    print("map.update")
    self:_on_map_update(context)
  end

  engine.reactor:subscribe("map.update", map_update_listener)

  context.events_source.add_handler('mouse_move', mouse_move)
  context.events_source.add_handler('mouse_click', mouse_click)
  context.events_source.add_handler('idle', idle)

  self.drawing.context = context
  self.drawing.mouse_click = mouse_click
  self.drawing.mouse_move = mouse_move
  self.drawing.idle = idle
  self.drawing.map_update_listener = map_update_listener

  self.drawing.fn = function() end
  engine.reactor:publish("map.update")
  -- self.drawing.fn is initialized indirectly via map.update handler
end

function Map:unbind_ctx(context)
  local map_ctx = _.clone(context, true)
  map_ctx.events_source = self:_get_event_source()
  _.each(self.drawing.objects, function(k, v) v:unbind_ctx(map_ctx) end)

  self.engine.reactor:unsubscribe("map.update", self.drawing.map_update_listener)

  context.events_source.remove_handler('mouse_move', self.drawing.mouse_move)
  context.events_source.remove_handler('mouse_click', self.drawing.mouse_click)
  context.events_source.remove_handler('idle', self.drawing.idle)

  self.drawing.fn = nil
  self.drawing.idle = nil
  self.drawing.mouse_move = nil
  self.drawing.objects = {}
  self.drawing.context = nil
end

function Map:draw()
  assert(self.drawing.fn)
  self.drawing.fn()
end


function Map:lookup_tile(id)
  local tile = assert(self.tile_for[id])
  return tile
end

return Map
