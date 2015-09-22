#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local inspect = require('inspect')


local Scenario = require 'polkovodets.Scenario'
local Engine = require 'polkovodets.Engine'
local DummyRenderer = require 't.DummyRenderer'

local engine = Engine.create()
engine:set_renderer(DummyRenderer.create(640, 480))

local scenario = Scenario.create(engine)
scenario:load('pg/Test')
ok(engine:get_scenario())
ok(engine:get_map())

is(scenario.turns, 10)
local map = engine:get_map()
local berlin = map.tiles[2+1][4+1]
ok(berlin.data.nation)
is(berlin.data.nation.data.name, "Germany")

done_testing()
