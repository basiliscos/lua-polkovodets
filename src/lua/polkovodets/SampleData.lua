local _ = require ("moses")

local Tile = require 'polkovodets.Tile'

local SampleData = {}
SampleData.__index = SampleData

function SampleData.generate_test_data(gear)
  gear:set("data/dirs", {
    scenarios   = 'data/db/scenarios',
    definitions = 'data/db',
    gfx         = 'data/gfx.sample',
    themes      = 'data/gfx.sample/themes/'
  })
end

function SampleData.generate_terrain(gear)
  local hex_geometry = {
    width    = 60,
    height   = 50,
    x_offset = 45,
    y_offset = 25,
  }
  gear:set("data/hex_geometry", hex_geometry)

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
      flags      = {},
      spot_cost  = {
        fair    = 1,
        snowing = 2,
      },
      move_cost  = {
        wheeled = {
          fair    = 2,
          snowing = 2,
        },
        tracked = {
          fair    = 2,
          snowing = 2,
        },
        leg     = {
          fair    = 1,
          snowing = 1,
        },
        towed     = {
          fair    = 'A',
          snowing = 'A',
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
    },
    {
      id         = "r",
      min_entr   = 0,
      max_entr   = 99,
      name       = "road",
      flags      = {},
      spot_cost  = {
        fair    = 1,
        snowing = 1,
      },
      move_cost  = {
        wheeled = {
          fair    = 1,
          snowing = 1,
        },
        tracked = {
          fair    = 2,
          snowing = 2,
        },
        leg     = {
          fair    = 1,
          snowing = 1,
        },
        towed     = {
          fair    = 'A',
          snowing = 'A',
        },
        air     = {
          fair    = 1,
          snowing = 1,
        },
      },
      image = {
        fair    = "terrain/road.bmp",
        snowing = "terrain/road_snow.bmp",
      }
    },
    {
      id         = "f",
      min_entr   = 0,
      max_entr   = 99,
      name       = "road",
      flags      = {},
      spot_cost  = {
        fair    = 2,
        snowing = 2,
      },
      move_cost  = {
        wheeled = {
          fair    = 4,
          snowing = 4,
        },
        tracked = {
          fair    = 2,
          snowing = 2,
        },
        leg     = {
          fair    = 1,
          snowing = 1,
        },
        towed     = {
          fair    = 'A',
          snowing = 'A',
        },
        air     = {
          fair    = 1,
          snowing = 1,
        },
      },
      image = {
        fair    = "terrain/forest.bmp",
        snowing = "terrain/forest_snow.bmp",
      }
    },
    {
      id         = "a",
      min_entr   = 0,
      max_entr   = 99,
      name       = "airfield",
      flags      = {},
      spot_cost  = {
        fair    = 2,
        snowing = 2,
      },
      move_cost  = {
        wheeled = {
          fair    = 1,
          snowing = 1,
        },
        tracked = {
          fair    = 2,
          snowing = 2,
        },
        leg     = {
          fair    = 1,
          snowing = 1,
        },
        towed     = {
          fair    = 'A',
          snowing = 'A',
        },
        air     = {
          fair    = 1,
          snowing = 1,
        },
      },
      image = {
        fair    = "terrain/airfield.bmp",
        snowing = "terrain/airfield_snow.bmp",
      }
    },
    {
      id         = "t",
      min_entr   = 0,
      max_entr   = 99,
      name       = "town",
      flags      = {
        ATTACK_CHANGES_TO   = "T",
        PER_TURN_NEG_ATTACK = 100,
      },
      spot_cost  = {
        fair    = 2,
        snowing = 2,
      },
      move_cost  = {
        wheeled = {
          fair    = 1,
          snowing = 1,
        },
        tracked = {
          fair    = 2,
          snowing = 2,
        },
        leg     = {
          fair    = 1,
          snowing = 1,
        },
        towed     = {
          fair    = 'A',
          snowing = 'A',
        },
        air     = {
          fair    = 1,
          snowing = 1,
        },
      },
      image = {
        fair    = "terrain/town.bmp",
        snowing = "terrain/town_snow.bmp",
      }
    },
    {
      id         = "T",
      min_entr   = 0,
      max_entr   = 99,
      name       = "destroyed-town",
      flags      = {
        BUILD_CHANGES_TO  = "t",
        BUILD_CHANGE_COST = 100,
      },
      spot_cost  = {
        fair    = 2,
        snowing = 2,
      },
      move_cost  = {
        wheeled = {
          fair    = 1,
          snowing = 1,
        },
        tracked = {
          fair    = 2,
          snowing = 2,
        },
        leg     = {
          fair    = 1,
          snowing = 1,
        },
        towed     = {
          fair    = 'A',
          snowing = 'A',
        },
        air     = {
          fair    = 1,
          snowing = 1,
        },
      },
      image = {
        fair    = "terrain/town-destroyed.bmp",
        snowing = "terrain/town-destroyed_snow.bmp",
      }
    },
  }

  gear:set("data/terrain", {
    weather_types = weather_types,
    terrain_types = terrain_types,
    icons         = icon_for
  })
