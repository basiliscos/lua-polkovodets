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

local _ = require ("moses")

local Engine = {}
Engine.__index = Engine

local inspect = require('inspect')
-- plural rules: http://unicode.org/repos/cldr-tmp/trunk/diff/supplemental/language_plural_rules.html
local i18n = require 'i18n'
local Tile = require 'polkovodets.Tile'
local History = require 'polkovodets.History'
local Reactor = require 'polkovodets.utils.Reactor'
local State = require 'polkovodets.State'


function Engine.create(gear, language)

  local lang = language or 'ru'
  local messages = require('polkovodets.i18n.' .. lang)
  i18n.load(messages)
  i18n.setLocale(lang)

  local reactor = Reactor.create({
    'unit.selected',
    'mouse-hint.change', 'map.active_tile.change',
    'action.change', 'mouse-position.change',
    'map.update', 'history.update',
    'ui.update',
    'full.refresh'
  })

  local e = {
    turn               = 0,
    messages           = messages,
    language           = lang,
    current_player_idx = 0,
    history_layer      = false,
    total_players      = 0,
    reactor            = reactor,
    options = {
      show_grid = true,
    },
    state          = State.create(reactor),
    gear           = gear,
  }
  setmetatable(e,Engine)
  e.history = History.create(e)

  e.reactor:subscribe("history.update", function(event, records)
    if (#records > 0) then
      e.reactor:publish("map.update")
    end
  end)
  gear:set("engine", e)
  _add_data_validators(gear)
  return e
end

function _add_data_validators(gear)
  gear:declare("validators/weapons/movement_types", {"data/weapons/movement_types", "data/terrain"},
    function() return { name = "weapon movement types"} end,
    function(gear, instance, movement_types, terrain_data)
      instance.fn = function()
        for _, movement_type in pairs(movement_types) do
          for j, terrain_type in pairs(terrain_data.terrain_types) do
            local mt_id = movement_type.id
            local tt_id = terrain_type.id
            assert(terrain_type.move_cost[mt_id],
              "no '" .. mt_id .. "' movement type costs defined on terrain type '" .. tt_id .. "'")
          end
        end
        print("weapon movement types are valid")
      end
    end
  )

  gear:declare("validators/units/classes", {"data/units/classes", "data/units/types::map"},
    function() return { name = "unit classes"} end,
    function(gear, instance, classes, type_for)
      instance.fn = function()
        for _, class in pairs(classes) do
          local t = class["type"]
          assert(type_for[t], "unknown unit type " .. t .. " for unit class " .. class.id)
        end
        print("unit classes are valid")
      end
    end
  )

  gear:declare("validator", { "validators/weapons/movement_types", "validators/units/classes" },
    function() return { } end,
    function(gear, instance, ...)
      local validators = { ... }
      instance.fn = function()
        _.each(validators, function(_, v) v.fn() end)
        print("all data seems to be valid")
      end
    end
  )

end

function Engine:translate(key, values)
  assert(key)
  local value = i18n.translate(key, values)
  return value or ('?' .. key .. '?')
end

function Engine:get_unit(id)
  local unit_for = self.gear:get("units::map")
  return assert(unit_for[id], "unit with id " .. id .. " not found")
end

function Engine:_set_current_player(order)
   local player
   local players = self.gear:get("players")
   for _, p in pairs(players) do
      if (p.order == order) then
         player = p
      end
   end
   assert(player)
   self.current_player = player
   self.current_player_idx = order
   print(string.format("current player: %s(%d)",  player.id, player.order))
end

function Engine:get_current_player()
  return self.current_player
end


function Engine:current_turn() return self.turn end
function Engine:end_turn()
  self.state:set_selected_unit(nil)
  local players = self.gear:get("players")
  if ((self.current_player_idx == #players) or self.turn == 0) then
    self.turn = self.turn + 1
    local all_units = self.gear:get("units")
    for k, unit in pairs(all_units) do
      unit:refresh()
    end
    print("current turm: " .. self.turn)
    self:_set_current_player(1)
  else
    self:_set_current_player(self.current_player_idx + 1)
  end
  self.state:set_recent_history(true)
  self.reactor:publish("full.refresh");
end

function Engine:current_weather()
  local turn = self.turn
  local scenario = self.gear:get("scenario")
  local w = assert(scenario.weather[turn], "unknown wheather on turn " .. turn)
  return w
end

function Engine:toggle_attack_priorities()
  local u = self.state:get_selected_unit()
  if (u) then
    u:switch_attack_priorities()
    self.reactor:publish("map.update");
  end
end

return Engine
