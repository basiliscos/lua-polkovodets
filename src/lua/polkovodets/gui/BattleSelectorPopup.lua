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

local inspect = require('inspect')
local _ = require ("moses")
local Popup = require ('polkovodets.gui.Popup')

local BattleSelectorPopup = {}
BattleSelectorPopup.__index = BattleSelectorPopup
setmetatable(BattleSelectorPopup, Popup)

function BattleSelectorPopup.create(engine, data)
  local o = Popup.create(engine, function(popup)
    engine.interface:remove_window(popup)
  end)
  o.history_records = assert(data.history_records)
  o.initial_position = assert(data.position)
  setmetatable(o, BattleSelectorPopup)
  return o
end

function BattleSelectorPopup:bind_ctx(context)
  local engine = self.engine
  local battles = self.history_records
  local definitions = _.map(battles, function(idx, history_record)
    -- show names of main units only
    local i_unit = engine:get_unit(history_record.context.i_units[1].unit_id)
    local p_unit = engine:get_unit(history_record.context.p_units[1].unit_id)
    return {
      label = engine:translate('ui.popup.battle_selector.battle', {i = i_unit.name, p = p_unit.name}),
      callback = function()
        engine.interface:remove_window(self, true)
        engine.interface:add_window('battle_details_window', history_record)
      end
    }
  end)
  local bs_ctx = _.clone(context, true)
  bs_ctx.definitions = definitions
  bs_ctx.initial_position = self.initial_position
  Popup.bind_ctx(self, bs_ctx)
end

function BattleSelectorPopup:unbind_ctx(context)
  self.ctx_bound = false
  Popup.unbind_ctx(self, context)
end

function BattleSelectorPopup:draw()
  Popup.draw(self)
end


return BattleSelectorPopup
