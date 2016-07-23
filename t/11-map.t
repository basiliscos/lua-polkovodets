#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local inspect = require('inspect')

local DummyRenderer = require 't.DummyRenderer'
local Gear = require "gear"

local Map = require 'polkovodets.Map'
local Engine = require 'polkovodets.Engine'
local Terrain = require 'polkovodets.Terrain'
local Tile = require 'polkovodets.Tile'

local SampleData = require 'polkovodets.SampleData'

local gear = Gear.create()
gear:declare("renderer", { constructor = function() return DummyRenderer.create(640, 480) end})
local engine = Engine.create(gear, "en")

SampleData.generate_test_data(gear)
SampleData.generate_terrain(gear)

local map_data = {
  path   = "dymmy",
  width  = 10,
  height = 10,
  tiles_data = {},
  tile_names = {}
}

for _ = 1, (10 * 100) do
  table.insert(map_data.tiles_data, "c1")
  table.insert(map_data.tile_names, "c1")
end
gear:set("data/map", map_data)


local map = gear:get("map")
local hex_geometry = gear:get("hex_geometry")
ok(map)

ok(map.tiles[1][1])
ok(map.tiles[10][10])
ok(map:lookup_tile(map.tiles[1][1].id))

subtest("adjascent tiles",
        function()
           local adj_tiles_33 = {}
           local skip_odd_33 = {}
           for t in map:get_adjastent_tiles(map.tiles[3][3]) do
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
           for t in map:get_adjastent_tiles(map.tiles[3][3], skip_odd_33) do
              table.insert(adj_tiles_33_revisited, t.id)
           end
           is_deeply(adj_tiles_33_revisited, {
                        "tile[3:2]",
                        "tile[3:4]",
           })

           local adj_tiles_43 = {}
           for t in map:get_adjastent_tiles(map.tiles[4][3]) do
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
           for t in map:get_adjastent_tiles(start) do
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

      is_deeply(map:pointer_to_tile(32, 50, hex_geometry, 0, 0), {2, 2})
      is_deeply(map:pointer_to_tile(51, 40, hex_geometry, 0, 0), {2, 2})
      is_deeply(map:pointer_to_tile(50, 61, hex_geometry, 0, 0), {2, 2})
      is_deeply(map:pointer_to_tile(31, 75, hex_geometry, 0, 0), {2, 2})
      is_deeply(map:pointer_to_tile(31, 76, hex_geometry, 0, 0), {2, 3})
      is_deeply(map:pointer_to_tile(35, 25, hex_geometry, 0, 0), {2, 1})

      is_deeply(map:pointer_to_tile(62, 65, hex_geometry, 0, 0), {3, 3})
      is_deeply(map:pointer_to_tile(58, 74, hex_geometry, 0, 0), {3, 3})
      is_deeply(map:pointer_to_tile(64, 95, hex_geometry, 0, 0), {3, 3})
      is_deeply(map:pointer_to_tile(62, 65, hex_geometry, 0, 0), {3, 3})
      is_deeply(map:pointer_to_tile(77, 80, hex_geometry, 0, 0), {3, 3})
      is_deeply(map:pointer_to_tile(96, 90, hex_geometry, 0, 0), {3, 3})
      is_deeply(map:pointer_to_tile(97, 63, hex_geometry, 0, 0), {3, 3})
      is_deeply(map:pointer_to_tile(79, 51, hex_geometry, 0, 0), {3, 3})
      is_deeply(map:pointer_to_tile(62, 65, hex_geometry, 0, 0), {3, 3})

      is_deeply(map:pointer_to_tile(76, 101, hex_geometry, 0, 0), {3, 4})
      is_deeply(map:pointer_to_tile(102, 87, hex_geometry, 0, 0), {4, 3})
      is_deeply(map:pointer_to_tile(102, 57, hex_geometry, 0, 0), {4, 2})
      is_deeply(map:pointer_to_tile(86, 48, hex_geometry, 0, 0), {3, 2})
    end)

    subtest("odd left view-frame", function()
      is_deeply(map:pointer_to_tile(120,71, hex_geometry, 1, 0), {5, 3})
      is_deeply(map:pointer_to_tile(117,87, hex_geometry, 1, 0), {5, 3})
     end)
  end
)

done_testing()
