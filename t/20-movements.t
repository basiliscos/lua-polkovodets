#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local _ = require ("moses")
local inspect = require('inspect')

local Gear = require "gear"

local Engine = require 'polkovodets.Engine'
local SampleData = require 't.SampleData'

local gear = Gear.create()
local engine = Engine.create(gear, "en")

SampleData.generate_test_data(gear)
SampleData.generate_battle_scheme(gear)
SampleData.generate_map(gear)
SampleData.generate_scenario(gear)
SampleData.generate_terrain(gear)
SampleData.generate_validators(gear)

local scenario = gear:get("scenario")
local map = gear:get("map")
engine:end_turn()

subtest("movement/leg 1 weapon", function()
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

  inf:move_to(map.tiles[3][6])
  is_deeply(inf:available_movement(), {
    ["u:rus_unit_1/w:rus_weapon_1"]  = 0,
  }, "no movement left")
end)

subtest("movement/leg motorized", function()
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
  local art = map.tiles[4][4]:get_unit('surface')
  ok(art)
  art:update_actions_map()
  -- print(inspect(art.data.actions_map.attack))
  is_deeply(art.data.actions_map.attack[map.tiles[5][3].id].surface,
    { ["fire/artillery"] = { "u:rus_unit_3/w:rus_art_1" } },
    "can attack enemy unit before movement"
  )
  art:move_to(map.tiles[5][5])
  is_deeply(art:available_movement(), {
    ["u:rus_unit_3/w:rus_art_1"]  = 0,
  }, "no movement left")
  art:update_actions_map()
  is_deeply(art.data.actions_map.attack, {}, "cannot attack after movement")
end)

done_testing()
