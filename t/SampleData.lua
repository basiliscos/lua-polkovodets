local _ = require ("moses")

local BattleFormula = require 'polkovodets.BattleFormula'
local BattleScheme = require 'polkovodets.BattleScheme'
local Map = require 'polkovodets.Map'
local Nation = require 'polkovodets.Nation'
local Player = require 'polkovodets.Player'
local Scenario = require 'polkovodets.Scenario'
local Terrain = require 'polkovodets.Terrain'
local Tile = require 'polkovodets.Tile'
local UnitDefinition = require 'polkovodets.UnitDefinition'
local Weapon = require 'polkovodets.Weapon'
local WeaponClass = require 'polkovodets.WeaponClass'

local DummyRenderer = require 't.DummyRenderer'


local SampleData = {}
SampleData.__index = SampleData

function SampleData.generate_test_data(gear)
  gear:set("data/dirs", {
    scenarios   = 'data/db/scenarios',
    definitions = 'data/db',
    gfx         = 'data/gfx',
    themes      = 'data/gfx/themes/'
  })
  gear:declare("renderer",
    function() return DummyRenderer.create(640, 480) end
  )
end

function SampleData.generate_terrain(gear)
  local hex_geometry = {
    width    = 60,
    height   = 50,
    x_offset = 45,
    y_offset = 25,
  }

  local icon_for = {
    fog         = "terrain/fog.png",
    frame       = "terrain/select_frame.bmp",
    participant = "terrain/participant.png",
    grid        = "terrain/grid.bmp",
    managed     = "terrain/managed.png",
  }

  local weather_types = {
    {id = "fair"    },
    {id = "snowing" },
  }

  local terrain_types = {
    {
      id         = "c",
      min_entr   = 0,
      max_entr   = 99,
      name       = "field",
      spot_cost  = {
        fair    = 1,
        snowing = 2,
      },
      move_cost  = {
        wheeled = {
          fair    = 2,
          snowing = 2,
        },
        leg     = {
          fair    = 1,
          snowing = 1,
        },
        air     = {
          fair    = 1,
          snowing = 1,
        },
      },
      image = {
        fair    = "terrain/clear.bmp",
        snowing = "terrain/clear_snow.bmp",
      }
    }
  }
  gear:set("data/terrain", {
    hex_geometry  = hex_geometry,
    weather_types = weather_types,
    terrain_types = terrain_types,
    icons         = icon_for
  })
  gear:declare("terrain", {"data/terrain", "data/dirs", "renderer"},
    function() return Terrain.create() end,
    function(gear, instance, terrain_data, dirs_data, renderer)
      instance:initialize(renderer, terrain_data, dirs_data)
    end
  )
end

function SampleData.generate_battle_scheme(gear)
  gear:declare("battle_formula", {"engine"},
    function() return BattleFormula.create() end,
    function(gear, instance, engine) instance:initialize(engine) end
  )
  gear:set("data/battle_blocks", {
    { block_id = "1", fire_type = "battle", condition = '(I.state == "attacking") && (P.state == "defending")'},
    { block_id = "1.1", active_weapon = 'I.category("wc_infant")', passive_weapon = 'P.target("any")', action = "battle" },
  })
  gear:declare("battle_scheme", {"data/battle_blocks", "battle_formula"},
    function() return BattleScheme.create() end,
    function(gear, instance, battle_blocks, battle_formula) instance:initialize(battle_formula, battle_blocks) end
  )
end

function SampleData.generate_map(gear)
  gear:set("data/map", {
    width  = 1000,
    height = 1000,
  })

  local engine = gear:get("engine")
  gear:set("helper/map/tiles_generator", function(terrain, x, y)
    local tile_data = {
      x            = x,
      y            = y,
      name         = 'dummy',                -- does not matter
      image_idx    = 13,                     -- does not matter
      terrain_name = 'c',                    -- clear
      terrain_type = terrain:get_type('c'),  -- clear
    }
    return Tile.create(engine, terrain, tile_data)
  end)

  gear:declare("map", {"data/map", "engine", "renderer", "terrain", "helper/map/tiles_generator" },
    function() return Map.create() end,
    function(gear, instance, map_data, engine, renderer, terrain, tiles_generator)
      instance:initialize(engine, renderer, terrain, tiles_generator, map_data)
    end
  )
end

