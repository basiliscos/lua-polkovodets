#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'

local Map = require 'polkovodets.Map'
local Engine = require 'polkovodets.Engine'
local DummyRenderer = require 't.DummyRenderer'

local engine = Engine.create()
engine:set_renderer(DummyRenderer.create(640, 480))
local map = Map.create(engine)
ok(map)

map:load('pg/map01')

is(#map.tiles, 10)
is(#map.tiles[1], 10)
local first_tile = map.tiles[1][1]
ok(first_tile)

is(first_tile.data.x, 1)
is(first_tile.data.y, 1)
is(first_tile.data.y, 1)
is(first_tile.data.image_idx, 14)
is(first_tile.data.name, 'Clear')
is(first_tile.data.terrain_type.move_cost.air.I, '1')

engine:set_map(map)
is(engine.gui.map_sw, 16)
is(engine.gui.map_sh, 11)
is(engine.gui.map_sx, -45)
is(engine.gui.map_sy, -50)

local adj_tiles_33 = {}
for t in engine:get_adjastent_tiles(map.tiles[3][3]) do
   table.insert(adj_tiles_33, t.uniq_id)
end
is_deeply(adj_tiles_33, {
             "tile[2:2]",
             "tile[3:2]",
             "tile[4:2]",
             "tile[4:3]",
             "tile[3:4]",
             "tile[2:3]",
})

local adj_tiles_43 = {}
for t in engine:get_adjastent_tiles(map.tiles[4][3]) do
   table.insert(adj_tiles_43, t.uniq_id)
end
is_deeply(adj_tiles_43, {
             "tile[3:3]",
             "tile[4:2]",
             "tile[5:3]",
             "tile[5:4]",
             "tile[4:4]",
             "tile[3:4]",
})

done_testing()
