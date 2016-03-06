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
    name         = 'dummy',
    image_idx    = 1,
    terrain_name = 'dummy-name',
    terrain_type = terrain:get_type('F'),
  }
  return Tile.create(engine, terrain, tile_data)
end
map:generate(10, 10, 'landscape.json', tiles_generator)

done_testing()
