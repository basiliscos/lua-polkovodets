#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'

local Map = require 'polkovodets.Map'
local Engine = require 'polkovodets.Engine'
local DummyRenderer = require 't.DummyRenderer'

local engine = Engine.create()
local map = Map.create(engine)
ok(map)

map:load('map01')

is(#map.tiles, 10)
is(#map.tiles[1], 10)
local first_tile = map.tiles[1][1]
ok(first_tile)

is(first_tile.x, 1)
is(first_tile.y, 1)
is(first_tile.y, 1)
is(first_tile.image_idx, 14)
is(first_tile.name, 'Clear')
is(first_tile.terrain_type.move_cost.air.I, '1')

engine:set_renderer(DummyRenderer.create(640, 480))
engine:set_map(map)
is(engine.gui.map_sw, 16)
is(engine.gui.map_sh, 11)
is(engine.gui.map_sx, -45)
is(engine.gui.map_sy, -50)

done_testing();	
