#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local inspect = require('inspect')

local DummyRenderer = require 't.DummyRenderer'
local Engine = require 'polkovodets.Engine'
local Map = require 'polkovodets.Map'
local Tile = require 'polkovodets.Tile'

local engine = Engine.create()
DummyRenderer.create(engine, 640, 480)
local map = Map.create(engine)
ok(map)

local tiles_generator = function(terrain, x, y)
  local tile_data = {
    x            = x,
    y            = y,
    name         = 'dummy',                -- does not matter
    image_idx    = 1,                      -- does not matter
    terrain_name = 'dummy-name',           -- does not matter
    terrain_type = terrain:get_type('F'),  -- field
  }
  return Tile.create(engine, terrain, tile_data)
end
map:generate(10, 10, 'landscape.json', tiles_generator)

ok(map.tiles[1][1])
ok(map.tiles[10][10])
ok(map:lookup_tile(map.tiles[1][1].id))

done_testing()
