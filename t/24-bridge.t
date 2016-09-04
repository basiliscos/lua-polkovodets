#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local _ = require ("moses")
local inspect = require('inspect')
local PT = require('t.PolkovodetsTest')

subtest("auto-bringing on moving engenerrunit to rivlet", function()
  local engine = PT.get_fresh_data()
  local map = engine.gear:get("map")

  local engineers = map.tiles[5][13]:get_unit('surface')
  ok(engineers)

  engineers:update_actions_map()
  ok(not engineers:is_action_possible('bridge', map.tiles[5][12]), "cannot do bridge on non-river")
  ok(engineers:is_action_possible('bridge', map.tiles[6][12]), "can move do bridge on rivelet")
  engineers:perform_action('bridge', map.tiles[6][12])
  is(engineers.data.state, 'bridging', "engineers started doing bridge over rivelet")
end)

subtest("auto-bringing on moving engenerrunit to rivlet", function()
  local engine = PT.get_fresh_data()
  local map = engine.gear:get("map")

  local engineers = map.tiles[5][13]:get_unit('surface')
  ok(engineers)

  engineers:update_actions_map()
  ok(engineers:is_action_possible('bridge', map.tiles[6][12]), "can move do bridge on river")
  engineers:perform_action('bridge', map.tiles[6][12])
  is(engineers.data.state, 'bridging', "engineers started doing bridge over river")
end)


done_testing()
