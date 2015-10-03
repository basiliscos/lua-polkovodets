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


function Unit.create(engine, data, player)
   assert(player, "unit should have player assigned")
   assert(data.id)
   assert(data.nation)
   assert(data.x)
   assert(data.y)
   assert(data.str)
   assert(data.entr)
   assert(data.exp)
   assert(data.orientation)

   local definition = assert(engine.unit_lib.unit_definitions[data.id])
   local nation = assert(engine.nation_for[data.nation])
   local x,y = tonumber(data.x), tonumber(data.y)
   local tile = assert(engine.map.tiles[x + 1][y + 1])

   local fuel = data.fuel and tonumber(data.fuel) or tonumber(definition.data.fuel)
   local movement = tonumber(definition.data.movement)

   local o = {
      engine = engine,
      nation = nation,
      player = player,
      tile = tile,
      definition = definition,
      data = {
         selected     = false,
         streight     = data.str,
         entrenchment = data.entr,
         experience   = data.exp,
         fuel         = fuel,
         orientation  = data.orientation,
         movement     = movement,
      }
   }
   setmetatable(o, Unit)
   tile.unit = o
   table.insert(player.units, o)
   return o
end

function Unit:draw(sdl_renderer, x, y)
   local terrain = self.engine.map.terrain
   local hex_h = terrain.hex_height
   local hex_w = terrain.hex_width

   local texture = self.definition:get_icon()
   local format, access, w, h = texture:query()
   local dst = {
      x = x + math.modf((hex_w - w)/2),
      y = y + math.modf((hex_h - h)/2),
      w = w,
      h = h,
   }
   local orientation = self.data.orientation
   assert((orientation == 'left') or (orientation == 'right'), "Unknown unit orientation: " .. orientation)
   local flip = (orientation == 'right') and SDL.rendererFlip.none or
                 (orientation == 'left') and SDL.rendererFlip.Horizontal

   if (self.data.selected) then
      local frame_icon = terrain:get_icon('frame')
      assert(sdl_renderer:copy(frame_icon, nil, {x = x, y = y, w = hex_w, h = hex_h}))
   end

   assert(sdl_renderer:copyEx(
             texture,
             {x = 0 , y = 0, w = w, h = h}, -- src
             dst,
             nil,                           -- no angle
             nil,                           -- no center
             flip
   ))
end

function Unit:available_movement()
   local fuel = self.data.fuel
   local movement = self.data.movement
   if (self.definition.data.fuel == 0) then
      return movement
   else
      return math.min(fuel, movement)
   end
end

function Unit:move_cost(tile)
   local move_type = self.definition.data.move_type
   local weather = self.engine:current_weather()
   local cost_for = tile.data.terrain_type.move_cost
   local value = cost_for[move_type][weather]
   -- all movement cost
   if (value == 'A') then return self.definition.data.movement
   -- impassable
   elseif (value == 'X') then return math.maxinteger
   else return tonumber(value) end
end

function Unit:move_to(dst_tile)
   assert(self.data.movement > 0, "unit already has been moved")
   local cost = assert(self.data.actions_map.move[dst_tile.uniq_id])
   if (self.definition.data.fuel > 0) then
      self.data.fuel = self.data.fuel - cost
   end
   self.data.movement = 0
   self.tile.unit = nil
   dst_tile.unit = self
   self.tile = dst_tile
   self:update_actions_map()
end


function Unit:_enemy_near(tile)
   for adj_tile in self.engine:get_adjastent_tiles(tile) do
      local has_enemy = adj_tile.unit and adj_tile.unit.player ~= self.player
      if (has_enemy) then return true end
   end
   return false
end


function Unit:update_actions_map()
   local engine = self.engine
   local map = engine.map
   -- determine, what the current user can do at the visible area
   local actions_map = {}

   local inspect_queue = {}
   local add_reachability_tile = function(src_tile, dst_tile, cost)
      table.insert(inspect_queue, {to = dst_tile, from = src_tile, cost = cost})
   end

   local get_nearest_tile = function()
      local iterator = function(state, value) -- ignored
         if (#inspect_queue > 0) then
            -- find route to a hex with smallest cost
            local min_idx, min_cost = 1, inspect_queue[1].cost
            for idx = 2, #inspect_queue do
               if (inspect_queue[idx].cost < min_cost) then
                  min_idx, min_cost = idx, inspect_queue[idx].cost
               end
            end
            local node = inspect_queue[min_idx]
            local src, dst = node.from, node.to
            table.remove(inspect_queue, min_idx)
            -- remove more costly destionations
            for idx, n in ipairs(inspect_queue) do
               if (n.to == dst) then table.remove(inspect_queue, idx) end
            end
            return src, dst, min_cost
         end
      end
      return iterator, nil, true
   end

   -- initialize reachability with tile, on which the unit is already located
   add_reachability_tile(self.tile, self.tile, 0)
   local fuel_at = {};
   local attack_map = {};
   local fuel_limit = self:available_movement()
   for src_tile, dst_tile, cost in get_nearest_tile() do
      -- attack branch
      if (dst_tile.unit and dst_tile.unit.player ~= self.player) then
         -- need to check, if the current unit can really attack the target
         local target = dst_tile.unit
         attack_map[dst_tile.uniq_id] = true
      -- move branch
      else
         if ((fuel_at[dst_tile.uniq_id] or cost + 1) < cost) then
            cost = fuel_at[dst_tile.uniq_id]
         else
            -- print(string.format("%s -> %s : %d", src_tile.uniq_id, dst_tile.uniq_id, cost))
            fuel_at[dst_tile.uniq_id] = cost
         end
         for adj_tile in engine:get_adjastent_tiles(dst_tile, fuel_at) do
            local adj_cost = self:move_cost(adj_tile)
            local total_cost = cost + adj_cost
            local has_enemy_near = self:_enemy_near(dst_tile)
            -- ignore near enemy, if we are moving from the start tile
            if (dst_tile == self.tile) then has_enemy_near = false end
            if (total_cost <= fuel_limit and not has_enemy_near) then
               add_reachability_tile(dst_tile, adj_tile, total_cost)
            end
         end
      end
   end
   -- do not move on the tile, where unit is already located
   fuel_at[self.tile.uniq_id] = nil
   actions_map.move = fuel_at
   actions_map.attack = attack_map

   self.data.actions_map = actions_map
   print(inspect(actions_map))
end

return Unit
