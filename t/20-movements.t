#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local _ = require ("moses")
local inspect = require('inspect')
local PT = require('t.PolkovodetsTest')


subtest("movement/leg 1 weapon", function()
  local engine = PT.get_fresh_data()
  local map = engine.gear:get("map")

  local inf = map.tiles[3][3]:get_unit('surface')
  ok(inf)
  local marched_weapons = inf:_marched_weapons()
  --print(inspect(marched_weapons))
  is(#marched_weapons, 1)
  is(marched_weapons[1].weapon.id, "rus_weapon_1")


  local move_cost = inf:move_cost(map.tiles[4][4])
  -- print(inspect(move_cost))
  ok(move_cost)
  is_deeply(move_cost.data, {
    ["u:rus_unit_1/w:rus_weapon_1"]  = 1,
  })

  local available_movement = inf:available_movement()
  --print(inspect(available_movement))
  is_deeply(available_movement, {
    ["u:rus_unit_1/w:rus_weapon_1"]  = 3,
  })

  inf:update_actions_map()
  --print(inspect(inf.data.actions_map.move))
  ok(not inf.data.actions_map.merge[map.tiles[3][7].id])
  ok(not inf.data.actions_map.merge[map.tiles[5][3].id], "cannot move on the occupied by enemy tile")
  ok(inf.data.actions_map.move[map.tiles[3][6].id])
  ok(inf.data.actions_map.move[map.tiles[3][5].id])
  ok(inf.data.actions_map.move[map.tiles[3][4].id])

  inf:perform_action('move', map.tiles[3][6])
  is_deeply(inf:available_movement(), {
    ["u:rus_unit_1/w:rus_weapon_1"]  = 0,
  }, "no movement left")
  is(inf.data.state, 'marching', 'state changed to marching')
end)

subtest("movement/leg motorized", function()
  local engine = PT.get_fresh_data()
  local map = engine.gear:get("map")

  local inf = map.tiles[4][3]:get_unit('surface')
  ok(inf)
  local marched_weapons = inf:_marched_weapons()
  --print(inspect(marched_weapons))
  is(#marched_weapons, 1)
  is(marched_weapons[1].weapon.id, "rus_trasport_1")

  --print(inspect(inf:available_movement()))
  is_deeply(inf:available_movement(), {
    ["u:rus_unit_2/w:rus_trasport_1"]  = 6,
  }, "no movement left")
  inf:update_actions_map()

  --print(inspect(inf.data.actions_map.move))
  ok(inf.data.actions_map.move[map.tiles[4][9].id])
  ok(not inf.data.actions_map.move[map.tiles[4][10].id])
end)

subtest("movement/attacks first", function()
  local engine = PT.get_fresh_data()
  local map = engine.gear:get("map")

  local art = map.tiles[4][4]:get_unit('surface')
  ok(art)
  art:update_actions_map()
  -- print(inspect(art.data.actions_map.attack))
  is_deeply(art.data.actions_map.attack[map.tiles[5][3].id].surface,
    { ["fire/artillery"] = { "u:rus_unit_3/w:rus_art_1" } },
    "can attack enemy unit before movement"
  )
  art:perform_action('move', map.tiles[5][5])
  is_deeply(art:available_movement(), {
    ["u:rus_unit_3/w:rus_art_1"]  = 0,
  }, "no movement left")
  art:update_actions_map()
  is_deeply(art.data.actions_map.attack, {}, "cannot attack after movement")
end)

subtest("movement/air", function()
  local engine = PT.get_fresh_data()
  local map = engine.gear:get("map")

  local fighter = map.tiles[7][7]:get_unit('air')
  ok(fighter)
  fighter:update_actions_map()

  ok(fighter.data.actions_map.move[map.tiles[7][22].id], "max distance for aircraft is correct")
  ok(not fighter.data.actions_map.move[map.tiles[7][23].id], "max distance for aircraft is correct")

  ok(fighter.data.actions_map.move[map.tiles[4][4].id], "can flight above our units")
  ok(fighter.data.actions_map.move[map.tiles[5][3].id], "as well as enemy units")
end)

subtest("transport problem", function()
  local engine = PT.get_fresh_data()
  local map = engine.gear:get("map")

  local u = map.tiles[5][9]:get_unit('surface')
  ok(u)
  u:update_actions_map()
  -- print(inspect(art.data.actions_map.attack))

  ok(not u.data.actions_map.move[map.tiles[4][5].id], "cannot march too far (no enought transport)")

  local problems = u:report_problems()
  -- print(inspect(problems))
  is(#problems, 1, "unit has 1 problem")
  is(problems[1].class, "transport", "... and it's transport problem")

  local u2 = map.tiles[4][3]:get_unit('surface')
  ok(u2)
  local problems2 = u2:report_problems()
  is(#problems2, 0, "other unit with transport don't have transport problems")

  local u3 = map.tiles[3][3]:get_unit('surface')
  ok(u3)
  local problems3 = u3:report_problems()
  is(#problems3, 0, "non-transporable unit don't have transport problems")

  local u4 = map.tiles[6][9]:get_unit('surface')
  ok(u4)
  local problems4 = u4:report_problems()
  is(#problems4, 1, "unit with transport in unit definition and w/o transport has problems")
  is(problems4[1].class, "missing_weapon", "... but that is missing weapon problem")
end)


subtest("transport for multiple types", function()
    local engine = PT.get_fresh_data()
    local map = engine.gear:get("map")
    local u = map.tiles[32][5]:get_unit('surface')
    ok(u)
    u:update_actions_map();
    local marched_weapons = u:_marched_weapons()
    is(#marched_weapons, 1, "all weapons are packed into transport")
    ok(u.data.actions_map.move[map.tiles[35][4].id], "transport can move far enough")
end)

done_testing()
