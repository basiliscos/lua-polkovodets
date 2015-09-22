#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local inspect = require('inspect')


local Scenario = require 'polkovodets.Scenario'
local Engine = require 'polkovodets.Engine'
local DummyRenderer = require 't.DummyRenderer'

local dirent = require "posix.dirent"

for _, f in pairs(dirent.dir("data/scenarios/pg")) do
   if(string.sub(f, 1, 1) ~= '.') then
	  print(f)
	  local engine = Engine.create()
	  engine:set_renderer(DummyRenderer.create(640, 480))

	  local scenario = Scenario.create(engine)
	  scenario:load('pg/' .. f)
	  ok(engine:get_scenario())
	  ok(engine:get_map())
	  ok(engine.nations)
	  ok(engine.flags)
   end
end

done_testing()
