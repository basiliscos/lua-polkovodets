--[[

Copyright (C) 2016 Ivan Baidakou

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

local _ = require ("moses")
local inspect = require('inspect')

local SDL = require "SDL"
local Widget = require 'polkovodets.gui.Widget'
local Image = require 'polkovodets.utils.Image'
local Region = require 'polkovodets.utils.Region'

local StrategicalMapWindow = {}
StrategicalMapWindow.__index = StrategicalMapWindow
setmetatable(StrategicalMapWindow, Widget)

local FONT_SIZE = 12
local AVAILABLE_COLOR = 0xAAAAAA
local HILIGHT_COLOR = 0xFFFFFF


function StrategicalMapWindow.create(engine)
  local o = Widget.create(engine)
  setmetatable(o, StrategicalMapWindow)
  o.drawing.content_fn = nil
  o.content = {}
  o.record = data
  local theme = engine.gear:get("theme")

  o.text = {
    font  = theme:get_font('default', FONT_SIZE),
  }
  o.drawing.position = {0, 0}

  return o
end

function StrategicalMapWindow:_construct_gui()
  local engine = self.engine
  local renderer = engine.gear:get("renderer")
  local map = engine.gear:get("map")
  local tile_geometry = map.tile_geometry
  local context = self.drawing.context
  local weather = engine:current_weather()
  local terrain = engine.gear:get("terrain")

  local get_sclaled_width = function(scale)
    return map.width * map.tile_geometry.x_offset / scale
  end
  local get_sclaled_height = function(scale)
    return map.height * map.tile_geometry.h / scale
  end


  local window_w, window_h = renderer:get_size()
  local max_w, max_h = math.modf(window_w * 1.0), math.modf(window_h * 1.0)

  local scale_w, scale_h = 1, 1;
  while (get_sclaled_width(scale_w) > max_w) do scale_w = scale_w + 1 end
  while (get_sclaled_height(scale_h) > max_h) do scale_h = scale_h + 1 end

  -- local scale = math.max(scale_w, scale_h)
  local scale = 5
  local w, h = math.modf(get_sclaled_width(scale)), math.modf(get_sclaled_height(scale))
  print(string.format("w = %d, h = %d, scale = %d", w, h, scale))

  local scaled_geometry = {
    w        = tile_geometry.w / scale,
    h        = tile_geometry.h / scale,
    x_offset = tile_geometry.x_offset / scale,
    y_offset = tile_geometry.y_offset / scale,
  }
  -- local screen_dx, screen_dy = table.unpack(context.screen.offset)
  local screen_dx, screen_dy = 0, 0

  -- We cannot use common math (virtual coordinates), because rounding errors lead to gaps between tiles,
  -- and they look terribly. Hence, we re-calculate tiels using int-math

  local tile_w, tile_h = math.modf(scaled_geometry.w), math.modf(scaled_geometry.h)
  local x_offset, y_offset = math.modf(scaled_geometry.x_offset), math.modf(scaled_geometry.y_offset)

  local layer = engine.state:get_active_layer()

  -- k: tile_id, value: description
  local tile_positions = {}
  for i = 1, map.width do
    for j = 1, map.height do
      local tile = map.tiles[i][j]
      local dst = {
        x = i * x_offset,
        y = j * tile_h + ( (i % 2 == 0) and y_offset or 0),
        w = tile_w,
        h = tile_h,
      }
      local image = terrain:get_hex_image(tile.data.terrain_type.id, weather, tile.data.image_idx)
      local flag_data

      local unit = tile:get_unit(layer)

      if (unit) then
        local flag = unit.definition.nation.unit_flag
        flag_data = {
          dst = {
            x = dst.x + (tile_w - x_offset),
            y = dst.y,
            w = tile_w - ((tile_w - x_offset) *2),
            h = tile_h,
          },
          image = flag,
        }
        -- print("flag data " .. inspect(flag_data))
        -- error("dst " .. inspect(dst))
      end

      tile_positions[tile.id] = {
        dst       = dst,
        image     = image,
        flag_data = flag_data,
      }
    end
  end

  local right_tile = map.tiles[map.width][map.height]
  local right_pos = tile_positions[right_tile.id]
  local bot_tile = map.tiles[1][map.height]
  local bot_pos = tile_positions[bot_tile.id]

  w = right_pos.dst.x + x_offset + tile_w
  h = bot_pos.dst.y + tile_h * 2 + y_offset

  local gui = {
    scale = scale,
    scaled_geometry = scaled_geometry,
    content_size = {w = w, h = h},
    tile_positions = tile_positions,
  }
  return gui
end

function StrategicalMapWindow:_on_ui_update(show)
  local engine = self.engine
  local context = self.drawing.context
  local handlers_bound = self.handlers_bound

  if (show) then
    local theme = engine.gear:get("theme")
    local sdl_renderer = engine.gear:get("renderer").sdl_renderer
    local gui = self.drawing.gui
    local map = engine.gear:get("map")
    local terrain = engine.gear:get("terrain")

    local x, y = table.unpack(self.drawing.position)
    local content_x, content_y = x + self.contentless_size.dx, y + self.contentless_size.dy
    local content_w, content_h = gui.content_size.w, gui.content_size.h

    local window_region = Region.create(x, y, content_x + content_w + self.contentless_size.dx, content_y + content_h + self.contentless_size.dy)

    -- pre-render map in memory, just copy it during rendering cycle
    local format = theme.window.background.texture:query()
    local map_texture = assert(sdl_renderer:createTexture(format, SDL.textureAccess.Target, content_w, content_h))

    assert(sdl_renderer:setTarget(map_texture))

    -- copy background
    assert(sdl_renderer:copy(theme.window.background.texture, nil,
      {x = content_x, y = content_y, w = content_w, h = content_h}
    ))

    local fog = terrain:get_icon('fog')
    -- copy terrain with fog
    for i = 1, map.width do
      for j = 1, map.height do
        local tile = map.tiles[i][j]

        -- terrain
        local description = gui.tile_positions[tile.id]
        assert(sdl_renderer:copy(description.image.texture, nil, description.dst))

        local spotting = map.united_spotting.map[tile.id]
        if (not spotting) then
          -- fog of war
          assert(sdl_renderer:copy(fog.texture, nil, description.dst))
        elseif (description.flag_data) then
          -- unit flag, scaled up to hex
          local dst = description.flag_data.dst
          local image = description.flag_data.image
          assert(sdl_renderer:copy(image.texture, nil, dst))
        end
      end
    end
    assert(sdl_renderer:setTarget(nil))
    local map_dst = {x = content_x, y = content_y, w = content_w, h = content_h}

    -- actual draw function is rather simple
    self.drawing.content_fn = function()
      assert(sdl_renderer:copy(map_texture, nil, map_dst))
      Widget.draw(self)
    end
    Widget.update_drawer(self, x, y, content_w, content_h)

    if (not handlers_bound) then
      self.handlers_bound = true

      local mouse_move = function(event)
        engine.state:set_mouse_hint('')
        if (window_region:is_over(event.x, event.y)) then
        end
        return true -- stop further event propagation
      end
      local mouse_click = function(event)
        if (window_region:is_over(event.x, event.y)) then
        else
          engine.interface:remove_window(self)
        end
        return true -- stop further event propagation
      end

      context.events_source.add_handler('mouse_move', mouse_move)
      context.events_source.add_handler('mouse_click', mouse_click)

      self.content.mouse_move = mouse_move
      self.content.mouse_click = mouse_click
    end
  elseif(handlers_bound) then -- unbind everything
    self.handlers_bound = false
    context.events_source.remove_handler('mouse_click', self.content.mouse_click)
    context.events_source.remove_handler('mouse_move', self.content.mouse_move)
    self.content.mouse_click = nil
    self.content.mouse_move = nil
    self.drawing.content_fn = function() end
  end
end

function StrategicalMapWindow:bind_ctx(context)
  local engine = self.engine

  -- remember ctx first, as it is involved in gui construction
  self.drawing.context = context
  local gui = self:_construct_gui()
  local ui_update_listener = function() return self:_on_ui_update(true) end

  self.drawing.ui_update_listener = ui_update_listener
  self.drawing.gui = gui

  engine.reactor:subscribe('ui.update', ui_update_listener)

  local w, h = gui.content_size.w + self.contentless_size.w, gui.content_size.h + self.contentless_size.h
  return {w, h}
end

function StrategicalMapWindow:set_position(x, y)
  self.drawing.position = {x, y}
end

function StrategicalMapWindow:unbind_ctx(context)
  self:_on_ui_update(false)
  self.engine.reactor:unsubscribe('ui.update', self.drawing.ui_update_listener)
  self.drawing.ui_update_listener = nil
  self.drawing.context = nil
end

function StrategicalMapWindow:draw()
  self.drawing.content_fn()
end


return StrategicalMapWindow
