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


local Tile = {}
Tile.__index = Tile

local _ = require ("moses")
local inspect = require('inspect')

function Tile.create(engine, terrain, data)
  assert(data.image_idx)
  assert(data.x)
  assert(data.y)
  assert(data.name)
  assert(data.terrain_type)
  assert(data.terrain_name)

  -- use adjusted tiles (hex) coordinates
  local tile_x = data.x
  local tile_y = data.y + math.modf((tile_x - 2) * 0.5)

  data.tile_x = tile_x
  data.tile_y = tile_y

  local virt_x = (data.x - 1) * terrain.hex_x_offset
  local virt_y = ((data.y - 1) * terrain.hex_height)
    + ( (data.x % 2 == 0) and terrain.hex_y_offset or 0)

  local o = {
    id      = Tile.uniq_id(data.x, data.y),
    engine  = engine,
    data    = data,
    virtual = {
      x = virt_x,
      y = virt_y,
    },
    layers  = {
      air     = nil,
      surface = nil,
    },
    drawing = {
      fn          = nil,
      mouse_click = nil,
      objects     = {},
    }
  }
  setmetatable(o, Tile)
  return o
end

function Tile.uniq_id(x,y)
   return string.format("tile[%d:%d]", x, y)
end

function Tile:set_unit(unit, layer)
   assert(layer == 'surface' or layer == 'air', 'unknown layer ' .. inspect(layer))
   self.layers[layer] = unit
end

function Tile:get_unit(layer)
   assert(layer == 'surface' or layer == 'air')
   return self.layers[layer]
end

function Tile:get_any_unit(priority_layer)
   assert(priority_layer == 'surface' or priority_layer == 'air')
   local fallback_layer = (priority_layer == 'air') and 'surface' or 'air'
   return self.layers[priority_layer] or self.layers[fallback_layer]
end

function Tile:get_all_units(filter)
   local units = {}
   for idx, unit in pairs(self.layers) do
      if (filter(unit)) then table.insert(units, unit) end
   end
   return units
end

