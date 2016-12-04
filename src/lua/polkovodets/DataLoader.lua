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

local _ = require ("moses")
local inspect = require('inspect')

local Parser = require 'polkovodets.Parser'

local DataLoader = {}
DataLoader.__index = DataLoader

function DataLoader.load(gear, scenario_path)
  local data_dirs = gear:get("data/dirs")
  local engine = gear:get("engine")

  local scenario_dir = data_dirs.scenarios .. '/' .. scenario_path

  -- [[ load scenario ]]

  local scenario_file = scenario_dir .. '/scenario.json'
  local scenario_parser = Parser.create(scenario_file)
  -- print(inspect(scenario_parser))

  gear:set("data/scenario", {
    description = assert(scenario_parser:get_value("description"), scenario_file .. " dont't have asscenario description"),
    authors     = assert(scenario_parser:get_value("authors"), scenario_file .. " dont't have authors"),
    name        = assert(scenario_parser:get_value("name"), scenario_file .. " dont't have name"),
    date        = assert(scenario_parser:get_value("date"), scenario_file .. " dont't have name"),
    weather     = assert(scenario_parser:get_value("weather"), scenario_file .. " dont't have weather"),
  });

  local scenario_files = assert(scenario_parser:get_value('files'), scenario_file .. " dont't have files section")

  --[[ load nations ]]

  local nation_file = assert(scenario_files.nations, scenario_file .. " don't have nations in files section")
  local nations_path = data_dirs.definitions .. '/' .. nation_file
  local nations_data = {}
  for idx, data in pairs(Parser.create(nations_path):get_raw_data()) do
    table.insert(nations_data, {
      id             = assert(data.id, nations_path .. " don't have id for nation " .. idx),
      name           = assert(data.name, nations_path .. " don't have name for nation " .. idx),
      unit_icon_path = assert(data.unit_icon_path, nations_path .. " don't have unit_icon_path for nation " .. idx),
      icon_path      = assert(data.icon_path, nations_path .. " don't have icon_path for nation " .. idx),
    })
  end
  gear:set("data/nations", nations_data)


  --[[ load hex names ]]

  local hex_names_file = assert(scenario_files.hex_names, scenario_file .. " don't have hex_names in files section")
  local hex_names_path = scenario_dir .. '/' .. hex_names_file
  local hex_names_data = {}
  for idx, data in pairs(Parser.create(hex_names_path):get_raw_data()) do
    local x = assert(data.x, hex_names_path .. " don't have x at row " .. idx)
    local y = assert(data.y, hex_names_path .. " don't have y at row " .. idx)
    local name = assert(data.name, hex_names_path .. " don't have name at row " .. idx)
    local id = x .. ":" .. y
    hex_names_data[id] = name
  end
  gear:set("data/hex_names", hex_names_data)

  --[[ load map ]]

  local map_file = assert(scenario_files.map, scenario_file .. " don't have map in files section")
  local map_path = scenario_dir .. '/' .. map_file
  local map_parser = Parser.create(map_path)
  local map_w = assert(map_parser:get_value('width'), map_path .. " don't have width")
  local map_h = assert(map_parser:get_value('height'), map_path .. " don't have height")

  local tiles_data = assert(map_parser:get_list_value('tiles'), map_path .. " don't have tiles")
  local tile_names = assert(map_parser:get_list_value('names'), map_path .. " don't have names of tiles")

  gear:set("data/map", {
    path   = map_path,
    width  = map_w,
    height = map_h,
    tiles_data = tiles_data,
    tile_names = tile_names,
  })

  --[[ load landscape ]]

  local landscape_file = assert(map_parser:get_value("terrain_db"), map_path .. " don't have terrain_db")
  local landscape_path = data_dirs.definitions .. '/' .. landscape_file
  local landscape_parser = Parser.create(landscape_path)

  local hex_geometry = assert(landscape_parser:get_value('hex'), landscape_path .. " don't have hex field")
  assert(hex_geometry.width, landscape_path .. " hex field don't have width")
  assert(hex_geometry.height, landscape_path .. " hex field don't have height")
  assert(hex_geometry.x_offset, landscape_path .. " hex field don't have x_offset")
  assert(hex_geometry.y_offset, landscape_path .. " hex field don't have y_offset")

  gear:set("data/hex_geometry", {
    width    = tonumber(hex_geometry.width),
    height   = tonumber(hex_geometry.height),
    x_offset = tonumber(hex_geometry.x_offset),
    y_offset = tonumber(hex_geometry.y_offset),
  })

  local landscape_icon_for = assert(landscape_parser:get_value('image'), landscape_path .. " don't have image field")

  -- load weather_types data
  local weather_file = assert(landscape_parser:get_value('weather-types'), landscape_path .. " don't have weather-types")
  local weather_path = data_dirs.definitions .. '/' .. weather_file
  local weather_types = {}
  for idx, data in pairs(Parser.create(weather_path):get_raw_data()) do
    table.insert(weather_types, {
      id = assert(data.id, weather_path .. " should have id for weather " .. idx)
    })
  end
  assert(#weather_types > 0, weather_path .. " should specify at least one weather")

  -- load raw terrain_types data
  local terrain_types_file = assert(landscape_parser:get_value('terrain-types'), landscape_path .. " don't have terrain-types")
  local terrain_types_path = data_dirs.definitions .. '/' .. terrain_types_file
  local terrain_types = {}
  for idx, data in pairs(Parser.create(terrain_types_path):get_raw_data()) do
    assert(data.min_entr, terrain_types_path .. " should have min_entr for terrain " .. idx)
    assert(data.max_entr, terrain_types_path .. " should have max_entr for terrain " .. idx)

    assert(data.image, terrain_types_path .. " should have image for terrain " .. idx)
    assert(type(data.image) == 'table', terrain_types_path .. " image must be a table for terrain " .. idx)

    assert(data.spot_cost, terrain_types_path .. " should have spot_cost for terrain " .. idx)
    assert(type(data.spot_cost) == 'table', terrain_types_path .. " spot_cost must be a table for terrain " .. idx)

    assert(data.move_cost, terrain_types_path .. " should have move_cost for terrain " .. idx)
    assert(type(data.move_cost) == 'table', terrain_types_path .. " move_cost must be a table for terrain " .. idx)

    local flags = data.flags or {}
    assert(type(flags) == 'table', terrain_types_path .. " flags must be a table for terrain " .. idx)

    table.insert(terrain_types, {
      id        = assert(data.id, terrain_types_path .. " should have id for terrain " .. idx),
      min_entr  = tonumber(data.min_entr),
      max_entr  = tonumber(data.max_entr),
      image     = data.image,
      flags     = flags,
      spot_cost = data.spot_cost,
      move_cost = data.move_cost,
    })
  end
  assert(#weather_types > 0, weather_path .. " should specify at least one weather")

  gear:set("data/terrain", {
    icons         = {
      fog         = assert(landscape_icon_for.fog, landscape_path .. " /image don't have fog image"),
      frame       = assert(landscape_icon_for.frame, landscape_path .. " /image don't have frame image"),
      participant = assert(landscape_icon_for.participant, landscape_path .. " /image don't have participant image"),
      grid        = assert(landscape_icon_for.grid, landscape_path .. " /image don't have grid image"),
      managed     = assert(landscape_icon_for.managed, landscape_path .. " /image don't have managed image"),
    },
    weather_types = weather_types,
    terrain_types = terrain_types,
  })

  --[[ load objectives ]]

  local objectives_file = assert(scenario_files.objectives, scenario_file .. " don't have objectives in files section")
  local objectives_path = scenario_dir .. '/' .. objectives_file
  local objectives = {}
  for idx, data in pairs(Parser.create(objectives_path):get_raw_data()) do
    assert(data.x, objectives_path .. " should have x for objective " .. idx)
    assert(data.y, objectives_path .. " should have y for objective " .. idx)
    table.insert(objectives, {
      x      = tonumber(data.x),
      y      = tonumber(data.y),
      nation = assert(data.nation, objectives_path .. " should have nation for objective " .. idx),
    })
  end
  gear:set("data/objectives", objectives)

  --[[ load players ]]

  local players_file = assert(scenario_files.players, scenario_file .. " don't have players in files section")
  local players_path = scenario_dir .. '/' .. players_file
  local players = {}
  for idx, data in pairs(Parser.create(players_path):get_raw_data()) do
    local nations = assert(data.nations, players_path .. " should have nations for player " .. idx)
    -- wrap single nation into list
    if (type(nations) ~= 'table') then nations = { nations } end
    table.insert(players, {
      order   = idx,
      id      = assert(data.id, players_path .. " should have id for player " .. idx),
      nations = nations,
    })
  end
  gear:set("data/players", players)

  --[[ load armed forces ]]
  -- there is no actual data, just a filenames for other data
  local armed_forces_file = assert(scenario_files.armed_forces, scenario_file .. " don't have armed_forces in files section")
  local armed_forces_path = data_dirs.definitions .. '/' .. armed_forces_file
  local armed_forces_parser = Parser.create(armed_forces_path)
  local weapons_section = assert(armed_forces_parser:get_value("weapons"), armed_forces_path .. " don't have weapons section"  )
  local units_section = assert(armed_forces_parser:get_value("units"), armed_forces_path .. " don't have units section"  )

  --[[ load battle scheme ]]

  local battle_scheme_file = assert(armed_forces_parser:get_value('battle_scheme', armed_forces_file .. " don't have battle_scheme"))
  local battle_scheme_path = data_dirs.definitions .. '/' .. battle_scheme_file
  local battle_scheme_parser = Parser.create(battle_scheme_path)
  local battle_scheme_blocks = {}
  for idx, data in pairs(battle_scheme_parser:get_raw_data()) do
    table.insert(battle_scheme_blocks, {
      block_id           = assert(data.block_id, battle_scheme_path .. " should have block_id for block " .. idx),
      command            = data.command,                -- optional / non-defined for all blocks
      condition          = data.condition,              -- optional / non-defined for all blocks
      active_weapon      = data.active_weapon,          -- optional / non-defined for all blocks
      active_multiplier  = data.active_multiplier,      -- optional / non-defined for all blocks
      passive_weapon     = data.passive_weapon,         -- optional / non-defined for all blocks
      passive_multiplier = data.passive_multiplier,     -- optional / non-defined for all blocks
      action             = data.action,                 -- optional / non-defined for all blocks
    })
  end
  gear:set("data/battle_blocks", battle_scheme_blocks)

  --[[ load transitions scheme ]]

  local transitions_scheme_file = assert(armed_forces_parser:get_value('transition-scheme', armed_forces_file .. " don't have transition-scheme"))
  local transitions_scheme_path = data_dirs.definitions .. '/' .. transitions_scheme_file
  local transitions_scheme_parser = Parser.create(transitions_scheme_path)
  local transitions_scheme_blocks = {}
  for idx, data in pairs(transitions_scheme_parser:get_raw_data()) do
    table.insert(transitions_scheme_blocks, {
      action  = assert(data.action, transitions_scheme_path .. " should have 'action' for rule " .. idx),
      from    = assert(data.from, transitions_scheme_path .. " should have 'from' for rule " .. idx),
      cost    = assert(data.cost, transitions_scheme_path .. " should have 'cost' for rule " .. idx),
    })
  end
  gear:set("data/transition_rules", transitions_scheme_blocks)


  --[[ load weapons / target types ]]

  local weapons_target_types_file = assert(weapons_section.target_types, armed_forces_file .. " don't have target_types in weapons section")
  local weapons_target_types_path = data_dirs.definitions .. '/' .. weapons_target_types_file
  local weapons_target_types_parser = Parser.create(weapons_target_types_path)
  local weapons_target_types = {}
  for idx, data in pairs(weapons_target_types_parser:get_raw_data()) do
    table.insert(weapons_target_types, {
      id = assert(data.id, weapons_target_types_path .. " should have id in target type " .. idx)
    })
  end
  gear:set("data/weapons/target_types", weapons_target_types)

  --[[ load weapons / classes ]]

  local weapons_classes_file = assert(weapons_section.classes, armed_forces_file .. " don't have classes in weapons section")
  local weapons_classes_path = data_dirs.definitions .. '/' .. weapons_classes_file
  local weapons_classes_parser = Parser.create(weapons_classes_path)
  local weapons_classes = {}
  for idx, data in pairs(weapons_classes_parser:get_raw_data()) do
    table.insert(weapons_classes, {
      id    = assert(data.id, weapons_classes_path .. " should have id in class " .. idx),
      icon  = assert(data.icon, weapons_classes_path .. " should have icon in class " .. idx),
      flags = data.flags or {},
    })
  end
  gear:set("data/weapons/classes", weapons_classes)

  --[[ load weapons / movement types ]]

  local weapons_movement_types_file = assert(weapons_section.movement_types, armed_forces_file .. " don't have movement_types in weapons section")
  local weapons_movement_types_path = data_dirs.definitions .. '/' .. weapons_movement_types_file
  local weapons_movement_types_parser = Parser.create(weapons_movement_types_path)
  local weapons_movement_types = {}
  for idx, data in pairs(weapons_movement_types_parser:get_raw_data()) do
    table.insert(weapons_movement_types, {
      id    = assert(data.id, weapons_movement_types_path .. " should have id in movement type " .. idx),
      flags = data.flags or {},
    })
  end
  gear:set("data/weapons/movement_types", weapons_movement_types)

  --[[ load weapons / categories ]]

  local weapons_categories_file = assert(weapons_section.categories, armed_forces_file .. " don't have categories in weapons section")
  local weapons_categories_path = data_dirs.definitions .. '/' .. weapons_categories_file
  local weapons_categories_parser = Parser.create(weapons_categories_path)
  local weapons_categories = {}
  for idx, data in pairs(weapons_categories_parser:get_raw_data()) do
    table.insert(weapons_categories, {
      id    = assert(data.id, weapons_categories_path .. " should have id in category " .. idx),
      flags = data.flags or {},
    })
  end
  gear:set("data/weapons/categories", weapons_categories)

  --[[ load weapons / types ]]

  local weapons_types_file = assert(weapons_section.types, armed_forces_file .. " don't have types in weapons section")
  local weapons_types_path = data_dirs.definitions .. '/' .. weapons_types_file
  local weapons_types_parser = Parser.create(weapons_types_path)
  local weapons_types = {}
  for idx, data in pairs(weapons_types_parser:get_raw_data()) do
    table.insert(weapons_types, {
      id       = assert(data.id, weapons_types_path .. " should have id in type " .. idx),
      class_id = assert(data.class_id, weapons_types_path .. " should have class_id in type " .. idx),
      flags    = data.flags or {},
    })
  end
  gear:set("data/weapons/types", weapons_types)

  --[[ load weapons / definitions ]]

  local weapons_definitions_file = assert(weapons_section.list, armed_forces_file .. " don't have list in weapons section")
  local weapons_definitions_path = data_dirs.definitions .. '/' .. weapons_definitions_file
  local weapons_definitions_parser = Parser.create(weapons_definitions_path)
  local weapons_definitions = {}
  for idx, data in pairs(weapons_definitions_parser:get_raw_data()) do
    assert(data.movement, weapons_definitions_path .. " should have movement in definition " .. idx)

    assert(data.range, weapons_definitions_path .. " should have range in definition " .. idx)
    assert(type(data.range) == 'table', weapons_definitions_path .. " range should be a table in definition " .. idx )

    assert(data.attack, weapons_definitions_path .. " should have attack in definition " .. idx)
    assert(type(data.attack) == 'table', weapons_definitions_path .. " attack should be a table in definition " .. idx )

    assert(data.defence, weapons_definitions_path .. " should have defence in definition " .. idx)
    assert(type(data.defence) == 'table', weapons_definitions_path .. " defence should be a table in definition " .. idx )

    table.insert(weapons_definitions, {
      id            = assert(data.id, weapons_definitions_path .. " should have id in definition " .. idx),
      name          = assert(data.name, weapons_definitions_path .. " should have name in definition " .. idx),
      nation        = assert(data.nation, weapons_definitions_path .. " should have nation in definition " .. idx),
      movement      = tonumber(data.movement),
      move_type     = assert(data.move_type, weapons_definitions_path .. " should have move_type in definition " .. idx),
      weap_category = assert(data.weap_category, weapons_definitions_path .. " should have weap_category in definition " .. idx),
      target_type   = assert(data.target_type, weapons_definitions_path .. " should have target_type in definition " .. idx),
      weap_type     = assert(data.weap_type, weapons_definitions_path .. " should have weap_type in definition " .. idx),
      weap_class    = assert(data.weap_class, weapons_definitions_path .. " should have weap_class in definition " .. idx),
      range         = data.range,
      attack        = data.attack,
      defence       = data.defence,
      flags         = data.flags or {},
    })
  end
  gear:set("data/weapons/definitions", weapons_definitions)

  --[[ load units / types ]]

  local units_types_file = assert(units_section.types, armed_forces_file .. " don't have types in units_section section")
  local units_types_path = data_dirs.definitions .. '/' .. units_types_file
  local units_types_parser = Parser.create(units_types_path)
  local units_types = {}
  for idx, data in pairs(units_types_parser:get_raw_data()) do
    table.insert(units_types, {
      id = assert(data.id, units_types_path .. " should have id in unit type " .. idx),
    })
  end
  gear:set("data/units/types", units_types)

  --[[ load units / classes ]]

  local units_classes_file = assert(units_section.classes, armed_forces_file .. " don't have classes in units_section section")
  local units_classes_path = data_dirs.definitions .. '/' .. units_classes_file
  local units_classes_parser = Parser.create(units_classes_path)
  local units_classes = {}
  for idx, data in pairs(units_classes_parser:get_raw_data()) do
    table.insert(units_classes, {
      id       = assert(data.id, units_classes_path .. " should have id in unit class " .. idx),
      ["type"] = assert(data.type, units_classes_path .. " should have type in unit class " .. idx),
    })
  end
  gear:set("data/units/classes", units_classes)

  --[[ load units / definitions ]]

  local units_definitions_file = assert(units_section.definitions, armed_forces_file .. " don't have definitions in units_section section")
  local units_definitions_path = data_dirs.definitions .. '/' .. units_definitions_file
  local units_definitions_parser = Parser.create(units_definitions_path)
  local units_definitions = {}
  for idx, data in pairs(units_definitions_parser:get_raw_data()) do

    assert(data.icons, units_definitions_path .. " should have icons in definition " .. idx)
    assert(type(data.icons) == 'table', units_definitions_path .. " icons should be a table in definition " .. idx )

    assert(data.staff, units_definitions_path .. " should have staff in definition " .. idx)
    assert(type(data.staff) == 'table', units_definitions_path .. " staff should be a table in definition " .. idx )

    -- print(inspect(data))
    table.insert(units_definitions, {
      id         = assert(data.id, units_definitions_path .. " should have id in unit definition " .. idx),
      name       = assert(data.name, units_definitions_path .. " should have name in unit definition " .. idx),
      nation     = assert(data.nation, units_definitions_path .. " should have nation in unit definition " .. idx),
      unit_class = assert(data.unit_class, units_definitions_path .. " should have unit_class in unit definition " .. idx),
      size       = assert(data.size, units_definitions_path .. " should have size in unit definition " .. idx),
      spotting   = assert(data.spotting, units_definitions_path .. " should have spotting in unit definition " .. idx),
      icons      = data.icons,
      staff      = data.staff,
      flags      = data.flags or {},
    })
  end
  gear:set("data/units/definitions", units_definitions)

  --[[ load army ]]

  local units_file = assert(scenario_files.army, scenario_file .. " don't have army in units_section section")
  local units_path = scenario_dir .. '/' .. units_file
  local units_parser = Parser.create(units_path)
  local units = {}
  for idx, data in pairs(units_parser:get_raw_data()) do

    assert(data.staff, units_path .. " should have staff in unit " .. idx)
    assert(type(data.staff) == 'table', units_path .. " staff should be a table in unit " .. idx )

    table.insert(units, {
      id                 = assert(data.id, units_path .. " should have id in unit " .. idx),
      name               = assert(data.name, units_path .. " should have name in unit " .. idx),
      x                  = assert(data.x, units_path .. " should have x in unit " .. idx),
      y                  = assert(data.y, units_path .. " should have y in unit " .. idx),
      unit_definition_id = assert(data.unit_definition_id, units_path .. " should have unit_definition_id in unit " .. idx),
      entr               = assert(data.entr, units_path .. " should have entr in unit " .. idx),
      state              = assert(data.state, units_path .. " should have state in unit " .. idx),
      exp                = assert(data.exp, units_path .. " should have exp in unit " .. idx),
      managed_by         = data.managed_by,  -- optional
      attached_to        = data.attached_to, -- optional
      orientation        = assert(data.orientation, units_path .. " should have orientation in unit " .. idx),
      staff              = data.staff,
    })
  end
  gear:set("data/armies", units)

  -- [[ intantiate / validate some data ]]

  local validator = gear:get("validator")
  validator.fn()
end

return DataLoader