end

function SampleData.generate_battle_scheme(gear)
  gear:set("data/battle_blocks", {
    { block_id = "1", fire_type = "battle", condition = '(I.state == "attacking") && (P.state == "defending")'},
    { block_id = "1.1", active_weapon = 'I.category("wc_infant")', passive_weapon = 'P.target("any")', action = "battle" },
  })

  gear:set("data/transition_rules", {
    { action = 'change_orientation', from = '*',                  cost = 0   },
    { action = 'information',        from = '*',                  cost = 0   },
    { action = 'attach',             from = '*',                  cost = 1   },
    { action = 'detach',             from = '*',                  cost = 0   },
    { action = 'move',               from = '*',                  cost = 0   },
    { action = 'retreat',            from = '*',                  cost = 1   },
    { action = 'patrol',             from = '*',                  cost = 1   },
    { action = 'raid',               from = '*',                  cost = 1   },
    { action = 'refuel',             from = '*',                  cost = 'A' },
    { action = 'defend',             from = 'circular_defending', cost = 0   },
    { action = 'defend',             from = '*',                  cost = 'A' },
    { action = 'circular_defend',    from = 'defend',             cost = 0   },
    { action = 'circular_defend',    from = '*',                  cost = 'A' },
    { action = 'attack',             from = '*',                  cost = 'A' },

    --[[
    { to = 'constructing', from = '*', cost = 'A'},
    ]]
  })
end

function SampleData.generate_map(gear)

  local width, height = 100, 100

  local my_map = {

    -- vertical road
    ["4_4"] = { "r", 1 }, ["4_5"]  = { "r", 1 },  ["4_6"]  = { "r", 1 }, ["4_7"]  = { "r", 1 }, ["4_8"]  = { "r", 1 },  ["4_9"]  = { "r", 1 }, ["4_10"] = { "r", 1 },

    -- airport
    ["7_4"] = { "a", 0 }, ["3_8"]  = { "a", 0 },

    -- some forest
    ["8_6"] = { "f", 0 }, ["9_6"] = { "f", 0 }, ["10_5"] = { "f", 0 }, ["8_7"] = { "f", 0 }, ["9_7"] = { "f", 0 }, ["10_6"] = { "f", 0 },
    ["20_10"] = { "f", 0 }, ["21_11"] = { "f", 0 }, ["22_12"] = { "f", 0 }, ["23_13"] = { "f", 0 }, ["24_15"] = { "f", 0 }, ["26_16"] = { "f", 0 },
    ["27_17"] = { "f", 0 }, ["28_18"] = { "f", 0 }, ["29_19"] = { "f", 0 }, ["30_20"] = { "f", 0 }, ["30_21"] = { "f", 0 }, ["30_22"] = { "f", 0 },
    ["30_23"] = { "f", 0 }, ["30_24"] = { "f", 0 }, ["30_25"] = { "f", 0 }, ["30_26"] = { "f", 0 }, ["30_27"] = { "f", 0 }, ["30_28"] = { "f", 0 },

    -- town
    ["8_9"] = { "t", 0 }, ["9_10"] = { "T", 2 },

  }

  local hex_names = {
    ["8:9"] = "Some city",
  }

  local engine = gear:get("engine")

  local map_data = {
    path   = "Sample data, no path available",
    width  = width,
    height = height,
    tiles_data = {},
    tile_names = {}
  }

  for y = 1, height do
    for x = 1, width do
      local key = x .. "_" .. y

      -- clear terrain by default
      local t_type, image_idx = 'c', 13
      local alternative_data = my_map[key]
      if (alternative_data) then
        t_type, image_idx = table.unpack(alternative_data)
      end

      local datum = t_type .. image_idx
      table.insert(map_data.tiles_data, datum)
    end
  end

  gear:set("data/hex_names", hex_names)
  gear:set("data/map", map_data)
