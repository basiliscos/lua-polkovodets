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

local inspect = require('inspect')
local _ = require ("moses")
local Popup = require ('polkovodets.gui.Popup')

local BattleSelectorPopup = {}
BattleSelectorPopup.__index = BattleSelectorPopup
setmetatable(BattleSelectorPopup, Popup)

function BattleSelectorPopup.create(engine, data)

  local close_cb = function(popup) engine.interface:remove_window(popup) end
  local initial_position = assert(data.position)
  local battles = assert(data.history_records)

  local definitions = _.map(battles, function(idx, history_record)
    -- show names of main units only
    local i_unit = engine:get_unit(history_record.context.i_units[1].unit_id)
    local p_unit = engine:get_unit(history_record.context.p_units[1].unit_id)
    return {
      label = engine:translate('ui.popup.battle_selector.battle', {i = i_unit.name, p = p_unit.name}),
      callback = function(self)
        engine.interface:remove_window(self)
        engine.interface:add_window('battle_details_window', history_record)
      end
    }
  end)

  local o = Popup.create(
    engine,
    close_cb,
    definitions,
    initial_position
  )

  -- actually we don't need that
  setmetatable(o, BattleSelectorPopup)
  return o
end

return BattleSelectorPopup
