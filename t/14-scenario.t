#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local inspect = require('inspect')
local _ = require ("moses")
local DummyRenderer = require 't.DummyRenderer'

local Gear = require "gear"

local Engine = require 'polkovodets.Engine'
local Nation = require 'polkovodets.Nation'
local Player = require 'polkovodets.Player'
local Scenario = require 'polkovodets.Scenario'
local UnitDefinition = require 'polkovodets.UnitDefinition'
local Weapon = require 'polkovodets.Weapon'
local WeaponClass = require 'polkovodets.WeaponClass'

local SampleData = require 'polkovodets.SampleData'

local gear = Gear.create()
gear:declare("renderer", { constructor = function() return DummyRenderer.create(640, 480) end})
local engine = Engine.create(gear, "en")

SampleData.generate_test_data(gear)
SampleData.generate_terrain(gear)
SampleData.generate_map(gear)

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
    unit_icon_path = "path/to/some.png",
    icon_path      = "path/to/some.png",
  },
  {
    id             = "ger",
    name           = "Deutschland",
    unit_icon_path = "path/to/some.png",
    icon_path      = "path/to/some.png",
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
  {id = "air"},
})

gear:set("data/weapons/classes", {
  {id = "wk_infant", flags = {}, icon = "units/classes/wk_infant" },
  {id = "wk_armor", flags = {}, icon = "units/classes/wk_armor" },
  {id = "wk_artil", flags = { RANGED_FIRE = "TRUE" }, icon = "units/classes/wk_artil" },
  {id = "wk_fighter", flags = {}, icon = "units/classes/wk_fighter" },
})

gear:set("data/weapons/categories", {
  {id = "wc_infant", flags = {} },
  {id = "wc_tank", flags = {} },
  {id = "wc_artil", flags = {} },
  {id = "wc_rear", flags = {}},
  {id = "wc_fighter", flags = {}},
})

gear:set("data/weapons/types", {
  {id = "wt_infant",     class_id = "wk_infant",  flags = {}},
  {id = "wt_tankInfMid", class_id = "wk_armor" ,  flags = {}},
  {id = "wt_artil",      class_id = "wk_artil",   flags = {}},
  {id = "wt_FightLt",    class_id = "wk_fighter", flags = {}},
})

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

-- units

gear:set("data/units/types", {
  {id = "ut_land"},
  {id = "ut_naval"},
  {id = "ut_air"},
})

gear:set("data/units/classes", {
  {id = "inf", ["type"] = "ut_land"},
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
    spotting = 1,
    staff = {
      wt_infant = 300,
    },
    icons = {
      marching = "path/to/some.png",
      defending = "path/to/some.png",
      attacking = "path/to/some.png",
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
      wt_infant = 35,
    },
    icons = {
      marching = "path/to/some.png",
      defending = "path/to/some.png",
      attacking = "path/to/some.png",
    }
  },
})


-- scenario

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

gear:set("data/armies", {
  {
    id = "rus_unit_1",
    name = "Russian Unit Definition 1",
    state = "defending",
    unit_definition_id = "rus_ud_1",
    x = 2, y = 2,
    exp = 0,
    entr = 0,
    orientation = "left",
    staff = {
      rus_weapon_1 = "300",
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
    orientation = "right",
    staff = {
      ger_weapon_1 = "30",
    },
  },
})

ok(gear:get("nations::map"))
ok(gear:get("players"))
ok(gear:get("weapons/classes::map"))
ok(gear:get("weapons/definitions::map"))
ok(gear:get("units/definitions::map"))
ok(gear:get("nation/player::map"))
ok(gear:get("objectives"))
ok(gear:get("scenario"))
gear:get("validators/weapons/movement_types").fn()
gear:get("validators/units/classes").fn()

done_testing()
