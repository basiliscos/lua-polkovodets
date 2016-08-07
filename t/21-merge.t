#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local _ = require ("moses")
local inspect = require('inspect')
local PT = require('t.PolkovodetsTest')


subtest("mergability", function()
  local engine = PT.get_fresh_data()
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
  local engine = PT.get_fresh_data()
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

subtest("non-mergable: land and air units", function()
  local engine = PT.get_fresh_data()
  local map = engine.gear:get("map")

  local tank1_m = map.tiles[4][2]:get_unit('surface')
  local fighter = map.tiles[7][7]:get_unit('air')

  fighter:update_actions_map()
  ok(not fighter.data.actions_map.merge[tank1_m.tile.id], "s-fighter non-mergeable with m-tank" )
  fighter:move_to(map.tiles[3][2])
  fighter:update_actions_map()
  tank1_m:update_actions_map()

  ok(not fighter.data.actions_map.merge[tank1_m.tile.id], "even if we flight close" )
  ok(not tank1_m.data.actions_map.merge[fighter.tile.id], "the same for tank" )
end)

subtest("non-mergable: manager and manageable units", function()
  local engine = PT.get_fresh_data()
  local map = engine.gear:get("map")

  local tank1_m = map.tiles[4][2]:get_unit('surface')
  local hq = map.tiles[6][5]:get_unit('surface')
  hq:update_actions_map()

  tank1_m:update_actions_map()
  tank1_m:move_to(map.tiles[5][6])
  tank1_m:update_actions_map()

  ok(not hq.data.actions_map.merge[tank1_m.tile.id], "hq isn't mergeable with tank" )
  ok(not tank1_m.data.actions_map.merge[hq.tile.id], "the same for tank" )
end)


done_testing()