end

function SampleData.generate_scenario(gear)

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

  gear:set("data/weapons/movement_types", {
    {id = "wheeled"},
    {id = "leg"},
    {id = "tracked"},
    {id = "towed"},
    {id = "air"},
  })

  gear:set("data/weapons/classes", {
    {id = "wk_infant", flags = {}, icon = "units/classes/wk_infant" },
    {id = "wk_armor", flags = {}, icon = "units/classes/wk_armor" },
    {id = "wk_artil", flags = { RANGED_FIRE = "TRUE" }, icon = "units/classes/wk_artil" },
    {id = "wk_fighter", flags = {}, icon = "units/classes/wk_fighter" },
    {id = "wk_transp", flags = {}, icon = "units/classes/wk_transp" },
  })

  gear:set("data/weapons/categories", {
    {id = "wc_infant",  flags = {} },
    {id = "wc_tank",    flags = {} },
    {id = "wc_artil",   flags = {} },
    {id = "wc_rear",    flags = {} },
    {id = "wc_fighter", flags = {} },
  })

  gear:set("data/weapons/types", {
    {id = "wt_infant",     class_id = "wk_infant",  flags = {} },
    {id = "wt_engineer",   class_id = "wk_infant",  flags = {} },
    {id = "wt_tankInfMid", class_id = "wk_armor",   flags = {} },
    {id = "wt_transp",     class_id = "wk_transp",  flags = {} },
    {id = "wt_artil",      class_id = "wk_artil",   flags = {} },
    {id = "wt_FightLt",    class_id = "wk_fighter", flags = {} },
  })

  gear:set("data/weapons/definitions", {
    {
      id = "rus_weapon_1",
      name = "Rus Infatry 1",
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
      id = "rus_trasport_1",
      name = "GAZ-1",
      nation = "rus",
      movement = 6,
      range   = {air = 0, surface = 1},
      defence = {air = 1, surface = 1 },
      attack = { air = 0, soft = 0, hard = 0 },
      flags  = { TRANSPORTS_LEG = 1 },
      move_type = "wheeled",
      weap_category = "wc_rear",
      target_type = "soft",
      weap_type  = "wt_transp",
      weap_class = "wk_transp",
    },
    {
      id = "rus_art_1",
      name = "vasiliok-1",
      nation = "rus",
      movement = 1,
      range   = {air = 0, surface = 3},
      defence = {air = 1, surface = 1 },
      attack = { air = 0, soft = 10, hard = 3 },
      flags  = { ATTACKS_FIRST = 1 },
      move_type = "towed",
      weap_category = "wc_artil",
      target_type = "soft",
      weap_type  = "wt_artil",
      weap_class = "wk_artil",
    },
    {
      id = "rus_tank_1",
      name = "t34",
      nation = "rus",
      movement = 10,
      range   = {air = 0, surface = 1},
      defence = {air = 5, surface = 6 },
      attack = { air = 0, soft = 4, hard = 7 },
      flags  = { },
      move_type = "tracked",
      weap_category = "wc_tank",
      target_type = "hard",
      weap_type  = "wt_tankInfMid",
      weap_class = "wk_armor",
    },
    {
      id = "rus_aircrat_1",
      name = "yak-5",
      nation = "rus",
      movement = 15,
      range   = {air = 1, surface = 0},
      defence = {air = 10, surface = 7 },
      attack = { air = 10, soft = 4, hard = 1 },
      flags  = { },
      move_type = "air",
      weap_category = "wc_fighter",
      target_type = "air",
      weap_type  = "wt_FightLt",
      weap_class = "wk_fighter",
    },
    {
      id = "rus_hq_1",
      name = "gen-shtab",
      nation = "rus",
      movement = 10,
      range   = {air = 1, surface = 0},
      defence = {air = 5, surface = 5 },
      attack = { air = 0, soft = 1, hard = 1 },
      flags  = { },
      move_type = "air",
      weap_category = "wc_rear",
      target_type = "air",
      weap_type  = "wt_FightLt",
      weap_class = "wk_fighter",
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
    {
      id = "ger_weapon_2",
      name = "German Builders 1",
      range = { surface = 1 },
      nation = "ger",
      movement = 3,
      range   = {air = 0, surface = 1},
      defence = {air = 8, surface = 7 },
      attack = { air = 0, soft = 1, hard = 1 },
      flags  = {
        BUILD_CAPABILITIES = 5,
      },
      move_type = "leg",
      weap_category = "wc_infant",
      target_type = "soft",
      weap_type  = "wt_engineer",
      weap_class = "wk_infant",
    },
  })


  -- units
  gear:set("data/units/types", {
    {id = "ut_land"},
    {id = "ut_naval"},
    {id = "ut_air"},
  })

  gear:set("data/units/classes", {
    {id = "inf", ["type"] = "ut_land"},
    {id = "tank", ["type"] = "ut_land"},
    {id = "hq", ["type"] = "ut_land"},
    {id = "air_fighter", ["type"] = "ut_air"},
  })

  gear:set("data/units/definitions", {
    {
      id = "rus_ud_1",
      name = "Russian Unit Definition (division)",
      size = "L",
      flags = {},
      nation = "rus",
      ammo = 5,
      unit_class = "inf",
      spotting = 2,
      staff = {
        wt_infant = 300,
      },
      icons = {
        marching           = "units/rus/rus_inf_M1.png",
        defending          = "units/rus/rus_inf_D1.png",
        circular_defending = "units/rus/rus_inf_DC.png",
        attacking          = "units/rus/rus_inf_A1.png",
        retreating         = "units/rus/rus_inf_MR.png",
        escaping           = "units/rus/rus_inf_ME.png",
        captured           = "units/rus/rus_inf_C.png",
        refuelling         = "units/rus/rus_inf_REF.png",
      }
    },
    {
      id = "rus_ud_2",
      name = "Russian Unit Definition (division / motorized)",
      size = "L",
      flags = {},
      nation = "rus",
      ammo = 5,
      unit_class = "inf",
      spotting = 2,
      staff = {
        wt_infant = 300,
        wt_transp = 300,
      },
      icons = {
        marching           = "units/rus/rus_inf_M1.png",
        defending          = "units/rus/rus_inf_D1.png",
        circular_defending = "units/rus/rus_inf_DC.png",
        attacking          = "units/rus/rus_inf_A1.png",
        retreating         = "units/rus/rus_inf_MR.png",
        escaping           = "units/rus/rus_inf_ME.png",
        captured           = "units/rus/rus_inf_C.png",
        refuelling         = "units/rus/rus_inf_REF.png",
      }
    },
    {
      id = "rus_ud_3",
      name = "Russian Artillery Unit Definition (batalion)",
      size = "S",
      flags = {},
      nation = "rus",
      ammo = 5,
      unit_class = "inf",
      spotting = 2,
      staff = {
        wt_artil = 30,
      },
      icons = {
        marching           = "units/rus/rus_art_M1.png",
        defending          = "units/rus/rus_art_D2.png",
        circular_defending = "units/rus/rus_art_DC.png",
        attacking          = "units/rus/rus_art_A1.png",
        retreating         = "units/rus/rus_art_MR.png",
        escaping           = "units/rus/rus_art_ME.png",
        captured           = "units/rus/rus_art_C.png",
        refuelling         = "units/rus/rus_art_REF.png",
      }
    },
    {
      id = "rus_ud_4",
      name = "Russian Tank Definition (brigade)",
      size = "M",
      flags = {},
      nation = "rus",
      ammo = 5,
      unit_class = "tank",
      spotting = 2,
      staff = {
        wt_tankInfMid = 100,
      },
      icons = {
        marching           = "units/rus/rus_tank_M1.png",
        defending          = "units/rus/rus_tank_D1.png",
        circular_defending = "units/rus/rus_tank_DC.png",
        attacking          = "units/rus/rus_tank_A1.png",
        retreating         = "units/rus/rus_tank_MR.png",
        escaping           = "units/rus/rus_tank_ME.png",
        captured           = "units/rus/rus_tank_C.png",
        refuelling         = "units/rus/rus_tank_REF.png",
      }
    },
    {
      id = "rus_ud_5",
      name = "Russian Fighters (batalion)",
      size = "S",
      flags = {},
      nation = "rus",
      ammo = 5,
      unit_class = "air_fighter",
      spotting = 3,
      staff = {
        wt_FightLt = 15,
      },
      icons = {
        marching    = "units/rus/rus_avia_F1.png",
        refuelling  = "units/rus/rus_avia_S1.png",
      },
    },
    {
      id = "rus_ud_6",
      name = "Russian HQ (batalion)",
      size = "S",
      flags = {
        MANAGE_LEVEL =               	0,
        MANAGED_UNITS_LIMIT =         "unlimited",
        MANAGED_UNIT_SIZES_LIMIT =    "unlimited",
        MANAGED_MANAGERS_LEVEL_LIMIT = "unlimited",
      },
      nation = "rus",
      ammo = 5,
      unit_class = "hq",
      spotting = 3,
      staff = {
        wt_infant = 15,
        wt_transp = 15,
      },
      icons = {
        marching           = "units/rus/rus_stab_M1.png",
        defending          = "units/rus/rus_stab_D1.png",
        circular_defending = "units/rus/rus_stab_DC.png",
        attacking          = "units/rus/rus_stab_D1.png",
        retreating         = "units/rus/rus_stab_MR.png",
        escaping           = "units/rus/rus_stab_ME.png",
        captured           = "units/rus/rus_stab_C.png",
        refuelling         = "units/rus/rus_stab_REF.png",
      },
    },
    {
      id = "ger_ud_1",
      name = "German Unit Definition (batalion)",
      size = "S",
      flags = {},
      nation = "ger",
      ammo = 5,
      unit_class = "inf",
      spotting = 2,
      staff = {
        wt_infant = 35,
      },
      icons = {
        marching           = "units/ger/GerInf01.png",
        defending          = "units/ger/GerInf01.png",
        circular_defending = "units/ger/GerInf01.png",
        attacking          = "units/ger/GerInf01.png",
        retreating         = "units/ger/GerInf01.png",
        escaping           = "units/ger/GerInf01.png",
        captured           = "units/ger/GerInf01.png",
        refuelling         = "units/ger/GerInf01.png",
      }
    },
    {
      id = "ger_ud_2",
      name = "German Engineer Unit Definition (batalion)",
      size = "S",
      flags = {},
      nation = "ger",
      ammo = 5,
      unit_class = "inf",
      spotting = 2,
      staff = {
        wt_engineer = 20,
      },
      icons = {
        marching           = "units/ger/GerInf01.png",
        defending          = "units/ger/GerInf01.png",
        circular_defending = "units/ger/GerInf01.png",
        attacking          = "units/ger/GerInf01.png",
        retreating         = "units/ger/GerInf01.png",
        escaping           = "units/ger/GerInf01.png",
        captured           = "units/ger/GerInf01.png",
        refuelling         = "units/ger/GerInf01.png",
        constructing       = "units/ger/GerInf01.png",
      }
    },
  })


  -- scenario
  gear:set("data/objectives", {
    {
      x = 2, y = 4,
      nation = 'rus',
    },
    {
      x = 8, y = 9,
      nation = 'ger',
    },
    {
      x = 9, y = 10,
      nation = 'ger',
    },
  })

  gear:set("data/scenario", {
    description = "demo scenario for polkovodets engine capabilities demonstration",
    authors     = "Ivan Baidakou",
    name        = "demo",
    date        = "1/09/39",
    weather     = { "fair", "snowing", "fair", "fair", "fair", "fair", "fair", "fair", "fair", "fair"},
  });

  gear:set("data/armies", {
    {
      id = "rus_unit_1",
      name = "Russian Unit 1/1",
      state = "defending",
      unit_definition_id = "rus_ud_1",
      x = 3, y = 3,
      exp = 0,
      entr = 0,
      orientation = "right",
      staff = {
        rus_weapon_1 = "300",
      },
    },
    {
      id = "rus_unit_2",
      name = "Russian Unit 2/1",
      state = "defending",
      unit_definition_id = "rus_ud_2",
      x = 4, y = 3,
      exp = 0,
      entr = 0,
      orientation = "right",
      staff = {
        rus_weapon_1 = "250",
        rus_trasport_1 = "300",
      },
    },
    {
      id = "rus_unit_3",
      name = "Russian Unit 3/1",
      state = "defending",
      unit_definition_id = "rus_ud_3",
      x = 4, y = 4,
      exp = 0,
      entr = 0,
      orientation = "right",
      staff = {
        rus_art_1 = "30",
      },
    },
    {
      id = "rus_unit_4",
      name = "Russian Unit 3/2",
      state = "defending",
      unit_definition_id = "rus_ud_3",
      x = 3, y = 5,
      exp = 0,
      entr = 0,
      orientation = "right",
      staff = {
        rus_art_1 = "30",
      },
    },
    {
      id = "rus_unit_5",
      name = "Russian tank Unit 4/1",
      state = "defending",
      unit_definition_id = "rus_ud_4",
      x = 4, y = 2,
      exp = 0,
      entr = 0,
      orientation = "right",
      staff = {
        rus_tank_1 = "100",
      },
    },
    {
      id = "rus_unit_6",
      name = "Russian air-fighters batallion 5/1",
      state = "marching",
      unit_definition_id = "rus_ud_5",
      x = 7, y = 7,
      exp = 0,
      entr = 0,
      orientation = "right",
      staff = {
        rus_aircrat_1 = 15,
      },
    },
    {
      id = "rus_unit_7",
      name = "Russian HQ/gen hq",
      state = "defending",
      unit_definition_id = "rus_ud_6",
      x = 6, y = 5,
      exp = 0,
      entr = 0,
      orientation = "left",
      staff = {
        rus_weapon_1 = 15,
        rus_trasport_1 = 15,
      },
    },
    {
      id = "rus_unit_8",
      name = "Russian Unit 2/3",
      state = "defending",
      unit_definition_id = "rus_ud_2",
      x = 5, y = 9,
      exp = 0,
      entr = 0,
      orientation = "right",
      staff = {
        rus_weapon_1 = "300",
        rus_trasport_1 = "299",
      },
    },
    {
      id = "rus_unit_9",
      name = "Russian Unit 2/4",
      state = "defending",
      unit_definition_id = "rus_ud_2",
      x = 6, y = 9,
      exp = 0,
      entr = 0,
      orientation = "right",
      staff = {
        rus_weapon_1 = "300",
      },
    },
    {
      id = "rus_unit_10",
      name = "Russian tank Unit 4/1",
      state = "defending",
      unit_definition_id = "rus_ud_4",
      x = 7, y = 8,
      exp = 0,
      entr = 0,
      orientation = "right",
      staff = {
        rus_tank_1 = "100",
      },
    },
    {
      id = "ger_unit_1",
      name = "German Unit Definition 1",
      state = "defending",
      unit_definition_id = "ger_ud_1",
      x = 5, y = 3,
      exp = 0,
      entr = 0,
      orientation = "left",
      staff = {
        ger_weapon_1 = "30",
      },
    },
    {
      id = "ger_unit_2",
      name = "German Unit Definition 1",
      state = "defending",
      unit_definition_id = "ger_ud_1",
      x = 11, y = 5,
      exp = 0,
      entr = 0,
      orientation = "left",
      staff = {
        ger_weapon_1 = "30",
      },
    },
    {
      id = "ger_unit_3",
      name = "German Unit 3",
      state = "defending",
      unit_definition_id = "ger_ud_2",
      x = 9, y = 11,
      exp = 0,
      entr = 0,
      orientation = "left",
      staff = {
        ger_weapon_2 = "10",
      },
    },
  })

end


return SampleData
