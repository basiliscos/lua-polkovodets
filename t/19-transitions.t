#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local _ = require ("moses")
local inspect = require('inspect')
local PT = require('t.PolkovodetsTest')

subtest("simple", function()
  local engine = PT.get_fresh_data()
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
