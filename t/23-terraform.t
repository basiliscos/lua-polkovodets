#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local _ = require ("moses")
local inspect = require('inspect')
local PT = require('t.PolkovodetsTest')

subtest("reconstruct town from destroyed town", function()
  local engine = PT.get_fresh_data()
  local map = engine.gear:get("map")

  engine:end_turn()

  local burned_city = map.tiles[9][10]

  local engineers = map.tiles[9][11]:get_unit('surface')
  ok(engineers)

  engineers:update_actions_map()
  is_deeply(engineers.data.actions_map.special, {},
    "the ruined town is too far")
  engineers:move_to(burned_city)

  engineers:update_actions_map()
  is(burned_city.data.terrain_type.id, 'T', "burned city before rebuild")
  is(#engineers.data.actions_map.special[burned_city.id].build, 1,
    "engineers can reconstruct burned town, where they are located"
  )

  is(burned_city.data.terrain_type.id, 'T', "burned city remains, not enought efforts has been spent")
  engineers:update_actions_map()
  engineers:special_action(burned_city, 'build')

  is_deeply(engineers.data.actions_map.special, {},
    "no more actions in this turn")

  engine:end_turn()
  engine:end_turn()
  engineers:update_actions_map()
  engineers:special_action(burned_city, 'build')

  is(burned_city.data.terrain_type.id, 't', "city is finally after rebuild")

end)

done_testing()
