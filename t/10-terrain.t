#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'

local inspect = require('inspect')
local Terrain = require 'polkovodets.Terrain'
local Engine = require 'polkovodets.Engine'
local Gear = require "gear"

local SampleData = require 'polkovodets.SampleData'

local gear = Gear.create()
local engine = Engine.create(gear, 'en')
local msg = engine:translate('map.battle-on-tile', {count = 5, tile = "1:2"})
is(msg, "5 battles have occured on the tile 1:2")

SampleData.generate_test_data(gear)

local hex_geometry = {
  width    = 60,
  height   = 50,
  x_offset = 45,
  y_offset = 25,
}

local icon_for = {
  fog         = "path/to/some1.png",
  frame       = "path/to/some2.png",
  participant = "path/to/some3.png",
  grid        = "path/to/some4.png",
  managed     = "path/to/some5.png",
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
      fair    = "path/to/some6.bmp",
      snowing = "path/to/some7.bmp",
    }
  }
}

gear:set("data/terrain", {
  hex_geometry  = hex_geometry,
  weather_types = weather_types,
  terrain_types = terrain_types,
  icons         = icon_for
})


local terrain = gear:get("terrain")
ok(terrain)

local clear = terrain:get_type('c')
ok(clear)
is(clear.spot_cost.snowing, 2)
is(clear.move_cost.air.fair, 1)
is(clear.move_cost.wheeled.fair, 2)
is(clear.move_cost.leg.snowing, 1)

done_testing()
