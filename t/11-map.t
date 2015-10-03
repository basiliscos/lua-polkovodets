#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local inspect = require('inspect')

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

subtest("adjascent tiles",
        function()
           local adj_tiles_33 = {}
           local skip_odd_33 = {}
           for t in engine:get_adjastent_tiles(map.tiles[3][3]) do
              table.insert(adj_tiles_33, t.uniq_id)
              if (t.data.x % 2 == 0) then
                 skip_odd_33[t.uniq_id] = true
              end
           end
           is_deeply(adj_tiles_33, {
                        "tile[2:2]",
                        "tile[3:2]",
                        "tile[4:2]",
                        "tile[4:3]",
                        "tile[3:4]",
                        "tile[2:3]",
           })

           local adj_tiles_33_revisited = {}
           for t in engine:get_adjastent_tiles(map.tiles[3][3], skip_odd_33) do
              table.insert(adj_tiles_33_revisited, t.uniq_id)
           end
           is_deeply(adj_tiles_33_revisited, {
                        "tile[3:2]",
                        "tile[3:4]",
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
        end
)

subtest("distances",
        function()
           local start = map.tiles[5][3]
           for t in engine:get_adjastent_tiles(start) do
              is(t:distance_to(start), 1)
              is(start:distance_to(t), 1)
           end

           is(map.tiles[8][4]:distance_to(map.tiles[4][4]), 4)
           is(map.tiles[8][4]:distance_to(map.tiles[5][4]), 3)
           is(map.tiles[8][4]:distance_to(map.tiles[4][6]), 4)
           is(map.tiles[8][4]:distance_to(map.tiles[4][7]), 5)
           is(map.tiles[8][4]:distance_to(map.tiles[4][8]), 6)
        end
)

done_testing()
