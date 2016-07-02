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

local Unit = {}
Unit.__index = Unit

local _ = require ("moses")
local inspect = require('inspect')
local Region = require 'polkovodets.utils.Region'
local Vector = require 'polkovodets.utils.Vector'


function Unit.create()
  return setmetatable({}, Unit)
end

function Unit:initialize(engine, renderer, map, unit_data, staff, unit_definitions_for, nation_to_player)

  local id = assert(unit_data.id)
  local unit_definition_id = assert(unit_data.unit_definition_id)
  local orientation = assert(unit_data.orientation)
  assert(string.find(orientation,'right') or string.find(orientation, 'left'))

  local unit_definition = assert(unit_definitions_for[unit_definition_id], "unit definiton " .. unit_definition_id .. " not found for unit " .. id)

  assert(unit_data.x, "x-coordinate isn't defined for unit " .. id)
  assert(unit_data.y, "y-coordinate isn't defined for unit " .. id)
  local x = tonumber(unit_data.x)
  local y = tonumber(unit_data.y)
  local tile = assert(map.tiles[x][y])

  local possible_efficiencies = {'high', 'avg', 'low'}

  local staff_size = 0
  for k, v in pairs(staff) do staff_size = staff_size + 1 end
  assert(staff_size > 0, "unit " .. id .. " cannot be without weapons instances")

  local nation_id = unit_definition.nation.id
  local player = assert(nation_to_player[nation_id], "no player for nation " .. nation_id)


  local state = assert(unit_data.state)
  assert(unit_definition:get_icon(state), "state '" .. "' is not available via unit definition")
  assert(unit_data.entr)
  assert(unit_data.exp)


  self.id         = id
  self.name       = assert(unit_data.name)
  self.engine     = engine
  self.renderer   = renderer
  self.player     = player
  self.tile       = tile
  self.definition = unit_definition
  self.staff      = staff
  self.data = {
    entr         = tonumber(unit_data.entr),
    experience   = tonumber(unit_data.exp),
    state        = "to-be-defined-later",
    layer        = "to-be-defined-later",
    allow_move   = true,
    efficiency   = possible_efficiencies[math.random(1, #possible_efficiencies)],
    orientation  = orientation,
    attached     = {},
    attached_to  = nil,
    subordinated = {},
  }
  self.drawing = {
    fn          = nil,
    mouse_click = nil,
    mouse_move  = nil,
    bind_tile   = nil,
  }

  -- affects on weapon instances
  self:_update_state(state)
  self:_update_layer()
  tile:set_unit(self, self.data.layer)
  self:refresh()
  table.insert(player.units, o)
end

function Unit:_update_layer()
   local unit_type = self.definition.unit_type.id
   local air_flights = (unit_type  == 'ut_air') and (self.data.state == 'marching')
   local layer = air_flights and 'air' or 'surface'
   self.data.layer = layer
end

function Unit:_update_state(new_state)
   self.data.state = new_state
   local united_staff = self:_united_staff()
   for idx, weapon_instance in pairs(united_staff) do
      weapon_instance:update_state(new_state)
   end
end

function Unit:get_movement_layer()
   local unit_type = self.definition.unit_type.id
   return (unit_type == 'ut_air') and 'air' or 'surface'
end

function Unit:get_layer() return self.data.layer end

function Unit:bind_ctx(context)
  local SDL = require "SDL"
  local x = context.tile.virtual.x + context.screen.offset[1]
  local y = context.tile.virtual.y + context.screen.offset[2]
  local engine = self.engine
  local terrain = engine.gear:get("terrain")
  local renderer = engine.gear:get("renderer")
  local theme = engine.gear:get("theme")
  local map = engine.gear:get("map")
  local hex_geometry = engine.gear:get("hex_geometry")

  local hex_w = hex_geometry.width
  local hex_h = hex_geometry.height
  local hex_x_offset = hex_geometry.x_offset

  local magnet_to = context.unit[self.id].magnet_to or 'center'
  local size = context.unit[self.id].size

  local image = self.definition:get_icon(self.data.state)
  local scale = (size == 'normal') and 1.0 or 0.6
  local x_shift = (hex_w - image.w * scale)/2
  local y_shift = (magnet_to == 'center')
            and (hex_h - image.h*scale)/2
            or (magnet_to == 'top')
            and 0                         -- pin unit to top
            or (hex_h - image.h*scale)    -- pin unit to bottom

  local dst = {
    x = math.modf(x + x_shift),
    y = math.modf(y + y_shift),
    w = math.modf(image.w * scale),
    h = math.modf(image.h * scale),
  }
  local orientation = self.data.orientation
  assert((orientation == 'left') or (orientation == 'right'), "Unknown unit orientation: " .. orientation)
  local flip = (orientation == 'left') and SDL.rendererFlip.none or
  (orientation == 'right') and SDL.rendererFlip.Horizontal

  -- unit nation flag
  local unit_flag = self.definition.nation.unit_flag
  -- +/- 1 is required to narrow the clickable/hilightable area
  -- which is also needed to preven hilighting when mouse pointer
  -- will be moved to the bottom tile
  local unit_flag_region = Region.create(x + 1 + hex_x_offset - unit_flag.w, y + 1 + hex_h - unit_flag.h, x - 1 + hex_x_offset, y - 1 + hex_h)
  local unit_flag_dst =  {
    x = x + hex_x_offset - unit_flag.w,
    y = y + hex_h - unit_flag.h,
    w = unit_flag.w,
    h = unit_flag.h,
  }

  local mouse = context.state:get_mouse()

  -- unit state
  local size = self.definition.size
  local efficiency = self.data.efficiency
  local unit_state = theme:get_unit_state_icon(size, efficiency)

  local u = context.state:get_selected_unit()
  local active_tile = context.state:get_active_tile()

  local sdl_renderer = assert(context.renderer.sdl_renderer)

  local draw_frame
  if (u and u.id == self.id) then
    local frame = terrain:get_icon('frame')
    draw_frame = function()
      assert(sdl_renderer:copy(frame.texture, nil, {x = x, y = y, w = hex_w, h = hex_h}))
    end
  end

  self.drawing.fn = function()
    -- draw selection frame
    if (draw_frame) then draw_frame() end

    -- draw unit
    assert(sdl_renderer:copyEx({
      texture     = image.texture,
      source      = {x = 0 , y = 0, w = image.w, h = image.h},
      destination = dst,
      nil,                                          -- no angle
      nil,                                          -- no center
      flip        = flip,
    }))

    -- draw unit nation flag
    assert(sdl_renderer:copy(unit_flag.texture, nil, unit_flag_dst))

    -- draw unit state
    assert(sdl_renderer:copy(
      unit_state.texture,
      nil,
      {
        x = x + (hex_w - hex_x_offset),
        y = y + hex_h - unit_state.h,
        w = unit_state.w,
        h = unit_state.h,
      }
    ))

  end

  local update_action = function(tile_id, x, y)
    if (tile_id == self.tile.id) then
      local hint = self.name
      self.engine.state:set_mouse_hint(hint)
      return true
    end
  end

  local mouse_move = function(event)
    return update_action(event.tile_id, event.x, event.y)
  end

  local active_tile = context.state:get_active_tile()
  update_action(active_tile.id, mouse.x, mouse.y)

  self.drawing.bind_tile = self.tile
  context.events_source.add_handler('mouse_move', self.drawing.bind_tile.id, mouse_move)

  self.drawing.mouse_click = mouse_click
  self.drawing.mouse_move  = mouse_move
end

function Unit:unbind_ctx(context)
  context.events_source.remove_handler('mouse_move', self.drawing.bind_tile.id, self.drawing.mouse_move)

  self.drawing.fn = nil
  self.drawing.mouse_click = nil
  self.drawing.bind_tile = nil
end

function Unit:draw()
  self.drawing.fn()
end

-- returns list of weapon instances for the current unit as well as for all it's attached units
function Unit:_united_staff()
   local unit_list = self:all_units()

   local united_staff = {}
   for idx, unit in pairs(unit_list) do
      for idx2, weapon_instance in pairs(unit.staff) do
         table.insert(united_staff, weapon_instance)
      end
   end
   return united_staff
end

-- returns list of all units, i.e. self + attached
function Unit:all_units()
  local unit_list = {self}
  for idx, unit in pairs(self.data.attached) do table.insert(unit_list, unit) end
  return unit_list
end

-- retunrs a table of weapon instances, which are will be marched,
-- i.e. as if they already packed into transporters
-- includes attached units too.
function Unit:_marched_weapons()
   local list = {}

   local united_staff = self:_united_staff()
   -- k:  type of weapon movement, which are capable to transport, w: quantity
   local transport_for = {}

   -- pass 1: determine transport capabilites
   for idx, weapon_instance in pairs(united_staff) do
      local transport_capability, value = weapon_instance:is_capable('TRANSPORTS_%w+')
      -- print("id: " .. weapon_instance.id .. " " .. inspect(weapon_instance.weapon.flags))
      -- intepret anything as true, in future it might be possible to define
      -- weight/volume transport capabilities
      if (value) then
         local transport_kind = string.lower(string.gsub(transport_capability, 'TRANSPORTS_', ''))
         local prev_value = transport_for[transport_kind] or 0
         transport_for[transport_kind] = prev_value + weapon_instance:quantity()
      end
   end
   -- print("transport_for " .. inspect(transport_for))

   -- this is actual transport_capabilities
   local transport_capabilities = _.clone(transport_for)
   -- get the possible transport capabilities from unit definitons

   local transport_needs = {}

   -- pass 2: put into transpots related weapons
   for idx, weapon_instance in pairs(united_staff) do
      local movement_type = weapon_instance.weapon.movement_type.id
      local transported = false
      local quantity = weapon_instance:quantity()
      -- print(weapon_instance.id .. " / " .. quantity .. " kind: " .. movement_type)

      local transported_via = transport_needs[movement_type] or {}
      --[[
        need transport if:
        a. it is not capable to transport
        b. or it is transport, for which there is a transport itself
      --]]
      local needs_transport = (quantity > 0)
        and ((not weapon_instance:is_capable('TRANSPORTS_%w+'))
         or (transport_capabilities[movement_type]))
      if (needs_transport) then table.insert(transported_via, weapon_instance) end
      transport_needs[movement_type] = transported_via

      if ((quantity  > 0) and (transport_for[movement_type] or 0) >= quantity) then
        transported = true
        transport_for[movement_type] = transport_for[movement_type] - quantity
      end
      if (not transported) then table.insert(list, weapon_instance) end
   end
   assert(#list, "ooops! nobody moves?")
   -- print("marched weapons " .. inspect(_.map(list, function(idx, v) return v.id end)))
   -- print("marched weapons " .. #united_staff)
   return list, transport_capabilities, transport_needs
end

function Unit:report_problems()
  local problems = {}

  --[[ transport problem ]]
  local _, transport_capabilities, transport_needs = self:_marched_weapons()
  -- print(inspect(transport_capabilities))
  -- print(inspect(transport_needs))

  for movement_type, capability in pairs(transport_capabilities) do
    local needs_summary = 0
    local needed_quantities = {}
    local need_to_transport = transport_needs[movement_type]
    if (need_to_transport) then
      for _, wi in pairs(need_to_transport) do
        local quantity = wi:quantity()
        table.insert(needed_quantities, quantity)
        needs_summary = needs_summary + quantity
      end
    end
    if (needs_summary > capability) then
      local details = table.concat(needed_quantities, " / ")
      table.insert(problems, {
        class = "transport",
        message = self.engine:translate('problem.transport', {
          capabilities = capability,
          needed       = needs_summary,
          details      = details,
        }),
      })
    end
  end

  --[[ missing weapon ]]
  local types_for = self.engine.gear:get("weapons/types::map")
  local declared_types = {} -- k: weapon_type_id, v: boolean
  for _, unit in pairs(self:all_units()) do
    for weapon_type_id in pairs(unit.definition.staff) do
      declared_types[weapon_type_id] = false
    end
  end
  for _, wi in pairs(self:_united_staff()) do
    if (wi:quantity() > 0) then
      local weapon_type_id = wi.weapon.weapon_type.id
      declared_types[weapon_type_id] = true
    end
  end
  for weapon_type_id, presents in pairs(declared_types) do
    if (not presents) then
      local class_id = types_for[weapon_type_id].class.id
      local localized_type = self.engine:translate('db.weapon-class.' .. class_id)
      table.insert(problems, {
        class = "missing_weapon",
        message = self.engine:translate('problem.missing_weapon', { weapon_type = localized_type }),
      })
    end
  end

  return problems
end


function Unit:refresh()
   local result = {}
   self.data.allow_move = true
   for idx, weapon_instance in pairs(self:_united_staff()) do
      weapon_instance:refresh()
   end
end


-- returns table (k: weapon_instance_id, v: value) of available movements for all
-- marched weapons instances
function Unit:available_movement()
   local data = {}
   local allow_move = self.data.allow_move
   for idx, weapon_instance in pairs(self:_marched_weapons()) do
      data[weapon_instance.id] = allow_move and weapon_instance.data.movement or 0
   end
   return data
end

-- returns table (k: weapon_instance_id, v: movement cost) for all marched weapon instances
function Unit:move_cost(tile)
   local weather = self.engine:current_weather()
   local cost_for = tile.data.terrain_type.move_cost
   local costs = {} -- k: weapon id, v: movement cost
   for idx, weapon_instance in pairs(self:_marched_weapons()) do
      local movement_type = weapon_instance.weapon.movement_type.id
      -- print("cost for " .. movement_type)
      local weather_costs = assert(cost_for[movement_type], "no costs for movement type "  .. movement_type)
      local value = cost_for[movement_type][weather]
      if (value == 'A') then value = weapon_instance.weapon.movement      -- all movement points
      elseif (value == 'X') then value = math.maxinteger end              -- impassable

      if (value == 0) then value = math.maxinteger end
      -- assert(value > 0, "movement costs for weapon instance " .. weapon_instance.id .. " cannot be zero, when moving to tile " .. tile.id)
      costs[weapon_instance.id] = value
   end
   -- print("move to " .. tile.id .. " costs: " .. inspect(costs))
   return Vector.create(costs)
end

function Unit:_update_orientation(dst_tile, src_tile)
   local dx = dst_tile.data.x - src_tile.data.x
   local orientation = self.data.orientation
   if (dx > 0) then orientation = 'right'
   elseif (dx <0) then orientation = 'left' end

   -- print("orientation: " .. self.data.orientation .. " -> " .. orientation)
   self.data.orientation = orientation
end

function Unit:_check_death()
  local alive_weapons = 0
  for k, weapon_instance in pairs(self.staff) do
    alive_weapons = alive_weapons + weapon_instance.data.quantity
  end
  if (alive_weapons == 0) then
    self.data.state = 'dead'
    print(self.id .. " is dead " .. alive_weapons)
    if (self.tile) then
      self.tile:set_unit(nil, self.data.layer)
      self.tile = nil
      if (self.engine.state:get_selected_unit() == self) then
          self.engine.state:set_selected_unit(nil)
      end
      self.engine.reactor:publish("map.update")
    end
  end
end

function Unit:_detach()
  if (self.data.attached_to) then
    local parent = self.data.attached_to
    local idx
    for i, u in ipairs(parent.data.attached) do
      if (u == self) then
        idx = i
        break
      end
    end
    assert(idx)
    table.remove(parent.data.attached, idx)
    self.data.attached_to = nil
    self.tile = parent.tile
    return true
  end
end

function Unit:move_to(dst_tile)
  -- print("moving " .. self.id .. " to " .. dst_tile.id)
  -- print("move map = " .. inspect(self.data.actions_map.move))
  local map = self.engine.gear:get("map")
  local costs = assert(self.data.actions_map.move[dst_tile.id],
    "unit " .. self.id  .. " cannot move to ".. dst_tile.id)
  local being_attached = self:_detach()
  local src_tile = self.tile

  -- calculate back route from dst_tile to src_tile
  -- print(inspect(self.data.actions_map.move))
  local route = { dst_tile }
  local marched_weapons = self:_marched_weapons()
  local move_costs = self.data.actions_map.move
  local initial_costs = {}
  for idx, wi in pairs(marched_weapons) do initial_costs[wi.id] = 0 end
  move_costs[src_tile.id] = Vector.create(initial_costs)

  local get_prev_tile = function()
    local current_tile = dst_tile
    local iterator = function(state, value)
      if (current_tile ~= src_tile) then
        local min_tile = nil
        local min_cost = math.huge
        for adj_tile in map:get_adjastent_tiles(current_tile) do
          local costs = move_costs[adj_tile.id]
          -- print("costs = " .. inspect(costs))
          if (costs and costs:min() < min_cost) then
            min_tile = adj_tile
            min_cost = costs:min()
          end
        end
        assert(min_tile)
        current_tile = min_tile
        -- print("current_tile " .. min_tile.id .. ", min cost: " .. min_cost)
        return (min_tile ~= src_tile) and min_tile or nil
      end
    end
    return iterator, nil, true
  end

  for tile in get_prev_tile() do
    table.insert(route, 1, tile)
  end
  -- print("routing via " .. inspect(_.map(route, function(k, v) return v.id end)))

  local prev_tile = src_tile
  for idx, tile in pairs(route) do
    -- print(self.id .. " moves on " .. tile.id .. " from " .. prev_tile.id)
    -- TODO: check for ambush and mines
    local ctx = {
      unit_id  = self.id,
      dst_tile = tile.id,
      src_tile = prev_tile.id,
    }
    self.engine.history:record_player_action('unit/move', ctx, true, {})
    prev_tile = tile
  end
  dst_tile = prev_tile
  -- print("history = " .. inspect(self.engine.history.records_at))

  self.data.allow_move = not(self:_enemy_near(dst_tile)) and not(self:_enemy_near(src_tile))
  if (not being_attached) then src_tile:set_unit(nil, self.data.layer) end
  -- print(inspect(costs))
  for idx, weapon_instance in pairs(marched_weapons) do
    local cost = costs.data[weapon_instance.id]
    weapon_instance.data.movement = weapon_instance.data.movement - cost
  end

  -- update state

  local unit_type = self.definition.unit_type.id
  local new_state
  if (unit_type == 'ut_land') then
    new_state = self:_enemy_near(dst_tile) and 'defending' or 'marching'
  elseif (unit_type == 'ut_air') then
    new_state = 'marching'
  end
  self:_update_state(new_state)
  self:_update_layer()

  dst_tile:set_unit(self, self.data.layer)
  self.tile = dst_tile
  self:_update_orientation(dst_tile, src_tile)
  self:update_spotting_map()
  self:update_actions_map()
end

function Unit:merge_at(dst_tile)
   local layer = self.data.layer
   local other_unit = assert(dst_tile:get_unit(layer))
   self:move_to(dst_tile)

   local weight_for = {
      L = 100,
      M = 10,
      S = 1,
   }
   local my_weight    = weight_for[self.definition.size]
   local other_weight = weight_for[other_unit.definition.size]
   local core_unit, aux_unit
   if (my_weight > other_weight) then
      core_unit, aux_unit = self, other_unit
   else
      core_unit, aux_unit = other_unit, self
   end

   for idx, unit in pairs(aux_unit.data.attached) do
      table.remove(aux_unit.data.attached)
      table.insert(core_unit.data.attached, unit)
   end
   table.insert(core_unit.data.attached, aux_unit)

   -- aux unit is now attached, remove from map
   aux_unit.tile:set_unit(nil, layer)
   aux_unit.tile = nil
   aux_unit.data.attached_to = core_unit
   dst_tile:set_unit(core_unit, layer)

   self.engine.state:set_selected_unit(core_unit)
   core_unit:update_actions_map()
end

function Unit:land_to(tile)
   self:move_to(tile)
   self:_update_state('landed')
   self:_update_layer()
   self.data.allow_move = false
   self:update_actions_map()
end

function Unit:attack_on(tile, fire_type)
  self:_check_death()
  local enemy_unit = tile:get_any_unit(self.engine.state:get_active_layer())
  local battle_scheme = self.engine.gear:get("battle_scheme")
  assert(enemy_unit)
  self:_update_orientation(enemy_unit.tile, self.tile)
  local i_casualities, p_casualities, i_participants, p_participants
    = battle_scheme:perform_battle(self, enemy_unit, fire_type)

  local unit_serializer = function(key, unit)
    return {
      unit_id = unit.id,
      state   = unit.data.state,
    }
  end

  local ctx = {
    i_units   = _.map(self:all_units(), unit_serializer),
    p_units   = _.map(enemy_unit:all_units(), unit_serializer),
    fire_type = fire_type,
    tile      = tile.id,
  }
  local results = {
    i = { casualities = i_casualities, participants = i_participants },
    p = { casualities = p_casualities, participants = p_participants },
  }
  self.engine.history:record_player_action('battle', ctx, true, results)
  print("batte results = " .. inspect(results))

  self:_check_death()
  enemy_unit:_check_death()
  if (self.data.state ~= 'dead') then
    self:update_spotting_map()
    self:update_actions_map()
  end
end

function Unit:special_action(tile, action)
  assert(self.data.actions_map.special[tile.id])
  assert(self.data.actions_map.special[tile.id][action])

  if (action == 'build') then
    local builde_weapon_instances = self.data.actions_map.special[tile.id][action]
    local efforts = 0
    for _, wi in pairs(builde_weapon_instances) do
      local capability, power = wi:is_capable("BUILD_CAPABILITIES")
      efforts = efforts + power * wi:quantity()
      wi.data.can_attack = false
    end
    tile:build(efforts)
  else
    assert("unknown action: " .. action)
  end
  self:update_spotting_map()
  self:update_actions_map()
end


function Unit:_enemy_near(tile)
  local layer = self:get_movement_layer()
  local map = self.engine.gear:get("map")
  for adj_tile in map:get_adjastent_tiles(tile) do
    local enemy = adj_tile:get_unit(layer)
    local has_enemy = enemy and enemy.player ~= self.player
    if (has_enemy) then return true end
  end
  return false
end

function Unit:update_spotting_map()
  local engine = self.engine
  local map = engine.gear:get("map")
  local terrain = engine.gear:get("terrain")
  local weather = self.engine:current_weather()

  local spotting_map = {}

  local unit = _.reduce(self:all_units(), function(u, other)
    if (not other) then
      return u
    else
      return (u.definition.spotting > other.definition.spotting) and u or other
    end
  end)
  -- it doesn't matter from which unit we get it's type, because units of
  -- different types cannot merge
  local unit_type = self.definition.unit_type.id
  local available_spotting = unit.definition.spotting

  -- print("available_spotting = " .. available_spotting)

  local queue =  {}

  local get_nearest_tile = function()
    return function()
      if (#queue > 0) then
        local max_idx, max_value = 1, queue[1][2]
        for idx, candidate in pairs(queue) do
          if (queue[idx][2] > max_value) then
             max_idx, max_value = idx, queue[idx][2]
          end
        end
        local maximum = table.remove(queue, max_idx)
        -- print("q = " .. inspect(queue))
        return table.unpack(maximum)
      end
    end
  end

  local add_to_queue = function(tile, cost) table.insert(queue, {tile, cost}) end
  add_to_queue( self.tile, available_spotting + 1)

  for tile, remained_spot_cost in get_nearest_tile() do
    if (remained_spot_cost > 0) then
      spotting_map[tile.id] = remained_spot_cost
      for adj_tile in map:get_adjastent_tiles(tile, spotting_map) do
        -- for air units the terrain type does not matter, but weather does,
        -- so we pick the "field" (clear) terrain for air unit
        local terrain_type = (unit_type == 'ut_air') and terrain:get_type('c') or adj_tile.data.terrain_type
        local adj_tile_cost = assert(terrain_type.spot_cost[weather])
        local spot_left = remained_spot_cost - adj_tile_cost
        -- print(remained_spot_cost .. " " .. spot_left)
        add_to_queue(adj_tile, spot_left)
      end
    end
  end
  -- print("spotting map " .. inspect(spotting_map))

  self.data.spotting_map = spotting_map
  engine.reactor:publish("unit.change-spotting", self)
end


function Unit:update_actions_map()
  local engine = self.engine
  local map = engine.gear:get("map")
  -- determine, what the current user can do at the visible area
  local actions_map = {}
  local start_tile = self.tile or self.data.attached_to.tile
  assert(start_tile)


  local merge_candidates = {}
  local landing_candidates = {}

  local layer = self:get_movement_layer()
  local unit_type = self.definition.unit_type.id

  local get_move_map = function()
    local inspect_queue = {}
    local add_reachability_tile = function(src_tile, dst_tile, cost)
      table.insert(inspect_queue, {to = dst_tile, from = src_tile, cost = cost})
    end
    local marched_weapons = self:_marched_weapons()

    local get_nearest_tile = function()
      local iterator = function(state, value) -- ignored
        if (#inspect_queue > 0) then
          -- find route to a hex with smallest cost
          local min_idx, min_cost = 1, inspect_queue[1].cost:min()
          for idx = 2, #inspect_queue do
            if (inspect_queue[idx].cost:min() < min_cost) then
              min_idx, min_cost = idx, inspect_queue[idx].cost:min()
            end
          end
          local node = inspect_queue[min_idx]
          local src, dst = node.from, node.to
          table.remove(inspect_queue, min_idx)
          -- remove more costly destionations
          for idx, n in ipairs(inspect_queue) do
            if (n.to == dst) then table.remove(inspect_queue, idx) end
          end
          return src, dst, node.cost
        end
      end
      return iterator, nil, true
    end

    -- initialize reachability with tile, on which the unit is already located
    local initial_costs = {}
    for idx, wi in pairs(marched_weapons) do initial_costs[wi.id] = 0 end
    add_reachability_tile(start_tile, start_tile, Vector.create(initial_costs))


    local fuel_at = {};  -- k: tile_id, v: movement_costs table
    local fuel_limit = Vector.create(self:available_movement())
    for src_tile, dst_tile, costs in get_nearest_tile() do
      local other_unit = dst_tile:get_unit(layer)

      -- inspect for further merging
      if (other_unit and other_unit.player == self.player) then
        table.insert(merge_candidates, dst_tile)
      end
      -- inspect for further landing
      if (unit_type == 'ut_air' and dst_tile.data.terrain_type.id == 'a') then
        table.insert(landing_candidates, dst_tile)
      end

      local can_move = not (other_unit and other_unit.player ~= self.player and other_unit:get_layer() == layer)
      if (can_move) then
        -- print(string.format("%s -> %s : %d", src_tile.id, dst_tile.id, cost))
        fuel_at[dst_tile.id] = costs
        local has_enemy_near = self:_enemy_near(dst_tile)
        for adj_tile in map:get_adjastent_tiles(dst_tile, fuel_at) do
          local adj_cost = self:move_cost(adj_tile)
          local total_costs = costs + adj_cost
          -- ignore near enemy, if we are moving from the start tile
          if (dst_tile == start_tile) then has_enemy_near = false end
          if (total_costs <= fuel_limit and not has_enemy_near) then
            add_reachability_tile(dst_tile, adj_tile, total_costs)
          end
        end
      end
    end
    -- do not move on the tile, where unit is already located
    fuel_at[start_tile.id] = nil
    return fuel_at
  end

  local get_attack_map = function()
    local attack_map = {}
    local visited_tiles = {} -- cache

    local max_range = -1
    local weapon_capabilites = {} -- k1: layer, value: table with k2:range, and value: list of weapons
    local united_staff = self:_united_staff()
    for idx, weapon_instance in pairs(united_staff) do
      if (weapon_instance.data.can_attack) then
        for layer, range in pairs(weapon_instance.weapon.range) do
          --print(weapon_instance.id .. " " .. range)
          -- we use range +1 to avoid zero-based indices
          for r = 0, range do
            local layer_capabilites = weapon_capabilites[layer] or {}
            local range_capabilites = layer_capabilites[r + 1] or {}
            table.insert(range_capabilites, weapon_instance)
            -- print("rc = " .. inspect(range_capabilites))
            layer_capabilites[r + 1] = range_capabilites
            weapon_capabilites[layer] = layer_capabilites
          end

          if (max_range < range) then max_range = range end
        end
      end
    end
    -- print("wc: " .. inspect(weapon_capabilites))
    -- print("wc: " .. inspect(_.keys(weapon_capabilites.surface[1])))
    -- print("wc: " .. inspect(_.map(weapon_capabilites.surface[1], function(idx, v) return v.id end)))


    local get_fire_kinds = function(weapon_instance, distance, enemy_unit)
      local fire_kinds = {}
      local enemy_layer = enemy_unit:get_layer()
      local same_layer = (enemy_layer == layer)
      if (weapon_instance:is_capable('RANGED_FIRE') and same_layer) then
        table.insert(fire_kinds, 'fire/artillery')
      end
      if ((distance == 1) and same_layer) then
        table.insert(fire_kinds, 'battle')
      end
      if (not same_layer) then
        table.insert(fire_kinds, ((layer == 'surface')
          and 'fire/anti-air'
          or  'fire/bombing'
          )
        )
      end
      if ((distance == 0) and (enemy_layer == layer)) then
        table.insert(fire_kinds, 'battle')
      end
      return fire_kinds
    end

    local examine_queue = {}
    local already_added = {}
    local add_to_queue = function(tile)
      if (not already_added[tile.id]) then
        table.insert(examine_queue, tile)
        already_added[tile.id] = true
      end
    end

    add_to_queue(start_tile)
    while (#examine_queue > 0) do
      local tile = table.remove(examine_queue, 1)
      local distance = start_tile:distance_to(tile)
      visited_tiles[tile.id] = true

      local enemy_units = tile:get_all_units(function(unit) return unit.player ~= self.player end)
      for idx, enemy_unit in pairs(enemy_units) do
        local enemy_layer = enemy_unit:get_layer()
        local weapon_instances = (weapon_capabilites[enemy_layer] or {})[distance+1]
        if (weapon_instances) then
          local attack_details = attack_map[tile.id] or {}
          local layer_attack_details = attack_details[enemy_layer] or {}
          for k, weapon_instance in pairs(weapon_instances) do
            local fire_kinds = get_fire_kinds(weapon_instance, distance, enemy_unit)
            -- print(inspect(fire_kinds))
            for k, fire_kind in pairs(fire_kinds) do
              -- print(fire_kind .. " by " .. weapon_instance.id)
              local fired_weapons = layer_attack_details[fire_kind] or {}
              table.insert(fired_weapons, weapon_instance.id)
              table.sort(fired_weapons)
              layer_attack_details[fire_kind] = fired_weapons
            end
          end
          attack_details[enemy_layer] = layer_attack_details
          attack_map[tile.id] = attack_details
        end
      end

      for adj_tile in map:get_adjastent_tiles(tile, visited_tiles) do
        local distance = start_tile:distance_to(adj_tile)
        if (distance <= max_range) then
          add_to_queue(adj_tile)
        end
      end
    end

    return attack_map
  end

  local get_merge_map = function()
    local merge_map = {}
    local my_size = self.definition.size
    local my_attached = self.data.attached
    local my_unit_type = self.definition.unit_type.id
    for k, tile in pairs(merge_candidates) do
      local other_unit = tile:get_unit(layer)
      if (other_unit.definition.unit_type.id == my_unit_type) then
        local expected_quantity = 1 + 1 + #my_attached + #other_unit.data.attached
        local other_size = other_unit.definition.size
        local size_matches = my_size ~= other_size
        local any_manager = self:is_capable('MANAGE_LEVEL') or other_unit:is_capable('MANAGE_LEVEL')
        if (expected_quantity <= 3 and size_matches and not any_manager) then
          merge_map[tile.id] = true
        -- print("m " .. tile.id .. ":" .. my_size .. other_size)
        end
      end
    end
    return merge_map
  end

  local get_landing_map = function()
    local map = {}
    for idx, tile in pairs(landing_candidates) do
      if (tile ~= start_tile) then
        map[tile.id] = true
      end
    end
    return map
  end

  local get_special_map = function()
    local map = {}
    for _, weapon_instance in pairs(self:_united_staff()) do

      -- build capability disabled, when unit is attached
      local can_build = weapon_instance:is_capable("BUILD_CAPABILITIES")
        and weapon_instance:quantity() > 0
        and weapon_instance.data.can_attack
        and self:get_layer() == 'surface'
        and self.tile
        and self.tile:is_capable("BUILD_")
      if (can_build) then
        local specials = map[self.tile.id] or {}
        local builders = specials.build or {}
        table.insert(builders, weapon_instance)
        specials.build = builders
        map[self.tile.id] = specials
      end
    end
    return map
  end

  actions_map.move    = get_move_map()
  actions_map.merge   = get_merge_map()
  actions_map.landing = get_landing_map()
  actions_map.attack  = get_attack_map()
  actions_map.special = get_special_map()

  self.data.actions_map = actions_map
  self.engine.reactor:publish("map.update");

  -- print(inspect(actions_map.move))
end

function Unit:is_capable(flag_mask)
  return self.definition:is_capable(flag_mask)
end

function Unit:get_subordinated(recursively)
   local r = {}
   local get_subordinated
   get_subordinated = function(u)
      for idx, s_unit in pairs(u.data.subordinated) do
         table.insert(r, s_unit)
         if (recursively) then get_subordinated(s_unit) end
      end
   end
   get_subordinated(self)
   return r
end


function Unit:subordinate(subject)
   local k, manage_level = self:is_capable('MANAGE_LEVEL')
   assert(manage_level, "unit " .. self.id .. " isn't capable to manage")
   manage_level = tonumber(manage_level)
   local k, subject_manage_level = subject:is_capable('MANAGE_LEVEL')

   if (not subject_manage_level) then -- subordinate usual (non-command) unit
      local k, units_limit = self:is_capable('MANAGED_UNITS_LIMIT')
      local k, unit_sizes_limit = self:is_capable('MANAGED_UNIT_SIZES_LIMIT')
      if (units_limit ~= 'unlimited') then
         local total_subjects = #self.data.subordinated
         assert(total_subjects < tonumber(units_limit),
                "not able to subordinate " .. subject.id .. ": already have " .. total_subjects)
      end
      if (unit_sizes_limit ~= 'unlimited') then
         local total_subjects = 0
         for k, unit in pairs(self.data.subordinated) do
            if (unit.definition.size == subject.definition.size) then
               total_subjects = total_subjects + 1
            end
         end
         assert(total_subjects < tonumber(unit_sizes_limit),
                "not able to subordinate " .. subject.id .. ": already have " .. total_subjects
                 .. " of size " .. subject.definition.size
         )
      end
      -- all OK, can subordinate
      table.insert(self.data.subordinated, subject)
      -- print("unit " .. subject.id .. " managed by " .. self.id)
   else -- subordinate command unit (manager)
      subject_manage_level = tonumber(subject_manage_level)
      assert(subject_manage_level > manage_level, "unit " .. subject.id .. " (level " .. subject_manage_level .. ") "
        .. "cannot be subordinated to unit " .. self.id .. " (level " .. manage_level .. ")")

      local k, managed_managers_level_limit = self:is_capable('MANAGED_MANAGERS_LEVEL_LIMIT')

      if (managed_managers_level_limit ~= 'unlimited') then
         local total_subjects = 0
         managed_managers_level_limit = tonumber(managed_managers_level_limit)
         for k, unit in pairs(self.data.subordinated) do
            local k, unit_manage_level = subject:is_capable('MANAGE_LEVEL')
            if (unit_manage_level) then
               unit_manage_level = tonumber(unit_manage_level)
               if (unit_manage_level == subject_manage_level) then
                  total_subjects = total_subjects + 1
               end
            end
         end
         assert(total_subjects < managed_managers_level_limit,
                "not able to subordinate '" .. subject.id .. "' to '" .. self.id ..  "', which already has "
                  .. total_subjects .. " manager units of level " .. subject_manage_level
         )
      end

      -- all, OK, can subordinate
      table.insert(self.data.subordinated, subject)
      -- print("manager unit " .. subject.id .. " managed by " .. self.id)
   end
end

function Unit:get_attack_kinds(tile)
   local kinds

   local attack_layers = self.data.actions_map.attack[tile.id]
   local same_layer = self:get_layer()
   local opposite_layer = (same_layer == 'surface') and 'air' or 'surface'
   local attack_layer = attack_layers[same_layer]
   if (not attack_layer) then                         -- non ambigious case
      attack_layer = attack_layers[opposite_layer]
      if (attack_layer['fire/bombing']) then kind = {'fire/bombing'}
      elseif (attack_layer['fire/anti-air']) then kind = {'fire/anti-air'}
      else
         error("possible attack kinds for different layers are: 'fire/bombing' or 'fire/anti-air'")
      end
   else                                               -- ambigious case
      local selected_attack, attack_score = nil, 0
      kinds = {}
      if (attack_layer['battle']) then table.insert(kinds, 'battle') end
      if (attack_layer['fire/artillery']) then
        local position = (self.definition.unit_class.id == 'art') and 1 or #kinds + 1
        table.insert(kinds, position, 'fire/artillery')
      end
   end
   return kinds
end

function Unit:get_actions(tile)
  local list = {}
  local engine = self.engine
  local theme = engine.gear:get("theme")

  if (self.tile == tile) then
    -- unit info
    table.insert(list, {
      priority = 10,
      policy = "click",
      hint = engine:translate('ui.radial-menu.hex.unit_info', {name = self.name}),
      state = "available",
      images = {
        available = theme.actions.information.available,
        hilight   = theme.actions.information.hilight,
      },
      callback = function()
        engine.interface:add_window('unit_info_window', self)
      end
    })


    -- change orientation, it if there is a any weapon without NON_ORIENTED_ONLY flag
    local orientable_weapons = _.select(self.staff, function(_, wi) return not wi.weapon:is_capable("NON_ORIENTED_ONLY") end)
    if (#orientable_weapons > 0) then
      table.insert(list, {
        priority = 10,
        policy = "click",
        hint = engine:translate('ui.radial-menu.hex.unit_rotate'),
        state = "available",
        images = {
          available = theme.actions.change_orientation.available,
          hilight   = theme.actions.change_orientation.hilight,
        },
        callback = function()
          self:change_orientation()
        end
      })
    end

    -- take (oriented) defence, if there is at least one orientable weapon
    if (#orientable_weapons > 0) then
      table.insert(list, {
        priority = 11,
        policy = "click",
        hint = engine:translate('ui.radial-menu.hex.unit_defence'),
        state = "available",
        images = {
          available = theme.actions.defence.available,
          hilight   = theme.actions.defence.hilight,
        },
        callback = function()
          print("[TODO] defence")
        end
      })
    end

    -- circular defence can be taken, if we have at least one weapon, without ORIENTED_ONLY flag
    local non_orientable_weapons = _.select(self.staff, function(_, wi) return not wi.weapon:is_capable("ORIENTED_ONLY") end)
    if (#non_orientable_weapons > 0) then
      table.insert(list, {
        priority = 12,
        policy = "click",
        hint = engine:translate('ui.radial-menu.hex.unit_cir_defence'),
        state = "available",
        images = {
          available = theme.actions.circular_defence.available,
          hilight   = theme.actions.circular_defence.hilight,
        },
        callback = function()
          print("[TODO] circular defence")
        end
      })
    end

    -- detach attached units
    _.each(self.data.attached, function(idx, unit)
      table.insert(list, {
        priority = 20 + idx,
        policy = "click",
        hint = engine:translate('ui.radial-menu.hex.unit_detach', {name = unit.name}),
        state = "available",
        images = {
          available = theme.actions.detach.available,
          hilight   = theme.actions.detach.hilight,
        },
        callback = function()
          unit:update_actions_map()
          state:set_selected_unit(unit)
        end
      })
    end)

  end

  -- unit action: move to the tile. We cannot move unit here if there are other units on the same
  -- layer, but something additional might be done, e.g. merge
  local tile_units = tile:get_all_units(function() return true end)
  local other_units = _.select(tile_units, function(idx, unit)
    return unit.data.layer == self.data.layer
  end)
  local can_move_to_tile = self.data.actions_map.move[tile.id] and (#other_units == 0)
  if (can_move_to_tile) then
    table.insert(list, {
      priority = 20,
      policy = "click",
      hint = engine:translate('ui.radial-menu.hex.unit_move', {x = tile.data.x, y = tile.data.y}),
      state = "available",
      images = {
        available = theme.actions.move.available,
        hilight   = theme.actions.move.hilight,
      },
      callback = function()
        self:move_to(tile)
      end
    })
  end

  -- march
  if (can_move_to_tile and self.definition.state_icons.retreating) then
    table.insert(list, {
      priority = 20,
      policy = "click",
      hint = engine:translate('ui.radial-menu.hex.unit_retreat', {x = tile.data.x, y = tile.data.y}),
      state = "available",
      images = {
        available = theme.actions.retreat.available,
        hilight   = theme.actions.retreat.hilight,
      },
      callback = function()
        print("[TODO] retreat")
      end
    })
  end

  -- unit action: patrol
  if (can_move_to_tile and self.definition.state_icons.patrol) then
    table.insert(list, {
      priority = 21,
      policy = "click",
      hint = engine:translate('ui.radial-menu.hex.unit_patrol', {x = tile.data.x, y = tile.data.y}),
      state = "available",
      images = {
        available = theme.actions.patrol.available,
        hilight   = theme.actions.patrol.hilight,
      },
      callback = function()
        print("[TODO] patrol")
      end
    })
  end

  -- unit action: raid
  if (can_move_to_tile and self.definition.state_icons.raid) then
    table.insert(list, {
      priority = 22,
      policy = "click",
      hint = engine:translate('ui.radial-menu.hex.unit_raid', {x = tile.data.x, y = tile.data.y}),
      state = "available",
      images = {
        available = theme.actions.raid.available,
        hilight   = theme.actions.raid.hilight,
      },
      callback = function()
        print("[TODO] raid")
      end
    })
  end

  -- unit action: merge
  if (self.data.actions_map.merge[tile.id]) then
    table.insert(list, {
      priority = 30,
      policy = "click",
      hint = engine:translate('ui.radial-menu.hex.unit_merge'),
      state = "available",
      images = {
        available = theme.actions.merge.available,
        hilight   = theme.actions.merge.hilight,
      },
      callback = function()
        self:merge_at(tile)
      end
    })
  end

  -- unit action: battle
  if (self.data.actions_map.attack[tile.id]) then
    table.insert(list, {
      priority = 40,
      policy = "click",
      hint = engine:translate('ui.radial-menu.hex.unit_battle'),
      state = "available",
      images = {
        available = theme.actions.battle.available,
        hilight   = theme.actions.battle.hilight,
      },
      callback = function()
        self:attack_on(tile, "battle")
      end
    })
  end

  -- unit special action: construction
  local special_actions = self.data.actions_map.special[tile.id]
  if (special_actions and special_actions.build) then
    table.insert(list, {
      priority = 35,
      policy = "click",
      hint = engine:translate('ui.radial-menu.hex.unit_construct'),
      state = "available",
      images = {
        available = theme.actions.construction.available,
        hilight   = theme.actions.construction.hilight,
      },
      callback = function()
        self:special_action(tile, 'build')
      end
    })
  end

  -- refuel action: for land units on the self tile, for  air units in aiprots,
  -- for naval units in haven
  local can_refuel
    =  (self.definition.unit_type.id == 'ut_land' and self.tile == tile)
    or (self.definition.unit_type.id == 'ut_air' and self.data.actions_map.landing[tile.id])
  if (can_refuel) then
    table.insert(list, {
      priority = 37,
      policy = "click",
      hint = engine:translate('ui.radial-menu.hex.unit_refuel'),
      state = "available",
      images = {
        available = theme.actions.refuel.available,
        hilight   = theme.actions.refuel.hilight,
      },
      callback = function()
        print("[TODO] refuel")
      end
    })
  end

  return list
end

function Unit:change_orientation()
  local o = (self.data.orientation == 'left') and 'right' or 'left'
  self.data.orientation = o
  self.engine.reactor:publish("map.update")
end

return Unit
