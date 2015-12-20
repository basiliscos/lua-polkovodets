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

local _ = require ("moses")
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
    drawing = {
      fn          = nil,
      mouse_move  = nil,
      mouse_click = nil,
    }
  }
  return setmetatable(o, _Record)
end

function _Record:bind_ctx(context)
  local hex_w = context.tile_geometry.w
  local hex_h = context.tile_geometry.h
  local hex_x_offset = context.tile_geometry.x_offset
  local hex_y_offset = context.tile_geometry.y_offset

  local sdl_renderer = assert(context.renderer.sdl_renderer)
  local draw_fn
  local mouse_move, mouse_click


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
    local tile_id = self.context.tile
    local tile = context.map:lookup_tile(tile_id)

    local battle_icon = context.theme.history.battle
    local icon_x = tile.virtual.x + context.screen.offset[1] + hex_x_offset - battle_icon.w
    local icon_y = tile.virtual.y + context.screen.offset[2]
    local is_over_icon = function(x, y)
      return ((x >= icon_x) and (x <= icon_x + battle_icon.w)
          and (y >= icon_y) and (y <= icon_y + battle_icon.h))
    end
    local over_icon = false

    local actual_records = context.renderer.engine.history:get_actual_records()
    local battles_count = _.countf(actual_records, function(k, v)
      return (v.action == 'battle') and (v.context.tile == tile_id)
    end)

    local update_participants = function(x, y, over_tile_id)
      local updated
      if (over_tile_id == tile_id) then
        local now_over_battle_icon = is_over_icon(x, y)
        local participant_locations = context.state.participant_locations or {}
        if (now_over_battle_icon ~= over_icon) then
          participant_locations = {}
          over_icon = now_over_battle_icon
          if (over_icon) then
            local battles_on_tile = _.select(context.renderer.engine.history:get_actual_records(),
              function(k, v)
                return (v.action == 'battle') and (v.context.tile == tile_id)
              end)
            local participants = {}
            _.each(battles_on_tile, function(k, v)
              _.each(v.context.i_units, function(i, unit_data) participants[unit_data.unit_id] = true end)
              _.each(v.context.p_units, function(i, unit_data) participants[unit_data.unit_id] = true end)
            end)
            _.each(_.keys(participants), function(k, v)
              local unit = context.renderer.engine:get_unit(v)
              if (unit.tile) then
                participant_locations[unit.tile.id] = unit.id
              end
            end)
            -- print("participants tile " .. inspect(participant_locations))
          end
          updated = true
          local tile = context.map:lookup_tile(tile_id)
          context.state.mouse_hint = context.renderer.engine:translate(
            'map.battle-on-tile', {count = battles_count, tile = tile.data.x .. ":" .. tile.data.y}
          )
          context.state.participant_locations = participant_locations
        end
      end
      return updated
    end

    update_participants(context.mouse.x, context.mouse.y, context.state.active_tile.id)

    local icon = over_icon and context.theme.history.battle_hilight or context.theme.history.battle

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
        context.renderer.engine.mediator:publish({ "view.update" })
      end
      return is_over_icon(event.x, event.y)
    end

    mouse_click = function(event)
      if (is_over_icon(event.x, event.y)) then
        context.renderer.engine.state.history_record = self
        context.renderer.engine.state.popups.battle_details_window = true
        context.renderer.engine.mediator:publish({ "view.update" })
        return true
      end
    end

  end

  if (mouse_move) then
    context.events_source.add_handler('mouse_move', mouse_move)
    self.drawing.mouse_move = mouse_move
  end
  if (mouse_click) then
    context.events_source.add_handler('mouse_click', mouse_click)
    self.drawing.mouse_click = mouse_click
  end

  self.drawing.fn = draw_fn
end


function _Record:draw()
  self.drawing.fn()
end

function _Record:unbind_ctx(context)
  self.drawing.fn = nil
  if (self.drawing.mouse_move) then
    -- reset hilighting participants battle, as we leave the tile
    -- and, hence, the battle icon
    context.state.participant_locations = {}
    context.events_source.remove_handler('mouse_move', self.drawing.mouse_move)
    self.drawing.mouse_move = nil
    self.drawing.mouse_click = nil
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
  self.engine.mediator:publish({ "model.update" });
end

function History:get_actual_records()
  local engine = self.engine
  local actual_turns = {} -- k: player.id, v: last turn
  local turn_no = self.engine:current_turn()
  local current_player = engine.current_player

  for i, p in pairs(engine.player_for) do
    local turn = (p.data.order <= current_player.data.order)
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
