#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local _ = require ("moses")
local inspect = require('inspect')
local PT = require('t.PolkovodetsTest')

subtest("land unit simple actions", function()
  local engine = PT.get_fresh_data()
  local map = engine.gear:get("map")
  local inf = map.tiles[3][3]:get_unit('surface')
  ok(inf)
  is(inf.data.state, 'defending')

  inf:update_actions_map()
  local state = engine.state
  state:set_selected_unit(inf)

  is(inf:is_action_possible('information'), true, "get unit information")
  is(inf:is_action_possible('change_orientation'), true, "can change orientation")
  is(inf:is_action_possible('move',map.tiles[3][6]), true, "can move to tile [3:4]")
  ok(not inf:is_action_possible('move', map.tiles[13][4]), "cannot move to tile [13:4]")
  is(inf:is_action_possible('retreat', map.tiles[3][4]), true, "can retreat tile [3:4]")
  ok(not inf:is_action_possible('retreat', map.tiles[3][6]), "cannot retreat tile [3:6] (too far, but we can move there)")
  ok(not inf:is_action_possible('retreat', map.tiles[13][4]), "cannot retreat to tile [13:4] (too far)")
  ok(not inf:is_action_possible('patrol', map.tiles[3][4]), "cannot patrol tile [3:4] (n/a)")
  ok(not inf:is_action_possible('raid', map.tiles[3][4]), "cannot raid tile [3:4] (n/a)")
  ok(not inf:is_action_possible('attach', map.tiles[3][4]), "can't attach at tile [4:4] (no unit)")
  ok(inf:is_action_possible('attach', map.tiles[4][4]), "can attach at tile [4:4]")
  ok(inf:is_action_possible('refuel'), "can refuel")
end)

subtest("land unit unavailability after moving", function()
  local engine = PT.get_fresh_data()
  local map = engine.gear:get("map")
  local inf = map.tiles[3][3]:get_unit('surface')
  ok(inf:is_action_possible('refuel'), "initially unit can refuel")
  inf:update_actions_map()
  inf:move_to(map.tiles[3][4])
  ok(inf:is_action_possible('refuel'), "still can refuel")
  inf:update_actions_map()
  inf:move_to(map.tiles[3][6])
  ok(not inf:is_action_possible('refuel'), "no more actions, cannot refuel")
end)

subtest("actions for air unit", function()
  local engine = PT.get_fresh_data()
  local map = engine.gear:get("map")
  local fighter = map.tiles[7][7]:get_unit('air')
  ok(fighter)
  fighter:update_actions_map()
  ok(not fighter:is_action_possible('refuel'), "refuel is n/a for air units")
  ok(not fighter:is_action_possible('retreat', map.tiles[8][8]), "retreat is n/a")
  is(fighter:is_action_possible('move', map.tiles[8][8]), true, "can move to tile [8:8]")
end)

subtest("get-possible actions method works", function()
  local engine = PT.get_fresh_data()
  local map = engine.gear:get("map")
  local inf = map.tiles[3][3]:get_unit('surface')
  ok(inf.tile:get_possible_actions(), "got action list")
end)

done_testing()