function SampleData.generate_scenario(gear)
  local to_map = function(map, list)
    _.each(list, function(_, object)
      local id = assert(object.id)
      map[id] = object
    end)
  end

  gear:set("data/nations", {
    {
      id             = "rus",
      name           = "Россия",
      unit_icon_path = "nations/rus-unit.png",
      icon_path      = "nations/rus.png",
    },
    {
      id             = "ger",
      name           = "Deutschland",
      unit_icon_path = "nations/ger-unit.png",
      icon_path      = "nations/ger.png",
    },
  })

  gear:declare("nations", {"data/nations", "data/dirs", "renderer"},
    function() return {} end,
    function(gear, instance, data_nations, data_dirs, renderer)
      for _, nation_data in pairs(data_nations) do
        local n = Nation.create()
        n:initialize(renderer, nation_data, data_dirs)
        table.insert(instance, n)
      end
    end
  )

  gear:declare("nations::map", {"nations"},
    function() return {} end,
    function(gear, instance, nations) to_map(instance, nations) end
  )

  gear:declare("players", {"data/players", "nations::map"},
    function() return {} end,
    function(gear, instance, data_players, nation_for)
      for _, player_data in pairs(data_players) do
        local p = Player.create()
        p:initialize(nation_for, player_data)
        table.insert(instance, p)
      end
    end
  )

  gear:set("data/players", {
    {
      id      = "allies",
      order   = 1,
      nations = { 'rus' }
    },
    {
      id      = "axis",
      order   = 2,
      nations = { 'ger' }
    },
  })


  -- weapons data

  gear:set("data/weapons/target_types", {
    {id = "soft"},
    {id = "hard"},
    {id = "air"},
  })

  gear:declare("data/weapons/target_types::map", {"data/weapons/target_types"},
    function() return {} end,
    function(gear, instance, target_types) to_map(instance, target_types) end
  )

  gear:set("data/weapons/movement_types", {
    {id = "wheeled"},
    {id = "leg"},
    {id = "air"},
  })

  gear:declare("data/weapons/movement_types::map", {"data/weapons/movement_types"},
    function() return {} end,
    function(gear, instance, list) to_map(instance, list) end
  )

  gear:set("data/weapons/classes", {
    {id = "wk_infant", flags = {}, icon = "units/classes/wk_infant" },
    {id = "wk_armor", flags = {}, icon = "units/classes/wk_armor" },
    {id = "wk_artil", flags = { RANGED_FIRE = "TRUE" }, icon = "units/classes/wk_artil" },
    {id = "wk_fighter", flags = {}, icon = "units/classes/wk_fighter" },
  })

  gear:declare("weapons/classes", {"data/weapons/classes", "data/dirs", "renderer"},
    function() return {} end,
    function(gear, instance, list, data_dirs, renderer)
      _.each(list, function(_, weapon_class_data)
        local wc = WeaponClass.create()
        wc:initialize(renderer, weapon_class_data, data_dirs)
        table.insert(instance, wc)
      end)
    end
  )

  gear:declare("weapons/classes::map", {"weapons/classes"},
    function() return {} end,
    function(gear, instance, list) to_map(instance, list) end
  )

  gear:set("data/weapons/categories", {
    {id = "wc_infant", flags = {} },
    {id = "wc_tank", flags = {} },
    {id = "wc_artil", flags = {} },
    {id = "wc_rear", flags = {}},
    {id = "wc_fighter", flags = {}},
  })

  gear:declare("data/weapons/categories::map", {"data/weapons/categories"},
    function() return {} end,
    function(gear, instance, list) to_map(instance, list) end
  )


  gear:set("data/weapons/types", {
    {id = "wt_infant"},
    {id = "wt_tankInfMid" },
    {id = "wt_minComp" },
    {id = "wt_canField"},
    {id = "wt_antiairMG"},
    {id = "wt_FightLt"},
  })

  gear:declare("data/weapons/types::map", {"data/weapons/types"},
    function() return {} end,
    function(gear, instance, list) to_map(instance, list) end
  )

  gear:set("data/weapons/definitions", {
    {
      id = "rus_weapon_1",
      name = "Rus Infatry 1",
      range = { surface = 1 },
      nation = "rus",
      movement = 3,
      range   = {air = 0, surface = 1},
      defence = {air = 8, surface = 7 },
      attack = { air = 0, soft = 2, hard = 1 },
      flags  = {},
      move_type = "leg",
      weap_category = "wc_infant",
      target_type = "soft",
      weap_type  = "wt_infant",
      weap_class = "wk_infant",
    },
    {
      id = "ger_weapon_1",
      name = "German Infatry 1",
      range = { surface = 1 },
      nation = "ger",
      movement = 3,
      range   = {air = 0, surface = 1},
      defence = {air = 8, surface = 7 },
      attack = { air = 0, soft = 2, hard = 1 },
      flags  = {},
      move_type = "leg",
      weap_category = "wc_infant",
      target_type = "soft",
      weap_type  = "wt_infant",
      weap_class = "wk_infant",
    },
  })

  gear:declare("weapons/definitions", {"data/weapons/definitions",
    "weapons/classes::map", "data/weapons/types::map", "data/weapons/categories::map",
    "data/weapons/movement_types::map", "data/weapons/target_types::map", "nations::map",
    "data/dirs", "renderer"},
    function() return {} end,
    function(gear, instance, list, classes_for, types_for, category_for, movement_type_for, target_type_for, nation_for, data_dirs, renderer)
      for _, weapon_data in ipairs(list) do
        local w = Weapon.create()
        w:initialize(renderer, weapon_data, classes_for, types_for, category_for, movement_type_for, target_type_for, nation_for, data_dirs)
        table.insert(instance, w)
      end
    end
  )

  gear:declare("weapons/definitions::map", {"weapons/definitions"},
    function() return {} end,
    function(gear, instance, list) to_map(instance, list) end
  )

  -- units

  gear:set("data/units/types", {
    {id = "ut_land"},
    {id = "ut_naval"},
    {id = "ut_air"},
  })

  gear:declare("data/units/types::map", {"data/units/types"},
    function() return {} end,
    function(gear, instance, list) to_map(instance, list) end
  )

  gear:set("data/units/classes", {
    {id = "inf", ["type"] = "ut_land"},
  })

  gear:declare("data/units/classes::map", {"data/units/classes"},
    function() return {} end,
    function(gear, instance, list) to_map(instance, list) end
  )

  gear:set("data/units/definitions", {
    {
      id = "rus_ud_1",
      name = "Russian Unit Definition (division)",
      size = "L",
      flags = {},
      nation = "rus",
      ammo = 5,
      unit_class = "inf",
      spotting = 1,
      staff = {
        rus_weapon_1 = 300,
      },
      icons = {
        marching  = "units/rus/rus_inf_M1.png",
        defending = "units/rus/rus_inf_D1.png",
        attacking = "units/rus/rus_inf_A1.png",
      }
    },
    {
      id = "ger_ud_1",
      name = "German Unit Definition (brigade)",
      size = "S",
      flags = {},
      nation = "ger",
      ammo = 5,
      unit_class = "inf",
      spotting = 1,
      staff = {
        ger_weapon_1 = 35,
      },
      icons = {
        marching  = "units/ger/GerInf01.png",
        defending = "units/ger/GerInf01.png",
        attacking = "units/ger/GerInf01.png",
      }
    },
  })


  gear:declare("units/definitions", {"data/units/definitions", "data/units/classes::map", "data/units/types::map",
    "nations::map", "data/weapons/types::map", "data/dirs", "renderer"},
    function() return {} end,
    function(gear, instance, list, classes_for, types_for, nations_for, weapon_types_for, data_dirs, renderer)
      for _, definition_data in ipairs(list) do
        local ud = UnitDefinition.create()
        ud:initialize(renderer, definition_data, classes_for, types_for, nations_for, weapon_types_for, data_dirs)
        table.insert(instance, ud)
      end
    end
  )
  gear:declare("units/definitions::map", {"units/definitions"},
    function() return {} end,
    function(gear, instance, list) to_map(instance, list) end
  )

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

  --- scenario

  gear:set("data/objectives", {
    {
      x = 2, y = 4,
      nation = 'ger',
    },
    {
      x = 7, y = 5,
      nation = 'rus',
    },
  })

  gear:set("data/scenario", {
    description = "demo scenario for polkovodets engine capabilities demonstration",
    authors     = "Ivan Baidakou",
    name        = "demo",
    date        = "1/09/39",
    weather     = { "fair", "snowing", "fair", "fair", "fair", "fair", "fair", "fair", "fair", "fair"},
  });

  gear:declare("nation/player::map", {"players", "nations::map"},
    function() return {} end,
    function(gear, instance, players, nation_for)
      for _, player in pairs(players) do
        for _, nation in pairs(player.nations) do
          instance[nation.id] = player
        end
      end
    end
  )

  gear:set("data/armies", {
    {
      id = "rus_unit_1",
      name = "Russian Unit 1/1",
      state = "defending",
      unit_definition_id = "rus_ud_1",
      x = 2, y = 2,
      exp = 0,
      entr = 0,
      orientation = "right",
      staff = {
        rus_weapon_1 = "300",
      },
    },
    {
      id = "rus_unit_2",
      name = "Russian Unit 1/2",
      state = "defending",
      unit_definition_id = "rus_ud_1",
      x = 3, y = 2,
      exp = 0,
      entr = 0,
      orientation = "right",
      staff = {
        rus_weapon_1 = "250",
      },
    },
    {
      id = "ger_unit_1",
      name = "German Unit Definition 1",
      state = "defending",
      unit_definition_id = "ger_ud_1",
      x = 4, y = 2,
      exp = 0,
      entr = 0,
      orientation = "left",
      staff = {
        ger_weapon_1 = "30",
      },
    },
  })

  gear:declare("scenario", {"data/scenario", "data/objectives", "data/armies",
    "engine", "renderer", "map",
    "nations::map", "weapons/definitions::map", "units/definitions::map", "nation/player::map"},
    function() return Scenario.create() end,
    function(gear, instance, ...)
      instance:initialize(...)
    end
  )
end

function SampleData.generate_validators(gear)
  gear:declare("validator", { "validators/weapons/movement_types", "validators/units/classes" },
    function() return { } end,
    function(gear, instance, ...)
      local validators = {}
      instance.fn = function()
        _.each(validators, function(_, v) v.fn() end)
      end
      print("all data seems to be valid")
    end
  )
end


return SampleData
