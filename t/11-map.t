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

gear:set("data/map", {
  width  = 10,
  height = 10,
})

gear:set("helper/map/tiles_generator", function(terrain, x, y)
  local tile_data = {
    x            = x,
    y            = y,
    name         = 'dummy',                -- does not matter
    image_idx    = 1,                      -- does not matter
    terrain_name = 'dummy-name',           -- does not matter
    terrain_type = terrain:get_type('c'),  -- clear
  }
  return Tile.create(engine, terrain, tile_data)
end)

local map = gear:get("map")
ok(map)

ok(map.tiles[1][1])
ok(map.tiles[10][10])
ok(map:lookup_tile(map.tiles[1][1].id))

is(map.gui.map_sw, 16)
is(map.gui.map_sh, 11)
is(map.gui.map_sx, -45)
is(map.gui.map_sy, -50)

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
      map.gui.map_x = 0
      is_deeply(map:pointer_to_tile(32, 50), {2, 2})
      is_deeply(map:pointer_to_tile(51, 40), {2, 2})
      is_deeply(map:pointer_to_tile(50, 61), {2, 2})
      is_deeply(map:pointer_to_tile(31, 75), {2, 2})
      is_deeply(map:pointer_to_tile(31, 76), {2, 3})
      is_deeply(map:pointer_to_tile(35, 25), {2, 1})

      is_deeply(map:pointer_to_tile(62, 65), {3, 3})
      is_deeply(map:pointer_to_tile(58, 74), {3, 3})
      is_deeply(map:pointer_to_tile(64, 95), {3, 3})
      is_deeply(map:pointer_to_tile(62, 65), {3, 3})
      is_deeply(map:pointer_to_tile(77, 80), {3, 3})
      is_deeply(map:pointer_to_tile(96, 90), {3, 3})
      is_deeply(map:pointer_to_tile(97, 63), {3, 3})
      is_deeply(map:pointer_to_tile(79, 51), {3, 3})
      is_deeply(map:pointer_to_tile(62, 65), {3, 3})

      is_deeply(map:pointer_to_tile(76, 101), {3, 4})
      is_deeply(map:pointer_to_tile(102, 87), {4, 3})
      is_deeply(map:pointer_to_tile(102, 57), {4, 2})
      is_deeply(map:pointer_to_tile(86, 48), {3, 2})
    end)

    subtest("odd left view-frame", function()
      map.gui.map_x = 1
      is_deeply(map:pointer_to_tile(120,71), {5, 3})
      is_deeply(map:pointer_to_tile(117,87), {5, 3})
     end)
  end
)

done_testing()
