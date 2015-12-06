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

local Map = {}
Map.__index = Map

local _ = require ("moses")
local Parser = require 'polkovodets.Parser'
local Terrain = require 'polkovodets.Terrain'
local Tile = require 'polkovodets.Tile'
local inspect = require('inspect')


local SCROLL_TOLERANCE = 5

function Map.create(engine)
   local m = {
    engine = engine,
    active_tile    = {1, 1},
    drawing = {
      fn          = nil,
      mouse_move  = nil,
      idle        = nil,
      objects     = {},
      -- k: original fn, value: proxied (map) fn
      proxy       = {
        mouse_move  = {},
        mouse_click = {},
      }
    }
  }
  setmetatable(m, Map)
  return m
end


function Map:load(map_file)
  local path = map_file
  print('loading map at ' .. path)
  local parser = Parser.create(path)
  self.width = tonumber(parser:get_value('width'))
  self.height = tonumber(parser:get_value('height'))
  print("map size: " .. self.width .. "x" .. self.height)
  assert(self.width > 3, "map width must me > 3")
  assert(self.height > 3, "map height must me > 3")

  local terrain_file = parser:get_value('terrain_db')
  assert(terrain_file)

  local engine = self.engine
  local terrain = Terrain.create(engine)
  terrain:load(terrain_file)
  self.terrain = terrain

  local tiles_data = parser:get_list_value('tiles')
  local tile_names = parser:get_list_value('names')

  -- 2 dimentional array, [x:y]
  local tiles = {}
  local tile_for = {} -- key: tile_id, value: tile object
  for x = 1,self.width do
    local column = {}
    for y = 1,self.height do
      local idx = (y-1) * self.width + x
      local datum = tiles_data[idx]
      local terrain_name = string.sub(datum,1,1)
      local image_idx = tonumber(string.sub(datum,2, -1))
      local terrain_type = terrain:get_type(terrain_name)
      local name = tile_names[idx] or terrain_name
      local tile_data = {
        x = x,
        y = y,
        name = name,
        terrain_name = terrain_name,
        image_idx = image_idx,
        terrain_type = terrain_type,
      }
      local tile = Tile.create(engine, terrain, tile_data)
      column[ y ] = tile
      tile_for[tile.id] = tile
    end
    tiles[x] = column
  end
  self.tiles = tiles
  self.tile_for = tile_for
  -- print(inspect(tiles[1][1]))

  engine.state.active_tile = self.tiles[1][1]
  self.tile_geometry = {
    w        = terrain.hex_width,
    h        = terrain.hex_height,
    x_offset = terrain.hex_x_offset,
    y_offset = terrain.hex_y_offset,
  }
end

