--[[

Copyright (C) 2016 Ivan Baidakou

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

local State = {}
State.__index = State

function State.create(reactor)
  local o = {
    reactor         = reactor,
    _action         = 'default',
    _active_tile    = nil,
    _mouse_hint     = nil,
    _mouse          = {x = 0, y = 0},
    _active_panels  = {},
    _actual_records = {},
    _selected_unit  = nil,
    _landscape_only = nil,
    _recent_history = nil,
    _active_layer   = 'surface',
    _current_player = nil,
  }
  return setmetatable(o, State)
end

function State:set_active_tile(tile)
  self._active_tile = tile
  self.reactor:publish('map.active_tile.change', tile)
end
function State:get_active_tile() return self._active_tile end

function State:set_mouse_hint(str)
  self._mouse_hint = str
  self.reactor:publish("mouse-hint.change", str)
end
function State:get_mouse_hint() return self._mouse_hint end

function State:set_mouse(x, y)
  self._mouse.x = x
  self._mouse.y = y
  self.reactor:publish('mouse-position.change')
end
function State:get_mouse() return self._mouse end

function State:activate_panel(panel, value)
  self._active_panels[panel] = value
  self.reactor:publish('ui.update', value)
end
function State:get_active_panels() return self._active_panels end

function State:set_actual_records(value)
  self._actual_records = value
  self.reactor:publish('history.update', value)
end
function State:get_actual_records() return self._actual_records end

function State:set_selected_unit(value)
  self._selected_unit = value
  self.reactor:publish('unit.selected', value)
end
function State:get_selected_unit() return self._selected_unit end

function State:set_landscape_only(value)
  self._landscape_only = value
  self.reactor:publish('map.update', value)
end
function State:get_landscape_only() return self._landscape_only end

function State:set_recent_history(value)
  self._recent_history = value
  self.reactor:publish('map.update', value)
end
function State:get_recent_history() return self._recent_history end

function State:set_active_layer(value)
  self._active_layer = value
  self.reactor:publish('map.update', value)
end
function State:get_active_layer() return self._active_layer end

function State:set_current_player(value)
  self._current_player = value
  print(string.format("current player: %s(%d)",  value.id, value.order))
  self.reactor:publish('current-player.change', value)
end
function State:get_current_player() return self._current_player end

return State