function Tile:bind_ctx(context)
  local sx, sy = self.data.x, self.data.y
  -- print(inspect(self.data))
  local x = self.virtual.x + context.screen.offset[1]
  local y = self.virtual.y + context.screen.offset[2]
  -- print("drawing " .. self.id .. " at (" .. x .. ":" .. y .. ")")

  local engine = self.engine
  local terrain = engine.gear:get("terrain")
  local map     = engine.gear:get("map")
  local weather = engine:current_weather()
  local player  = engine.state:get_current_player()
  -- print(inspect(weather))
  -- print(inspect(self.data.terrain_type.image))

  local hex_h = terrain.hex_height
  local hex_w = terrain.hex_width

  local dst = {x = x, y = y, w = hex_w, h = hex_h}
  local grid_rectange = {x = 0, y = 0, w = hex_w, h = hex_h}
  local image = terrain:get_hex_image(self.data.terrain_name, weather, self.data.image_idx)


  local landscape_only = context.state:get_landscape_only()
  local show_grid = engine.options.show_grid

  -- draw nation/objective flag in city, unless there is unit (then unit flag will be drawn)
  local objective = self.data.objective
  local units_on_tile = (self.layers.surface and 1 or 0) + (self.layers.air and 1 or 0)
  -- force drawing 0 units
  if (landscape_only) then units_on_tile = 0 end

  local tile_context = _.clone(context, true)
  tile_context.tile = self
  tile_context.unit = {}

  local drawers = {}

  if (objective and (units_on_tile == 0)) then table.insert(drawers, objective) end

  local spotting = map.united_spotting.map[self.id]

  local is_unit_shown = function(unit)
    local result = (unit.player == player) or unit.data.visible_to_current_player
    -- print("unit on " .. unit.tile.id .. " is visible: " .. tostring(unit.data.visible_to_current_player))
    return result
  end

  if (units_on_tile == 1) then
    local normal_unit = self.layers.surface or self.layers.air
    if (is_unit_shown(normal_unit)) then
      tile_context.unit[normal_unit.id] = { size = 'normal' }
      table.insert(drawers, normal_unit)
    end
  elseif (units_on_tile == 2) then -- draw 2 units: small and large
    local active_layer = context.active_layer
    local inactive_layer = (active_layer == 'air') and 'surface' or 'air'

    -- small unit have to added first, as it has lower priority in event,
    -- and should be drawn first, and then, possibly over-drawn by normal
    -- unit. In the same tilme normal-unit events (i.e. click), should be
    -- cauched first. This is more important
    local small_unit = self.layers[inactive_layer]
    if (is_unit_shown(small_unit)) then
      local magnet_to = (inactive_layer == 'air') and 'top' or 'bottom'
      tile_context.unit[small_unit.id] = {size = 'small', magnet_to = magnet_to}
      table.insert(drawers, small_unit)
    end

    local normal_unit = self.layers[active_layer]
    if (is_unit_shown(normal_unit)) then
      tile_context.unit[normal_unit.id] = { size = 'normal' }
      table.insert(drawers, normal_unit)
    end
  end

  local hex_rectange = {x = 0, y = 0, w = hex_w, h = hex_h}

  local sdl_renderer = assert(context.renderer.sdl_renderer)
  local draw_fn = function()
    -- draw terrain
    assert(sdl_renderer:copy(image.texture, hex_rectange, dst))

    if (not landscape_only) then
      -- hilight managed units, participants, fog of war
      local u = context.state:get_selected_unit()
      local disable_fog = false
      if (u) then
        local movement_area = u.data.actions_map.move
        -- print(inspect(_.keys(movement_area)))
        local u_tile = u.tile or u.data.attached_to.tile
        disable_fog = movement_area[self.id]
        if (not disable_fog and (u_tile.id ~= self.id)) then
          local fog = terrain:get_icon('fog')
          assert(sdl_renderer:copy(fog.texture, hex_rectange, dst))
        end
      end
      if (context.subordinated[self.id]) then
        local managed = terrain:get_icon('managed')
        assert(sdl_renderer:copy(managed.texture, hex_rectange, dst))
      end
      if (context.state.participant_locations and context.state.participant_locations[self.id]) then
        local participant = terrain:get_icon('participant')
        assert(sdl_renderer:copy(participant.texture, hex_rectange, dst))
      end
      -- fog of war
      if (not spotting and not disable_fog) then
        local fog = terrain:get_icon('fog')
        assert(sdl_renderer:copy(fog.texture, hex_rectange, dst))
      end
    end

    -- draw flag and unit(s)
    _.each(self.drawing.objects, function(k, v) v:draw() end)

    -- draw grid
    if (show_grid) then
      local icon = terrain:get_icon('grid')
      assert(sdl_renderer:copy(icon.texture, grid_rectange, dst))
    end

  end

  local mouse_click = function(event)
    if (event.tile_id == self.id and event.button == 'left') then
      local u = context.state:get_selected_unit()
      local action = context.state:get_action()
      if (action == 'default') then
        if (u and (not u.tile or (u.tile.id ~= self.id))) then
          print("unselecting unit")
          context.state:set_selected_unit(nil)
          self.engine.reactor:publish("map.update")
          return true
        end
      else
        local actor = assert(context.state:get_selected_unit())
        local method_for = {
          move  = 'move_to',
          land  = 'land_to',
        }
        local method = assert(method_for[action])
        actor[method](actor, self, action)
        return true
      end
    elseif (event.button == 'right') then
      local u = context.state:get_selected_unit()
      if (u) then
        context.state:set_selected_unit(nil)
        context.state:set_action('default')
        self.engine.reactor:publish("map.update")
        return true
      end
    end
  end

  local mouse_move = function(event)
    if (event.tile_id == self.id) then
      local u = context.state:get_selected_unit()
      local action = 'default'
      if (u and u.data.actions_map.landing[self.id]) then
        action = 'land'
      elseif (u and u.data.actions_map.move[self.id]) then
        action = 'move'
      end
      context.state:set_mouse_hint('')
      context.state:set_action(action)
      return true
    end
  end
  -- tile handlers has lower priority then unit handlers, add them first
  context.events_source.add_handler('mouse_click', self.id, mouse_click)
  context.events_source.add_handler('mouse_move', self.id, mouse_move)

  _.each(drawers, function(k, v) v:bind_ctx(tile_context) end)

  self.drawing.objects = drawers
  self.drawing.fn = draw_fn
  self.drawing.mouse_click = mouse_click
  self.drawing.mouse_move = mouse_move
end

function Tile:unbind_ctx(context)
  _.each(self.drawing.objects, function(k, v) v:unbind_ctx(context) end)

  context.events_source.remove_handler('mouse_click', self.id, self.drawing.mouse_click)
  context.events_source.remove_handler('mouse_move', self.id, self.drawing.mouse_move)

  self.drawing.fn = nil
  self.drawing.mouse_click = nil
  self.drawing.mouse_move = nil
end

function Tile:draw()
  assert(self.drawing.fn)
  self.drawing.fn()
end

function Tile:distance_to(other_tile)
   --[[
      calculate the distance in tile coordinates, see hex grid geometry
      http://playtechs.blogspot.com.by/2007/04/hex-grids.html
   --]]
   local dx = self.data.tile_x - other_tile.data.tile_x
   local dy = self.data.tile_y - other_tile.data.tile_y
   local value = (math.abs(dx) + math.abs(dy) + math.abs(dy - dx)) / 2

   return value;
end

function Tile:is_capable(flag_mask)
  local terrain = self.engine.gear:get("terrain")
  return terrain:is_capable(self.data.terrain_type.id, flag_mask)
end

return Tile
