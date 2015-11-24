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


local History = {}
History.__index = History

local inspect = require('inspect')

local _Record = {}
_Record.__index = _Record

function _Record.create(player, turn_no, action, context, success, results)
  local o = {
    player  = player,
    turn_no = turn_no,
    action  = action,
    context = context,
    success = success,
    results = results,
  }
  return setmetatable(o, _Record)
end

function _Record:draw(sdl_renderer, context)
  assert(sdl_renderer)
  local hex_w = context.tile_geometry.w
  local hex_h = context.tile_geometry.h
  local hex_x_offset = context.tile_geometry.x_offset
  local hex_y_offset = context.tile_geometry.y_offset

  if (self.action == 'unit/move') then
    local src_tile = context.map:lookup_tile(self.context.src_tile)
    local dst_tile = context.map:lookup_tile(self.context.dst_tile)
    local src_coord = { src_tile.virtual.x, src_tile.virtual.y }
    local dst_coord = { dst_tile.virtual.x, dst_tile.virtual.y }
    if (src_coord and dst_coord) then
      local dx = dst_coord[1] - src_coord[1]
      local dy = dst_coord[2] - src_coord[2]
      --[[
        Assuming that original arrow points to top, i.e. has (0, -1) vector,
        because coordinates origin (0,0) is top right corner of the window
      ]]
      local angle = math.acos(-dy/math.sqrt(dx^2 + dy^2))
      if (dx < 0) then angle = -1 * angle end
      angle = math.deg(angle)
      -- print("angle " .. angle)
      local arrow = context.theme.history.move
      local delta_x, delta_y = 0, 0
      if ((angle ~= 0) and (angle ~= 180)) then
        delta_x = (dx > 0) and hex_x_offset or 0
        delta_y = (dy > 0) and hex_y_offset or 0
      else
        delta_x = math.modf(hex_w/2 - arrow.w/2)
        delta_y = (dy < 0) and math.modf(-hex_y_offset/2) or math.modf(hex_h -hex_y_offset/2)
      end
      -- print("dx = " .. delta_x .. " , dy = " .. delta_y)
      local dst = {
        x = src_coord[1] + delta_x + context.screen.offset[1],
        y = src_coord[2] + delta_y + context.screen.offset[2],
        w = arrow.w,
        h = arrow.h,
      }
      assert(sdl_renderer:copyEx({
        texture     = arrow.texture,
        source      = nil,
        destination = dst,
        angle       = angle,
      }))
    end
  elseif (self.action == 'battle') then
    local tile_id = self.context.tile
    if (not context.cache.drawn_battle_tiles[tile_id]) then
      context.cache.drawn_battle_tiles[tile_id] = true

    end
  end
end


function History.create(engine)
  local o = {
    engine     = engine,
    records_at = {}, -- k: turn_no, v: array of records
  }
  return setmetatable(o, History)
end

function History:record_player_action(action, context, success, results)
  assert(type(action) == 'string')
  assert(type(success) == 'boolean')
  assert(type(results) == 'table')
  local player = self.engine:get_current_player()
  local turn_no = self.engine:current_turn()
  local record = _Record.create(player.id, turn_no, action, context, success, results)

  local turn_records = self.records_at[turn_no] or {}
  table.insert(turn_records, record)
  self.records_at[turn_no] = turn_records
end

function History:get_records(turn_no)
  return self.records_at[turn_no] or {}
end

return History
