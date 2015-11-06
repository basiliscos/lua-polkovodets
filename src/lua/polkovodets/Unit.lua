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

local Unit = {}
Unit.__index = Unit

local inspect = require('inspect')
local SDL = require "SDL"
local Vector = require 'polkovodets.Vector'


function Unit.create(engine, data, player)
   assert(player, "unit should have player assigned")
   assert(data.id)
   assert(data.unit_definition_id)
   assert(data.x)
   assert(data.y)
   assert(data.staff)
   assert(data.state)
   local orientation = assert(data.orientation)
   assert(string.find(orientation,'right') or string.find(orientation, 'left'))


   local unit_lib = engine.unit_lib
   local definition = assert(unit_lib.units.definitions[data.unit_definition_id])
   local x,y = tonumber(data.x), tonumber(data.y)
   local tile = assert(engine.map.tiles[x + 1][y + 1])

   local possible_efficiencies = {'high', 'avg', 'low'}

   local o = {
      id         = data.id,
      engine     = engine,
      player     = player,
      tile       = tile,
      definition = definition,
      data = {
         staff        = data.staff,
         state        = data.state,
         selected     = false,
         allow_move   = true,
         efficiency   = possible_efficiencies[math.random(1, #possible_efficiencies)],
         orientation  = orientation,
         attached     = {},
         subordinated = {},
         managed_by   = data.managed_by,
      }
   }
   setmetatable(o, Unit)
   o:_update_layer()
   tile:set_unit(o, o.data.layer)
   o:_refresh_movements()
   table.insert(player.units, o)
   return o
end

function Unit:_update_layer()
   local unit_type = self.definition.unit_type.id
   local layer = self.data.state == 'flying' and 'air' or 'surface'
   self.data.layer = layer
end

function Unit:get_movement_layer()
   local unit_type = self.definition.unit_type.id
   return (unit_type == 'ut_air') and 'air' or 'surface'
end

function Unit:get_layer() return self.data.layer end

function Unit:draw(sdl_renderer, x, y, context)
   local terrain = self.engine.map.terrain
   local hex_h = terrain.hex_height
   local hex_w = terrain.hex_width
   local hex_x_offset = terrain.hex_x_offset

   local magnet_to = context.magnet_to or 'center'
   local texture = self.definition:get_icon(self.data.state)
   local format, access, w, h = texture:query()
   local scale = (context.size == 'normal') and 1.0 or 0.6
   local x_shift = (hex_w - w*scale)/2
   local y_shift = (magnet_to == 'center')
      and (hex_h - h*scale)/2
      or (magnet_to == 'top')
      and 0                         -- pin unit to top
      or (hex_h - h*scale)          -- pin unit to bottom
   local dst = {
      x = math.modf(x + x_shift),
      y = math.modf(y + y_shift),
      w = math.modf(w * scale),
      h = math.modf(h * scale),
   }
   local orientation = self.data.orientation
   assert((orientation == 'left') or (orientation == 'right'), "Unknown unit orientation: " .. orientation)
   local flip = (orientation == 'left') and SDL.rendererFlip.none or
                 (orientation == 'right') and SDL.rendererFlip.Horizontal

   if (self.data.selected) then
      local frame_icon = terrain:get_icon('frame')
      assert(sdl_renderer:copy(frame_icon, nil, {x = x, y = y, w = hex_w, h = hex_h}))
   end

   assert(sdl_renderer:copyEx({
             texture     = texture,
             source      = {x = 0 , y = 0, w = w, h = h},
             destination = dst,
             nil,                                          -- no angle
             nil,                                          -- no center
             flip        = flip,
   }))
   -- unit nation flag
   local unit_flag = self.definition.nation.unit_flag
   assert(sdl_renderer:copy(
             unit_flag.texture,
             nil,
             {
                x = x + hex_x_offset - unit_flag.w,
                y = y + hex_h - unit_flag.h,
                w = unit_flag.w,
                h = unit_flag.h,
             }
   ))
   -- unit state
   local size = self.definition.data.size
   local efficiency = self.data.efficiency
   local unit_state = self.engine.renderer.theme:get_unit_state_icon(size, efficiency)
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

-- returns list of weapon instances for the current unit as well as for all it's attached units
function Unit:_united_staff()
   local unit_list = {self}
   for idx, unit in pairs(self.data.attached) do table.insert(unit_list, unit) end

   local united_staff = {}
   for idx, unit in pairs(unit_list) do
      for idx2, weapon_instance in pairs(unit.data.staff) do
         table.insert(united_staff, weapon_instance)
      end
   end
   return united_staff
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
      if (value == 'TRUE') then
         local transport_kind = string.lower(string.gsub(transport_capability, 'TRANSPORTS_', ''))
         local prev_value = transport_for[transport_kind] or 0
         transport_for[transport_kind] = prev_value + weapon_instance:quantity()
      end
   end

   -- pass 2: put into transpots related weapons
   for idx, weapon_instance in pairs(united_staff) do
      local kind = weapon_instance.weapon.movement_type
      local transported = false
      local quantity = weapon_instance:quantity()
      if ((transport_for[kind] or 0) >= quantity) then
         transported = true
         transport_for[kind] = transport_for[kind] - quantity
      end
      if (not transported) then table.insert(list, weapon_instance) end
   end
   return list
end


function Unit:_refresh_movements()
   local result = {}
   self.data.allow_move = true
   for idx, weapon_instance in pairs(self:_marched_weapons()) do
      weapon_instance:refresh_movements()
   end
end


-- returns table (k: weapon_instance_id, v: value) of available movements for all
-- marched weapons instances
function Unit:available_movement()
   local data = {}
   local allow_move = self.data.allow_move
   for idx, weapon_instance in pairs(self:_marched_weapons()) do
      data[weapon_instance.uniq_id] = allow_move and weapon_instance.data.movement or 0
   end
   return data
end

-- returns table (k: weapon_instance_id, v: movement cost) for all marched weapon instances
function Unit:move_cost(tile)
   local weather = self.engine:current_weather()
   local cost_for = tile.data.terrain_type.move_cost
   local costs = {} -- k: weapon id, v: movement cost
   for idx, weapon_instance in pairs(self:_marched_weapons()) do
      local movement_type = weapon_instance.weapon.movement_type
      local value = cost_for[movement_type][weather]
      if (value == 'A') then value = weapon_instance.weapon.data.movement -- all movement points
      elseif (value == 'X') then value = math.maxinteger end              -- impassable
      costs[weapon_instance.uniq_id] = value
   end
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

function Unit:move_to(dst_tile)
   local costs = assert(self.data.actions_map.move[dst_tile.uniq_id])
   local src_tile = self.tile
   self.data.allow_move = not(self:_enemy_near(dst_tile)) and not(self:_enemy_near(src_tile))
   self.tile:set_unit(nil, self.data.layer)
   -- print(inspect(costs))
   for idx, weapon_instance in pairs(self:_marched_weapons()) do
      local cost = costs.data[weapon_instance.uniq_id]
      weapon_instance.data.movement = weapon_instance.data.movement - cost
   end

   -- update state
   local unit_type = self.definition.unit_type.id
   if (unit_type == 'ut_land') then
      self.data.state = 'marching'
   elseif (unit_type == 'ut_air') then
      self.data.state = 'flying'
   end
   self:_update_layer()

   dst_tile:set_unit(self, self.data.layer)
   self.tile = dst_tile
   self:_update_orientation(dst_tile, src_tile)
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
   local my_weight    = weight_for[self.definition.data.size]
   local other_weight = weight_for[other_unit.definition.data.size]
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
   dst_tile:set_unit(core_unit, layer)
   core_unit:update_actions_map()
end

function Unit:land_to(tile)
   self:move_to(tile)
   self.data.state = 'landed'
   self.data.allow_move = false
end


function Unit:_enemy_near(tile)
   local layer = self.data.layer
   for adj_tile in self.engine:get_adjastent_tiles(tile) do
      local enemy = adj_tile:get_unit(layer)
      local has_enemy = enemy and enemy.player ~= self.player
      if (has_enemy) then return true end
   end
   return false
end


function Unit:update_actions_map()
   local engine = self.engine
   local map = engine.map
   -- determine, what the current user can do at the visible area
   local actions_map = {}

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
      for idx, wi in pairs(marched_weapons) do initial_costs[wi.uniq_id] = 0 end
      add_reachability_tile(self.tile, self.tile, Vector.create(initial_costs))


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

         local can_move = not (other_unit and other_unit.player ~= self.player)
         if (can_move) then
            -- print(string.format("%s -> %s : %d", src_tile.uniq_id, dst_tile.uniq_id, cost))
            fuel_at[dst_tile.uniq_id] = costs
            local has_enemy_near = self:_enemy_near(dst_tile)
            for adj_tile in engine:get_adjastent_tiles(dst_tile, fuel_at) do
               local adj_cost = self:move_cost(adj_tile)
               local total_costs = costs + adj_cost
               -- ignore near enemy, if we are moving from the start tile
               if (dst_tile == self.tile) then has_enemy_near = false end
               if (total_costs <= fuel_limit and not has_enemy_near) then
                  add_reachability_tile(dst_tile, adj_tile, total_costs)
               end
            end
         end
      end
      -- do not move on the tile, where unit is already located
      fuel_at[self.tile.uniq_id] = nil
      return fuel_at
   end

   local get_attack_map = function()
      local attack_map = {}
      local visited_tiles = {} -- cache
      local start_tile = self.tile

      local max_range = -1
      local weapon_capabilites = {} -- k1: layer, value: table with k2:range, and value: list of weapons
      local united_staff = self:_united_staff()
      for idx, weapon_instance in pairs(united_staff) do
         for layer, range in pairs(weapon_instance.weapon.data.range) do
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
      -- print("wc: " .. inspect(weapon_capabilites))
      -- print("wc: " .. inspect(weapon_capabilites.surface[1]))

      local examine_queue = { start_tile }
      while (#examine_queue > 0) do
         local tile = table.remove(examine_queue, 1)
         local distance = start_tile:distance_to(tile)
         visited_tiles[tile.uniq_id] = true

         local enemy_units = tile:get_all_units(function(unit) return unit.player ~= self.player end)
         for idx, enemy_unit in pairs(enemy_units) do
            local enemy_layer = enemy_unit:get_layer()
            local weapon_instances = weapon_capabilites[enemy_layer][distance+1]
            if (weapon_instances) then
               attack_map[tile.uniq_id] = { layer = enemy_layer, weapon_instances = weapon_instances }
            end
         end
         for adj_tile in engine:get_adjastent_tiles(tile, visited_tiles) do
            local distance = start_tile:distance_to(adj_tile)
            if (distance <= max_range) then
               table.insert(examine_queue, adj_tile)
            end
         end
      end

      return attack_map
   end

   local get_merge_map = function()
      local merge_map = {}
      local my_size = self.definition.data.size
      local my_attached = self.data.attached
      local my_unit_type = self.definition.unit_type.id
      for k, tile in pairs(merge_candidates) do
         local other_unit = tile:get_unit(layer)
         if (other_unit.definition.unit_type.id == my_unit_type) then
            local expected_quantity = 1 + 1 + #my_attached + #other_unit.data.attached
            local other_size = other_unit.definition.data.size
            local size_matches = my_size ~= other_size
            local any_manager = self:is_capable('MANAGE_LEVEL') or other_unit:is_capable('MANAGE_LEVEL')
            if (expected_quantity <= 3 and size_matches and not any_manager) then
               merge_map[tile.uniq_id] = true
               -- print("m " .. tile.uniq_id .. ":" .. my_size .. other_size)
            end
         end
      end
      return merge_map
   end

   local get_landing_map = function()
      local map = {}
      for idx, tile in pairs(landing_candidates) do
         if (tile ~= self.tile) then
            map[tile.uniq_id] = true
         end
      end
      return map
   end

   actions_map.move    = get_move_map()
   actions_map.merge   = get_merge_map()
   actions_map.landing = get_landing_map()
   actions_map.attack  = get_attack_map()

   self.data.actions_map = actions_map
   -- print(inspect(actions_map.attack))
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
            if (unit.definition.size == subject.definition.data.size) then
               total_subjects = total_subjects + 1
            end
         end
         assert(total_subjects < tonumber(unit_sizes_limit),
                "not able to subordinate " .. subject.id .. ": already have " .. total_subjects
                 .. "of size " .. subject.definition.data.size
         )
      end
      -- all OK, can subordinate
      table.insert(self.data.subordinated, subject)
      print("unit " .. subject.id .. " managed by " .. self.id)
   else -- subordinate command unit (manager)
      subject_manage_level = tonumber(subject_manage_level)
      assert(subject_manage_level < manage_level)

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
                "not able to subordinate " .. subject.id .. ": already have " .. total_subjects
                   .. " manager units of level " .. subject_manage_level
         )
      end

      -- all, OK, can subordinate
      table.insert(self.data.subordinated, subject)
      print("manager unit " .. subject.id .. " managed by " .. self.id)
   end
end

return Unit
