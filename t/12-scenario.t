#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'

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

done_testing()
