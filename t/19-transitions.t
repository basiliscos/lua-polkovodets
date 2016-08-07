#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local _ = require ("moses")
local inspect = require('inspect')
local DummyRenderer = require 't.DummyRenderer'

local Gear = require "gear"

local Engine = require 'polkovodets.Engine'
local SampleData = require 'polkovodets.SampleData'

local get_fresh_data = function()
  local gear = Gear.create()
  gear:declare("renderer", { constructor = function() return DummyRenderer.create(640, 480) end})
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

subtest("simple", function()
  local engine = get_fresh_data()
  local map = engine.gear:get("map")
  local inf = map.tiles[3][3]:get_unit('surface')
  ok(inf)
  is(inf.data.state, 'defending')

  inf:update_actions_map()
  local state = engine.state
  state:set_selected_unit(inf)

  -- actions
  is(inf:is_action_possible('information', true), true, "get unit information")
  is(inf:is_action_possible('change_orientation', true), true, "can change orientation")
  is(inf:is_action_possible('move', true, map.tiles[3][6]), true, "can move to tile [3:4]")
  ok(not inf:is_action_possible('move', true, map.tiles[13][4]), "cannot move to tile [13:4]")
  is(inf:is_action_possible('retreat', true, map.tiles[3][4]), true, "can retreat tile [3:4]")
  ok(not inf:is_action_possible('retreat', true, map.tiles[3][6]), "cannot retreat tile [3:6] (too far, but we can move there)")
  ok(not inf:is_action_possible('retreat', true, map.tiles[13][4]), "cannot retreat to tile [13:4] (too far)")
  ok(not inf:is_action_possible('patrol', true, map.tiles[3][4]), "cannot patrol tile [3:4] (n/a)")
  ok(not inf:is_action_possible('raid', true, map.tiles[3][4]), "cannot raid tile [3:4] (n/a)")
  ok(not inf:is_action_possible('attach', true, map.tiles[3][4]), "can't attach at tile [4:4] (no unit)")
  ok(inf:is_action_possible('attach', true, map.tiles[4][4]), "can attach at tile [4:4]")

  -- change state
  is(inf:is_action_possible('defending', false), false, "cannot change state to defending (already in it)")
  is(inf:is_action_possible('circular_defending', false), true, "can change state to circular_defending")

  ok(inf.tile:get_possible_actions(), "got action list")
end)

done_testing()
