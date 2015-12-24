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

function BattleSelectorPopup.create(engine)
  local o = Popup.create(engine, function()
    engine.state.popups.battle_selector_popup = nil
    engine.mediator:publish({ "view.update" })
  end)
  setmetatable(o, BattleSelectorPopup)
  o.ctx_bound = false
  return o
end

function BattleSelectorPopup:bind_ctx(context)
  local engine = self.engine
  local popup_state = engine.state.popups.battle_selector_popup
  if (popup_state) then
    self.ctx_bound = true
    local battles = assert(popup_state.history_records)
    local definitions = _.map(battles, function(idx, history_record)
      -- show names of main units only
      local i_unit = engine:get_unit(history_record.context.i_units[1].unit_id)
      local p_unit = engine:get_unit(history_record.context.p_units[1].unit_id)
      return {
        label = engine:translate('ui.popup.battle_selector.battle', {i = i_unit.name, p = p_unit.name}),
        callback = function()
          engine.state.history_record = history_record
          engine.state.popups.battle_details_window = true
          engine.state.popups.battle_selector_popup = nil
          engine.mediator:publish({ "view.update" })
        end
      }
    end)
    local bs_ctx = _.clone(context, true)
    bs_ctx.definitions = definitions
    bs_ctx.initial_position = popup_state.position
    Popup.bind_ctx(self, bs_ctx)
  end
end

function BattleSelectorPopup:unbind_ctx(context)
  if (self.ctx_bound) then
    self.ctx_bound = false
    Popup.unbind_ctx(self, context)
  end
end

function BattleSelectorPopup:draw()
  if (self.ctx_bound) then
    Popup.draw(self)
  end
end


return BattleSelectorPopup
