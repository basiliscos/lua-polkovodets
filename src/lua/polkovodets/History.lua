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


local History = {}
History.__index = History

local _ = require ("moses")
local inspect = require('inspect')
local Region = require 'polkovodets.utils.Region'

local _Record = {}
_Record.__index = _Record

function _Record.create(engine, player, turn_no, action, context, success, results)
  local o = {
    engine  = engine,
    player  = player,
    turn_no = turn_no,
    action  = action,
    context = context,
    success = success,
    results = results,
    drawing = {
      tile_id     = nil,
      fn          = nil,
      mouse_move  = nil,
      mouse_click = nil,
    }
  }
  return setmetatable(o, _Record)
end

function _Record:bind_ctx(context)
  local engine = self.engine
  local state = engine.state
  local theme = engine.gear:get("theme")
  local hex_geometry = engine.gear:get("hex_geometry")
  local sdl_renderer = engine.gear:get("renderer").sdl_renderer
  local map = engine.gear:get("map")

  local hex_w = hex_geometry.width
  local hex_h = hex_geometry.height
  local hex_x_offset = hex_geometry.x_offset
  local hex_y_offset = hex_geometry.y_offset

  local draw_fn
  local mouse_move, mouse_click

  local tile_id

  if (self.action == 'unit/move') then
    local src_tile = map:lookup_tile(self.context.src_tile)
    local dst_tile = map:lookup_tile(self.context.dst_tile)
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
      local arrow = theme.history.move
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

      draw_fn = function()
        assert(sdl_renderer:copyEx({
          texture     = arrow.texture,
          source      = nil,
          destination = dst,
          angle       = angle,
        }))
        -- print("movement has been drawn")
      end
    end
  elseif (self.action == 'battle') then
    tile_id = self.context.tile
    local tile = map:lookup_tile(tile_id)

    local battle_icon = theme.history.battle
    local icon_x = tile.virtual.x + context.screen.offset[1] + hex_x_offset - battle_icon.w
    local icon_y = tile.virtual.y + context.screen.offset[2]
    local icon_region = Region.create(icon_x, icon_y, icon_x + battle_icon.w, icon_y + battle_icon.h)
    local over_icon = false

    local actual_records = self.engine.history:get_actual_records()
    local battles_count = _.countf(actual_records, function(k, v)
      return (v.action == 'battle') and (v.context.tile == tile_id)
    end)

    local battles_on_tile

    local update_participants = function(x, y, over_tile_id)
      local updated
      if (over_tile_id == tile_id) then
        local now_over_battle_icon = icon_region:is_over(x, y)
        local participant_locations = state.participant_locations or {}
        if (now_over_battle_icon ~= over_icon) then
          participant_locations = {}
          over_icon = now_over_battle_icon
          if (over_icon) then
            battles_on_tile = _.select(engine.history:get_actual_records(),
              function(k, v)
                return (v.action == 'battle') and (v.context.tile == tile_id)
              end)
            local participants = {}
            _.each(battles_on_tile, function(k, v)
              _.each(v.context.i_units, function(i, unit_data) participants[unit_data.unit_id] = true end)
              _.each(v.context.p_units, function(i, unit_data) participants[unit_data.unit_id] = true end)
            end)
            _.each(_.keys(participants), function(k, v)
              local unit = engine:get_unit(v)
              if (unit.tile) then
                participant_locations[unit.tile.id] = unit.id
              end
            end)
            -- print("participants tile " .. inspect(participant_locations))
          end
          updated = true
          local tile = map:lookup_tile(tile_id)
          local hint = engine:translate(
            'map.battle-on-tile', {count = battles_count, tile = tile.data.x .. ":" .. tile.data.y}
          )
          state:set_mouse_hint(hint)
          state.participant_locations = participant_locations
        end
      end
      return updated
    end

    local mouse = state:get_mouse()
    local active_tile = state:get_active_tile()
    update_participants(mouse.x, mouse.y, active_tile.id)

    local icon = over_icon and theme.history.battle_hilight or theme.history.battle

    draw_fn = function(event)
      assert(sdl_renderer:copy(
        icon.texture,
        nil,
        {
          x = icon_x,
          y = icon_y,
          w = icon.w,
          h = icon.h,
        })
      )
    end

    mouse_move = function(event)
      if (update_participants(event.x, event.y, event.tile_id)) then
        engine.reactor:publish("map.update")
      end
      return icon_region:is_over(event.x, event.y)
    end

    mouse_click = function(event)
      if (icon_region:is_over(event.x, event.y)) then
        if (#battles_on_tile == 1) then
          engine.interface:add_window('battle_details_window', self)
        else
          engine.interface:add_window('battle_selector_popup', {
            history_records = battles_on_tile,
            position        = {
              x = event.x,
              y = event.y,
            }
          })
        end
        return true
      end
    end

  end

  if (mouse_move) then
    context.events_source.add_handler('mouse_move', tile_id, mouse_move)
    self.drawing.tile_id = tile_id
    self.drawing.mouse_move = mouse_move
  end
  if (mouse_click) then
    self.drawing.tile_id = tile_id
    context.events_source.add_handler('mouse_click', tile_id, mouse_click)
    self.drawing.mouse_click = mouse_click
  end

  self.drawing.fn = draw_fn
end


function _Record:draw()
  self.drawing.fn()
end

function _Record:unbind_ctx(context)
  self.drawing.fn = nil
  local state = self.engine.state
  if (self.drawing.mouse_move) then
    -- reset hilighting participants battle, as we leave the tile
    -- and, hence, the battle icon
    state.participant_locations = {}
    context.events_source.remove_handler('mouse_move', self.drawing.tile_id, self.drawing.mouse_move)
    self.drawing.mouse_move = nil
  end
  if (self.drawing.mouse_click) then
    context.events_source.remove_handler('mouse_click', self.drawing.tile_id, self.drawing.mouse_click)
    self.drawing.mouse_click = nil
  end
  if (self.drawing.tile_id) then
    self.drawing.tile_id = nil
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
  local player = self.engine.state:get_current_player()
  local turn_no = self.engine:current_turn()
  local record = _Record.create(self.engine, player.id, turn_no, action, context, success, results)

  local turn_records = self.records_at[turn_no] or {}
  table.insert(turn_records, record)
  self.records_at[turn_no] = turn_records
  self.engine.state:set_actual_records(self:get_actual_records())
end

function History:get_actual_records()
  local engine = self.engine
  local actual_turns = {} -- k: player.id, v: last turn
  local turn_no = self.engine:current_turn()
  local current_player = engine.state:get_current_player()

  local players = engine.gear:get("players")
  for _, p in pairs(players) do
    local turn = (p.order <= current_player.order)
      and turn_no
       or turn_no -1
    actual_turns[p.id] = turn
  end

  local records = _.select(self.records_at[turn_no] or {}, function(k, v)
    return actual_turns[v.player] == turn_no
  end)
  if ((turn_no - 1) > 0) then
    records = _.append(records, _.select(self.records_at[turn_no - 1] or {}, function(k, v)
        return actual_turns[v.player.id] == turn_no - 1
      end)
    )
  end
  records = records or {}
  return records
end

return History
