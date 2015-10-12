#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'

local inspect = require('inspect')
local Terrain = require 'polkovodets.Terrain'
local Engine = require 'polkovodets.Engine'
local DummyRenderer = require 't.DummyRenderer'

local engine = Engine.create()
engine:set_renderer(DummyRenderer.create(640, 480))

local terrain = Terrain.create(engine)
ok(terrain)
terrain:load('landscape.json')

local clear = terrain:get_type('c')
ok(clear)
-- print(inspect(clear))
is(clear.move_cost.air.fair, 1)
is(clear.move_cost.halftracked.raining_mud, 3)
is(clear.spot_cost.snowing_ice, 2)

done_testing()
