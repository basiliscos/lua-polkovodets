#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local _ = require ("moses")
local inspect = require('inspect')

local Gear = require "gear"

local Engine = require 'polkovodets.Engine'
local SampleData = require 'polkovodets.SampleData'

local get_fresh_data = function()
  local gear = Gear.create()
  local engine = Engine.create(gear, "en")

  SampleData.generate_test_data(gear)
  SampleData.generate_battle_scheme(gear)
  SampleData.generate_map(gear)
  SampleData.generate_scenario(gear)
  SampleData.generate_terrain(gear)

  gear:get("validator").fn()
  local scenario = gear:get("scenario")
  local map = gear:get("map")
  engine:end_turn()

  return engine
end


subtest("reconstruct town from destroyed town", function()
  local engine = get_fresh_data()
  local map = engine.gear:get("map")

  engine:end_turn()

  local engineers = map.tiles[9][11]:get_unit('surface')
  ok(engineers)

  engineers:update_actions_map()
  is_deeply(engineers.data.actions_map.special, {},
    "the ruined town is too far")
  engineers:move_to(map.tiles[9][10])

  engineers:update_actions_map()
  is_deeply(engineers.data.actions_map.special[map.tiles[9][10].id],
    {build = 50},
    "engineers can reconstruct burned town, where they are located")
end)

done_testing()
