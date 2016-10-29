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
local SDL	= require "SDL"
local Region = require 'polkovodets.utils.Region'

local _ = require ("moses")
local inspect = require('inspect')

function Tile.create(engine, data)
  assert(data.image_idx)
  assert(data.x)
  assert(data.y)
  assert(data.name)
  assert(data.terrain_type)
  assert(data.terrain_id)

  local hex_geometry = engine.gear:get("hex_geometry")

  data.build_efforts = 0

  -- use adjusted tiles (hex) coordinates
  local tile_x = data.x
  local tile_y = data.y + math.modf((tile_x - 2) * 0.5)

  data.tile_x = tile_x
  data.tile_y = tile_y

  local virt_x = (data.x - 1) * hex_geometry.x_offset
  local virt_y = ((data.y - 1) * hex_geometry.height)
    + ( (data.x % 2 == 0) and hex_geometry.y_offset or 0)

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
    stash = {},
    drawing = {
      fn          = nil,
      mouse_click = nil,
      objects     = {},
    },
    hex_geometry = hex_geometry,
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

function Tile:stash_unit(unit)
    table.insert(self.stash, unit)
    unit.tile = self
end

function Tile:unstash_unit(unit)
    for idx, u in pairs(self.stash) do
        if (u == unit) then
            table.remove(self.stash, idx)
        end
    end
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

  local engine  = self.engine
  local terrain = engine.gear:get("terrain")
  local map     = engine.gear:get("map")
  local weather = engine:current_weather()
  local state   = engine.state
  local player  = state:get_current_player()
  local sdl_renderer = engine.gear:get("renderer").sdl_renderer
  local hex_geometry = engine.gear:get("hex_geometry")

  -- print(inspect(weather))
  -- print(inspect(self.data.terrain_type.image))

  local hex_h = self.hex_geometry.height
  local hex_w = self.hex_geometry.width

  local dst = {x = x, y = y, w = hex_w, h = hex_h}
  local grid_rectange = {x = 0, y = 0, w = hex_w, h = hex_h}
  local image = terrain:get_hex_image(self.data.terrain_type.id, weather, self.data.image_idx)


  local landscape_only = state:get_landscape_only()
  local show_grid = state:get_show_grid()

  -- draw nation/objective flag in city, unless there is unit (then unit flag will be drawn)
  local objective = self.data.objective
  local units_per_layer = {}
  local units_on_tile = 0
  if (not landscape_only) then
      for _, layer in pairs({'surface', 'air'}) do
        local unit = self.layers[layer]
        if (unit) then
            units_per_layer[layer] = unit
            units_on_tile = units_on_tile + 1
        end
      end
  end

  local tile_context = _.clone(context, true)
  tile_context.tile = self
  tile_context.unit = {}

  local drawers = {}

  local spotting = map.united_spotting.map[self.id]

  local is_unit_shown = function(unit)
    local result = (unit.player == player) or unit.data.visible_to_current_player
    -- print("unit on " .. unit.tile.id .. " is visible: " .. tostring(unit.data.visible_to_current_player))
    return result
  end
  local is_unit_drawn = function(unit)
    local land_unit_in_airport = (unit.definition.unit_type.id == 'ut_land') and (self.data.terrain_id == 'a')
    local land_unit_in_port = (unit.definition.unit_type.id == 'ut_land') and (self.data.terrain_id == 'h')
    local result = (not land_unit_in_airport) and (not land_unit_in_port)
    return result
  end

  local main_unit
  local drawn_units = 0

  if (units_on_tile == 1) then
    local normal_unit = self.layers.surface or self.layers.air
    if (is_unit_shown(normal_unit)) then
      main_unit = normal_unit
      if (is_unit_drawn(normal_unit)) then
          tile_context.unit[normal_unit.id] = { size = 'normal' }
          table.insert(drawers, normal_unit)
          drawn_units = drawn_units + 1
      end
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
      main_unit = small_unit
      if (is_unit_drawn(small_unit)) then
          local magnet_to = (inactive_layer == 'air') and 'top' or 'bottom'
          tile_context.unit[small_unit.id] = {size = 'small', magnet_to = magnet_to}
          table.insert(drawers, small_unit)
          drawn_units = drawn_units + 1
      end
    end

    local normal_unit = self.layers[active_layer]
    if (is_unit_shown(normal_unit)) then
      main_unit = normal_unit
      if (is_unit_drawn(normal_unit)) then
          tile_context.unit[normal_unit.id] = { size = 'normal' }
          table.insert(drawers, normal_unit)
          drawn_units = drawn_units + 1
      end
    end
  end
  if ((drawn_units == 0) and (#self.stash > 0)) then
    -- draw only 1st stashed unit
    local unit = self.stash[1]
    if (is_unit_shown(unit)) then
      main_unit = unit
      tile_context.unit[unit.id] = { size = 'normal' }
      drawn_units = drawn_units + 1
      table.insert(drawers, unit)
    end
  end

  if (objective and (drawn_units == 0)) then table.insert(drawers, objective) end


  local icon_drawer
  local hex_rectange = {x = 0, y = 0, w = hex_w, h = hex_h}
  if (main_unit) then
    local unit_flag = main_unit.definition.nation.unit_flag
      -- +/- 1 is required to narrow the clickable/hilightable area
      -- which is also needed to prevent hilighting when mouse pointer
      -- will be moved to the bottom tile
      local unit_flag_region = Region.create(
        x + 1 + hex_geometry.x_offset - unit_flag.w,
        y + 1 + hex_geometry.height - unit_flag.h,
        x - 1 + hex_geometry.x_offset,
        y - 1 + hex_geometry.height
      )
      local unit_flag_dst =  {
        x = x + hex_geometry.x_offset - unit_flag.w,
        y = y + hex_h - unit_flag.h,
        w = unit_flag.w,
        h = unit_flag.h,
      }
      icon_drawer = function()
        assert(sdl_renderer:copy(unit_flag.texture, nil, unit_flag_dst))
      end
  end


  local draw_fn = function()
    -- draw terrain
    assert(sdl_renderer:copy(image.texture, hex_rectange, dst))

    if (not landscape_only) then
      -- hilight managed units, participants, fog of war
      local u = state:get_selected_unit()
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
      if (state.participant_locations and state.participant_locations[self.id]) then
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
    if (icon_drawer) then icon_drawer() end

    -- draw grid
    if (show_grid) then
      local icon = terrain:get_icon('grid')
      assert(sdl_renderer:copy(icon.texture, grid_rectange, dst))
    end

  end

  local mouse_click = function(event)
    if (event.tile_id == self.id and event.button == 'left') then
      local mod_state = SDL.getModState()
      local simple = not (mod_state[SDL.keymod.LeftControl] or mod_state[SDL.keymod.RightControl])
      if (simple) then

        -- select unit on hext
        local unit
        local u = self:get_any_unit(state:get_active_layer())
        if (u and u.player == state:get_current_player()) then
            u:update_actions_map()
            unit = u
        end
        -- may be deselect current unit, if clicked on empty hex
        state:set_selected_unit(unit)
      else
        local actions = self:get_possible_actions()
        if (#actions > 0) then
          local action = actions[1]
          action.callback()
          -- trigger hints / mouse actions updates
          state:set_active_tile(self, self:get_possible_actions())
       end
      end
    elseif (event.button == 'right') then
      self.engine.interface:add_window('radial_menu', {tile = self, x = x, y = y})
    end
    return true
  end

  local mouse_move = function(event)
    if (event.tile_id == self.id) then
      state:set_mouse_hint('')
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

function Tile:build(efforts)
  local _, change_costs = self:is_capable("BUILD_CHANGE_COST")
  assert(change_costs)
  change_costs = tonumber(change_costs)

  self.data.build_efforts = self.data.build_efforts + efforts
  if (self.data.build_efforts >= change_costs) then
    local _, new_terrain_type_id = self:is_capable("BUILD_CHANGES_TO")
    local terrain = self.engine.gear:get("terrain")
    local new_type = assert(terrain.terrain_types[new_terrain_type_id])
    self.data.terrain_type = new_type
  end
end

function Tile:is_capable(flag_mask)
  local terrain = self.engine.gear:get("terrain")
  return terrain:is_capable(self.data.terrain_type.id, flag_mask)
end

function Tile:_get_possbile_battle_actions()
  local engine = self.engine
  local theme = engine.gear:get("theme")
  local records = engine.state:get_actual_records()
  local my_tile_battles = _.select(records, function(_, record)
    return (record.action == 'battle') and (record.context.tile == self.id)
  end)

  local list = _.map(my_tile_battles, function(idx, record)
    local i_unit = engine:get_unit(record.context.i_units[1].unit_id)
    local p_unit = engine:get_unit(record.context.p_units[1].unit_id)
    local action = {
      policy = "click",
      priority = 200 + idx,
      hint = engine:translate('ui.radial-menu.hex.battle_hist', {index = idx, i = i_unit.name, p = p_unit.name}),
      state = "available",
      images = {
        available = theme.actions.battle_history.available,
        hilight   = theme.actions.battle_history.hilight,
      },
      callback = function()
        engine.interface:add_window('battle_details_window', record)
      end
    }
    return action
  end)
  return list
end

function Tile:get_possible_actions()
  local engine = self.engine
  local state = engine.state
  local theme = engine.gear:get("theme")
  local my_unit = state:get_selected_unit()
  local tile_units = self:get_all_units(function() return true end)
  _.each(self.stash, function(_, unit) table.insert(tile_units, unit) end)
  local current_layer = state:get_active_layer()
  local current_player = state:get_current_player()

  local list = {}
  local my_units_selector = function(_, unit) return unit.player == current_player end

  -- we can't much in view-only mode
  if (state:get_landscape_only()) then return list end

  _.each(self:_get_possbile_battle_actions(), function(idx, action)
    table.insert(list, action)
  end)

  if (not my_unit) then
    -- if no unit selected, and there are units on tile
    -- the only possible action is to select other units of the current player
    -- or view information about units of the other player(s)

    _.each(_.select(tile_units, my_units_selector), function(idx, unit)
      local action = {
        policy = "click",
        priority = 10 * idx,
        hint = engine:translate('ui.radial-menu.hex.select_unit', {name = unit.name}),
        state = "available",
        images = {
          available = theme.actions.select_unit.available,
          hilight   = theme.actions.select_unit.hilight,
        },
        callback = function()
          unit:update_actions_map()
          state:set_selected_unit(unit)
        end
      }
      table.insert(list, action)
    end)

    _.each(_.reject(tile_units, my_units_selector), function(idx, unit)
      local action = {
        policy = "click",
        priority = 100 * idx,
        hint = engine:translate('ui.radial-menu.hex.unit_info', {name = unit.name}),
        state = "available",
        images = {
          available = theme.actions.information.available,
          hilight   = theme.actions.information.hilight,
        },
        callback = function()
          engine.interface:add_window('unit_info_window', unit)
        end
      }
      table.insert(list, action)
    end)

  else
    -- we have some selected unit, which belongs to the curren player
    _.each(my_unit:get_actions(self), function(idx, action)
      table.insert(list, action)
    end)
  end

  table.sort(list, function(a, b) return a.priority < b.priority end)

  return list
end

return Tile
