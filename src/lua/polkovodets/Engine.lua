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

local BattleFormula = require 'polkovodets.BattleFormula'
local BattleScheme = require 'polkovodets.BattleScheme'
local History = require 'polkovodets.History'
local Map = require 'polkovodets.Map'
local Nation = require 'polkovodets.Nation'
local Reactor = require 'polkovodets.utils.Reactor'
local Objective = require 'polkovodets.Objective'
local Player = require 'polkovodets.Player'
local Scenario = require 'polkovodets.Scenario'
local State = require 'polkovodets.State'
local Terrain = require 'polkovodets.Terrain'
local Theme = require 'polkovodets.Theme'
local Tile = require 'polkovodets.Tile'
local Weapon = require 'polkovodets.Weapon'
local WeaponClass = require 'polkovodets.WeaponClass'
local WeaponType = require 'polkovodets.WeaponType'
local UnitDefinition = require 'polkovodets.UnitDefinition'
local Validator = require 'polkovodets.Validator'


function Engine.create(gear, language)

  local lang = language or 'ru'
  local messages = require('polkovodets.i18n.' .. lang)
  i18n.load(messages)
  i18n.setLocale(lang)

  local reactor = Reactor.create({
    'turn.end', 'turn.start',
    'unit.selected', 'unit.change-spotting',
    'current-player.change',
    'mouse-hint.change', 'map.active_tile.change',
    'mouse-position.change',
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
  _fill_initial_data(gear)
  return e
end

function _fill_initial_data(gear)

  -- helper list to map function
  local to_map = function(map, list)
    _.each(list, function(_, object)
      local id = assert(object.id)
      assert(not map[id], "Oops! Object with id '" .. id .. "' already exists in the map")
      map[id] = object
    end)
  end

  gear:set("data/theme", {
    name          = 'default',
    active_hex    = {
      outline_color = 0x0,
      outline_width = 2,
      color         = 0xFFFFFF,
      font_size     = 15,
      font          = 'DroidSansMono.ttf'
    },
  })

  gear:declare("weapons/definitions::map", {
    dependencies = {"weapons/definitions"},
    constructor  = function() return {} end,
    initializer  = function(gear, instance, list) to_map(instance, list) end,
  })

  gear:declare("nations::map", {
    dependencies = {"nations"},
    constructor  = function() return {} end,
    initializer  = function(gear, instance, nations) to_map(instance, nations) end,
  })

  gear:declare("data/weapons/target_types::map", {
    dependencies = {"data/weapons/target_types"},
    constructor  = function() return {} end,
    initializer  = function(gear, instance, target_types) to_map(instance, target_types) end
  })

  gear:declare("data/weapons/movement_types::map", {
    dependencies = {"data/weapons/movement_types"},
    constructor  = function() return {} end,
    initializer  = function(gear, instance, list) to_map(instance, list) end,
  })

  gear:declare("weapons/classes::map", {
    dependencies = {"weapons/classes"},
    constructor  = function() return {} end,
    initializer  = function(gear, instance, list) to_map(instance, list) end,
  })

  gear:declare("data/weapons/categories::map", {
    dependencies = {"data/weapons/categories"},
    constructor  = function() return {} end,
    initializer  = function(gear, instance, list) to_map(instance, list) end,
  })

  gear:declare("weapons/types::map", {
    dependencies = {"weapons/types"},
    constructor  = function() return {} end,
    initializer  = function(gear, instance, list) to_map(instance, list) end,
  })

  gear:declare("data/units/types::map", {
    dependencies = {"data/units/types"},
    constructor  = function() return {} end,
    initializer  = function(gear, instance, list) to_map(instance, list) end,
  })

  gear:declare("data/units/classes::map", {
    dependencies = {"data/units/classes"},
    constructor  = function() return {} end,
    initializer  = function(gear, instance, list) to_map(instance, list) end,
  })

  gear:declare("theme", {
    dependencies = {"data/theme", "renderer", "data/dirs"},
    constructor  = function() return Theme.create() end,
    initializer  = function(gear, instance, ...) instance:initialize(...) end,
  })

  gear:declare("units/definitions::map", {
    dependencies = {"units/definitions"},
    constructor  = function() return {} end,
    initializer  = function(gear, instance, list) to_map(instance, list) end,
  })

  gear:declare("nation/player::map", {
    dependencies = {"players", "nations::map"},
    constructor  = function() return {} end,
    initializer  = function(gear, instance, players, nation_for)
      for _, player in pairs(players) do
        for _, nation in pairs(player.nations) do
          instance[nation.id] = player
        end
      end
    end,
  })

  -- k: player_id, v: list of units
  gear:declare("player/units::map", {
    dependencies = {"players", "units"},
    constructor  = function() return {} end,
    initializer  = function(gear, instance, players, units)
      for _, unit in pairs(units) do
        local list = instance[unit.player.id] or {}
        table.insert(list, unit)
        instance[unit.player.id] = list
      end
    end,
  })

  gear:declare("hex_geometry", {
    dependencies = {"data/hex_geometry"},
    constructor  = function() return {} end,
    initializer  = function(gear, instance, data)
      instance.width = data.width
      instance.height = data.height
      instance.x_offset = data.x_offset
      instance.y_offset = data.y_offset
    end,
  })

  gear:declare("terrain", {
    dependencies = {"hex_geometry", "data/terrain", "data/dirs", "renderer"},
    constructor  = function() return Terrain.create() end,
    initializer  = function(gear, instance, hex_geometry, terrain_data, dirs_data, renderer)
      instance:initialize(renderer, hex_geometry, terrain_data, dirs_data)
    end,
  })

  gear:declare("map", {
    dependencies = {"data/map", "engine", "renderer", "hex_geometry", "terrain", "data/map" },
    constructor  = function() return Map.create() end,
    initializer  = function(gear, instance, map_data, engine, renderer, hex_geometry, terrain, map_data)
      instance:initialize(engine, renderer, hex_geometry, terrain, map_data)
    end,
  })

  gear:declare("nations", {
    dependencies = {"data/nations", "data/dirs", "renderer"},
    constructor  = function() return {} end,
    initializer  = function(gear, instance, data_nations, data_dirs, renderer)
      for _, nation_data in pairs(data_nations) do
        local n = Nation.create()
        n:initialize(renderer, nation_data, data_dirs)
        table.insert(instance, n)
      end
    end,
  })

  gear:declare("objectives", {
    dependencies = {"data/objectives", "nations::map", "map", "renderer", "hex_geometry"},
    constructor  = function() return {} end,
    initializer  = function(gear, instance, list, ... )
      for _, data in pairs(list) do
        local o = Objective.create(self)
        o:initialize(data, ... )
        table.insert(instance, o)
      end
    end,
  })

  gear:declare("players", {
    dependencies = {"data/players", "nations::map"},
    constructor  = function() return {} end,
    initializer  = function(gear, instance, data_players, nation_for)
      for _, player_data in pairs(data_players) do
        local p = Player.create()
        p:initialize(nation_for, player_data)
        table.insert(instance, p)
      end
    end
  })

  gear:declare("weapons/definitions", {
    dependencies = {"data/weapons/definitions", "weapons/classes::map", "weapons/types::map",
      "data/weapons/categories::map", "data/weapons/movement_types::map", "data/weapons/target_types::map",
      "nations::map", "data/dirs", "renderer"
    },
    constructor  = function() return {} end,
    initializer  = function(gear, instance, list, classes_for, types_for, category_for, movement_type_for, target_type_for, nation_for, data_dirs, renderer)
      for _, weapon_data in ipairs(list) do
        local w = Weapon.create()
        w:initialize(renderer, weapon_data, classes_for, types_for, category_for, movement_type_for, target_type_for, nation_for, data_dirs)
        table.insert(instance, w)
      end
    end,
  })

  gear:declare("weapons/classes", {
    dependencies = {"data/weapons/classes", "data/dirs", "renderer"},
    constructor  = function() return {} end,
    initializer  = function(gear, instance, list, data_dirs, renderer)
      _.each(list, function(_, weapon_class_data)
        local wc = WeaponClass.create()
        wc:initialize(renderer, weapon_class_data, data_dirs)
        table.insert(instance, wc)
      end)
    end,
  })

  gear:declare("weapons/types", {
    dependencies = {"data/weapons/types", "weapons/classes::map"},
    constructor  = function() return {} end,
    initializer  = function(gear, instance, list, class_for)
      _.each(list, function(_, weapon_type_data)
        local wt = WeaponType.create()
        wt:initialize(weapon_type_data, class_for)
        table.insert(instance, wt)
      end)
    end,
  })

  gear:declare("units/definitions", {
    dependencies = {"data/units/definitions", "data/units/classes::map", "data/units/types::map",
      "nations::map", "weapons/types::map", "data/dirs", "renderer"
    },
    constructor  = function() return {} end,
    initializer  = function(gear, instance, list, classes_for, types_for, nations_for, weapon_types_for, data_dirs, renderer)
      for _, definition_data in ipairs(list) do
        local ud = UnitDefinition.create()
        ud:initialize(renderer, definition_data, classes_for, types_for, nations_for, weapon_types_for, data_dirs)
        table.insert(instance, ud)
      end
    end,
  })

  -- battle scheme & formula
  gear:declare("battle_formula", {
    dependencies = {"engine"},
    constructor  = function() return BattleFormula.create() end,
    initializer  = function(gear, instance, engine) instance:initialize(engine) end,
  })

  gear:declare("battle_scheme", {
    dependencies = {"data/battle_blocks", "battle_formula"},
    constructor  = function() return BattleScheme.create() end,
    initializer  = function(gear, instance, battle_blocks, battle_formula) instance:initialize(battle_formula, battle_blocks) end
  })

  -- scenario
  gear:declare("scenario", {
    dependencies = {"data/scenario", "objectives", "data/armies", "engine", "renderer", "map",
      "nations::map", "weapons/definitions::map", "units/definitions::map", "nation/player::map"
    },
    constructor  = function() return Scenario.create() end,
    initializer  = function(gear, instance, ...)
      return instance:initialize(...)
    end,
    provides     = {"units", "units::map", "weapon_instaces::map"}
  })

  -- validators
  Validator.declare(gear)

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


function Engine:current_turn() return self.turn end
function Engine:end_turn()
  self.reactor:publish("turn.end")
  self.state:set_selected_unit(nil)
  local players = self.gear:get("players")
  local player_idx
  local current_player = self.state:get_current_player()
  if (not current_player or current_player.order == #players) then
    player_idx = 1
  else
    player_idx = current_player.order + 1
  end

  if (player_idx == 1) then
    self.turn = self.turn + 1
    print("current turn: " .. self.turn)
  end

  local player = players[player_idx]

  self.state:set_current_player(player)
  self.state:set_recent_history(true)
  self.reactor:publish("turn.start");
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
