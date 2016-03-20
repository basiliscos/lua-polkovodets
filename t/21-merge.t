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


subtest("mergability", function()
  local engine = get_fresh_data()
  local map = engine.gear:get("map")

  local inf1_l  = map.tiles[3][3]:get_unit('surface')
  local inf2_l  = map.tiles[4][3]:get_unit('surface')
  local art1_s  = map.tiles[4][4]:get_unit('surface')
  local art2_s  = map.tiles[3][5]:get_unit('surface')
  local tank1_m = map.tiles[4][2]:get_unit('surface')

  inf1_l:update_actions_map()
  inf2_l:update_actions_map()
  art1_s:update_actions_map()
  art2_s:update_actions_map()
  tank1_m:update_actions_map()

  ok(not inf1_l.data.actions_map.merge[inf2_l.tile.id], "same sized units can't merge")
  ok(not inf1_l.data.actions_map.merge[inf2_l.tile.id], "same sized units can't merge")
  ok(not art1_s.data.actions_map.merge[art2_s.tile.id], "same sized units can't merge")
  ok(not inf2_l.data.actions_map.merge[inf1_l.tile.id], "cant merge with self")

  -- print(inspect(inf2_l.data.actions_map.merge))
  ok(inf2_l.data.actions_map.merge[art1_s.tile.id], "large unit mergeable with small")
  ok(art1_s.data.actions_map.merge[inf2_l.tile.id], "small unit mergeable with large")

  ok(tank1_m.data.actions_map.merge[inf2_l.tile.id], "medium unit mergeable with large")
  ok(tank1_m.data.actions_map.merge[art1_s.tile.id], "medium unit mergeable with small")
end)

subtest("merge: l + m + s", function()
  local engine = get_fresh_data()
  local map = engine.gear:get("map")

  local inf1_l  = map.tiles[4][3]:get_unit('surface')
  local art1_s  = map.tiles[4][4]:get_unit('surface')
  local art2_s  = map.tiles[3][5]:get_unit('surface')
  local tank1_m = map.tiles[4][2]:get_unit('surface')

  inf1_l:update_actions_map()
  art1_s:update_actions_map()
  tank1_m:update_actions_map()

  tank1_m:merge_at(inf1_l.tile)
  is(map.tiles[4][3]:get_unit('surface'), inf1_l, "M-unit joins to L-unit")
  ok(not map.tiles[4][2]:get_unit('surface'), "M-unit disappears from map after merge")
  inf1_l:update_actions_map()
  ok(inf1_l.data.actions_map.move[map.tiles[4][2].id], "can move to initial tank position")


  art1_s:merge_at(inf1_l.tile)
  is(map.tiles[4][3]:get_unit('surface'), inf1_l, "S-unit joins to L-unit")
  ok(not map.tiles[4][4]:get_unit('surface'), "s-unit disappears from map after merge")
  is(#inf1_l.data.attached, 2, "valid number of attache units")

  inf1_l:update_actions_map()
  ok(not inf1_l.data.actions_map.move[map.tiles[4][2].id], "cannot move (no more movements in the attached artillery)")

  art2_s:update_actions_map()
  art2_s:move_to(map.tiles[3][4])

  engine:end_turn()
  engine:end_turn()
  art2_s:update_actions_map()
  ok(not art2_s.data.actions_map.merge[inf1_l.tile.id], "small unit mergeable with large, because 2 units are already attached")

end)

done_testing()