function Map:bind_ctx(context)
  local engine = self.engine
  local terrain = self.terrain

  local start_map_x = engine.gui.map_x
  local start_map_y = engine.gui.map_y

  local map_sw = (engine.gui.map_sw > self.width) and self.width or engine.gui.map_sw
  local map_sh = (engine.gui.map_sh > self.height) and self.height or engine.gui.map_sh

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
      engine.gui.map_sx - (engine.gui.map_x * terrain.hex_x_offset),
      engine.gui.map_sy - (engine.gui.map_y * terrain.hex_height),
    }
  }
  map_context.active_layer = engine.active_layer

  -- proxy mouse click and mouse move callbacks, to provide actual
  -- tile context
  local create_proxy = function(event_type, cb)
    local proxy = function(event)
      local proxied_ctx = _.clone(event, true)
      proxied_ctx.tile_id = context.state.active_tile.id
      return cb(proxied_ctx)
    end
    self.drawing.proxy[event_type][cb] = proxy
    return context.events_source.add_handler(event_type, proxy)
  end
  map_context.events_source = {
    add_handler = function(event_type, cb)
      if (event_type == 'mouse_move') then
        return create_proxy(event_type, cb)
      elseif (event_type == 'mouse_click') then
        return create_proxy(event_type, cb)
      else
        context.events_source.add_handler(event_type, cb)
      end
    end,
  }

  local u = context.state.selected_unit

  local active_x, active_y = table.unpack(self.active_tile)
  local active_tile = self.tiles[active_x][active_y]
  local hilight_unit = u or (active_tile and active_tile:get_unit(engine.active_layer))
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

  local actual_records = context.state.actual_records
  local landscape_only = context.state.landscape_only

  -- bttles are always shown
  local shown_records = {}

  if (not landscape_only) then
    shown_records = _.select(actual_records, battles)
    if (u) then
      shown_records = _.append(shown_records, _.select(actual_records, my_unit_movements))
    end

    if (engine:show_history()) then
      shown_records = _.append(shown_records, _.select(actual_records, opponent_movements))
    end
    -- print("shown records " .. #shown_records)
  end

  -- propagete drawing context
  local drawers = {}
  drawers = {}
  -- self:bind_ctx(context)
  visible_area_iterator(function(tile) table.insert(drawers, tile) end)
  _.each(shown_records, function(k, v) table.insert(drawers, v) end)


  local sdl_renderer = assert(context.renderer.sdl_renderer)
  local draw_fn = function()
    _.each(drawers, function(k, v) v:draw() end)
  end

  local mouse_move = function(event)
    local new_tile = self.engine:pointer_to_tile(event.x, event.y)
    local old_tile = context.state.active_tile
    if (new_tile and ((old_tile.data.x ~= new_tile[1]) or (old_tile.data.y ~= new_tile[2])) ) then
      engine.state.active_tile = self.tiles[new_tile[1]][new_tile[2]]
      -- print("active tile:" .. engine.state.active_tile.id)
      engine.mediator:publish({ "view.update" })
    end
  end


  local map_w, map_h = engine.map.width, engine.map.height
  local map_sw, map_sh = engine.gui.map_sw, engine.gui.map_sh
  local window_w, window_h = context.renderer.window:getSize()

  local idle = function(event)
    local scroll_dy, scroll_dx = 0, 0
    local direction
    local x, y = event.x, event.y
    local map_x, map_y = engine.gui.map_x, engine.gui.map_y
    if ((y < SCROLL_TOLERANCE or scroll_dy > 0) and map_y > 0) then
      engine.gui.map_y = engine.gui.map_y - 1
      direction = "up"
    elseif (((y > window_h - SCROLL_TOLERANCE) or scroll_dy < 0) and map_y < map_h - map_sh) then
      engine.gui.map_y = engine.gui.map_y + 1
      direction = "down"
    elseif ((x < SCROLL_TOLERANCE or scroll_dx < 0)  and map_x > 0) then
      engine.gui.map_x = engine.gui.map_x - 1
      direction = "left"
    elseif (((x > window_w - SCROLL_TOLERANCE) or scroll_dx > 0) and map_x < map_w - map_sw) then
      engine.gui.map_x = engine.gui.map_x + 1
      direction = "right"
    end

    if (direction) then
      engine:update_shown_map()
      engine.mediator:publish({ "view.update" })
    end
    return true
  end

  _.each(drawers, function(k, v) v:bind_ctx(map_context) end)

  context.events_source.add_handler('mouse_move', mouse_move)
  context.events_source.add_handler('idle', idle)

  self.drawing.objects = drawers
  self.drawing.mouse_click = mouse_click
  self.drawing.mouse_move = mouse_move
  self.drawing.fn = draw_fn
end

function Map:unbind_ctx(context)
  local map_ctx = _.clone(context, true)
  map_ctx.events_source = {
    remove_handler = function(event_type, cb)
      if (event_type == 'mouse_move') then
        local proxy = assert(self.drawing.proxy[event_type][cb])
        self.drawing.proxy[event_type][cb] = nil
        return context.events_source.remove_handler(event_type, proxy)
      elseif (event_type == 'mouse_click') then
        local proxy = assert(self.drawing.proxy[event_type][cb])
        self.drawing.proxy[event_type][cb] = nil
        return context.events_source.remove_handler(event_type, proxy)
      else
        return context.events_source.remove_handler(event_type, cb)
      end
    end,
  }
  _.each(self.drawing.objects, function(k, v) v:unbind_ctx(map_ctx) end)

  context.events_source.remove_handler('mouse_move', self.drawing.mouse_move)

  self.drawing.fn = nil
  self.drawing.idle = nil
  self.drawing.mouse_move = nil
  self.drawing.objects = nil
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
