#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local inspect = require('inspect')

local Map = require 'polkovodets.Map'
local Engine = require 'polkovodets.Engine'
local DummyRenderer = require 't.DummyRenderer'

local engine = Engine.create()
DummyRenderer.create(engine, 640, 480)
local map = Map.create(engine)
ok(map)

map:load('data/db/scenarios/Test/map01')

is(#map.tiles, 15)
is(#map.tiles[1], 15)
local first_tile = map.tiles[1][1]
ok(first_tile)

is(first_tile.data.x, 1)
is(first_tile.data.y, 1)
is(first_tile.data.y, 1)
is(first_tile.data.image_idx, 14)
is(first_tile.data.name, 'Clear')

engine:set_map(map)
engine:update_shown_map()
is(engine.gui.map_sw, 16)
is(engine.gui.map_sh, 11)
is(engine.gui.map_sx, -45)
is(engine.gui.map_sy, -50)

subtest("adjascent tiles",
        function()
           local adj_tiles_33 = {}
           local skip_odd_33 = {}
           for t in engine:get_adjastent_tiles(map.tiles[3][3]) do
              table.insert(adj_tiles_33, t.id)
              if (t.data.x % 2 == 0) then
                 skip_odd_33[t.id] = true
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
              table.insert(adj_tiles_33_revisited, t.id)
           end
           is_deeply(adj_tiles_33_revisited, {
                        "tile[3:2]",
                        "tile[3:4]",
           })

           local adj_tiles_43 = {}
           for t in engine:get_adjastent_tiles(map.tiles[4][3]) do
              table.insert(adj_tiles_43, t.id)
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
           is(start:distance_to(start), 0, "distance to self tile")
           for t in engine:get_adjastent_tiles(start) do
              is(t:distance_to(start), 1, string.format("direct distance %s -> %s", t.id, start.id))
              is(start:distance_to(t), 1, string.format("reverse distance %s -> %s", t.id, start.id))
           end

           is(map.tiles[8][4]:distance_to(map.tiles[4][4]), 4)
           is(map.tiles[8][4]:distance_to(map.tiles[5][4]), 3)
           is(map.tiles[8][4]:distance_to(map.tiles[4][6]), 4)
           is(map.tiles[8][4]:distance_to(map.tiles[4][7]), 5)
           is(map.tiles[8][4]:distance_to(map.tiles[4][8]), 6)
           is(map.tiles[4][6]:distance_to(map.tiles[3][5]), 2)
        end
)

subtest("screen coordinates to tiles",
  function()
    subtest("even left view-frame", function()
      engine.gui.map_x = 0
      is_deeply(engine:pointer_to_tile(32, 50), {2, 2})
      is_deeply(engine:pointer_to_tile(51, 40), {2, 2})
      is_deeply(engine:pointer_to_tile(50, 61), {2, 2})
      is_deeply(engine:pointer_to_tile(31, 75), {2, 2})
      is_deeply(engine:pointer_to_tile(31, 76), {2, 3})
      is_deeply(engine:pointer_to_tile(35, 25), {2, 1})

      is_deeply(engine:pointer_to_tile(62, 65), {3, 3})
      is_deeply(engine:pointer_to_tile(58, 74), {3, 3})
      is_deeply(engine:pointer_to_tile(64, 95), {3, 3})
      is_deeply(engine:pointer_to_tile(62, 65), {3, 3})
      is_deeply(engine:pointer_to_tile(77, 80), {3, 3})
      is_deeply(engine:pointer_to_tile(96, 90), {3, 3})
      is_deeply(engine:pointer_to_tile(97, 63), {3, 3})
      is_deeply(engine:pointer_to_tile(79, 51), {3, 3})
      is_deeply(engine:pointer_to_tile(62, 65), {3, 3})

      is_deeply(engine:pointer_to_tile(76, 101), {3, 4})
      is_deeply(engine:pointer_to_tile(102, 87), {4, 3})
      is_deeply(engine:pointer_to_tile(102, 57), {4, 2})
      is_deeply(engine:pointer_to_tile(86, 48), {3, 2})
    end)

    subtest("odd left view-frame", function()
      engine.gui.map_x = 1
      is_deeply(engine:pointer_to_tile(120,71), {5, 3})
      is_deeply(engine:pointer_to_tile(117,87), {5, 3})
     end)
  end
)

done_testing()
