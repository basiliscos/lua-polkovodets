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

function _Record.create(player, turn_no, action, context, success, resuls)
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

return History
