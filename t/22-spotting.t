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


subtest("air spotting area", function()
  local engine = get_fresh_data()
  local map = engine.gear:get("map")

  local aircraft = map.tiles[7][7]:get_unit('air')
  ok(aircraft)
  is(aircraft.definition.spotting, 3)

  aircraft:update_spotting_map()
  ok(aircraft.data.spotting_map[aircraft.tile.id], "sees in the tile, where it is located")
  ok(aircraft.data.spotting_map[map.tiles[7][10].id], "sees in +3 tiles radius")
  ok(not aircraft.data.spotting_map[map.tiles[7][11].id], "but not sees in +4 tiles radius")
  ok(aircraft.data.spotting_map[map.tiles[10][5].id], "sees in +3 tiles radius, ignoring type of terrain")
  ok(aircraft.data.spotting_map[map.tiles[10][6].id], "sees in +3 tiles radius, ignoring type of terrain")
end)

subtest("land spotting area", function()
  local engine = get_fresh_data()
  local map = engine.gear:get("map")

  local tank = map.tiles[7][8]:get_unit('surface')
  ok(tank)
  is(tank.definition.spotting, 2)

  tank:update_spotting_map()
  ok(tank.data.spotting_map[tank.tile.id], "sees in the tile, where it is located")
  ok(tank.data.spotting_map[map.tiles[5][7].id], "sees in +2 tiles radius")
  ok(not tank.data.spotting_map[map.tiles[4][6].id], "but not sees in +3 tiles radius")
  ok(tank.data.spotting_map[map.tiles[8][7].id], "tank see s adjascent forest tile")
  ok(not tank.data.spotting_map[map.tiles[9][7].id], "tank can't see too far through the forest")
end)

subtest("map united spotting", function()
  local engine = get_fresh_data()
  local map = engine.gear:get("map")
  is(engine.state:get_current_player().id, "allies")
  ok(map.united_spotting.map[map.tiles[2][6].id])
  ok(map.united_spotting.map[map.tiles[9][4].id])
  ok(map.united_spotting.map[map.tiles[10][8].id])
  ok(not map.united_spotting.map[map.tiles[2][7].id])

  local axis_inf = map.tiles[5][3]:get_unit('surface')
  ok(axis_inf)
  ok(axis_inf.data.visible_to_current_player)

  engine:end_turn()
  is(engine.state:get_current_player().id, "axis")
  ok(map.united_spotting.map[map.tiles[7][2].id])
  ok(map.united_spotting.map[map.tiles[5][5].id])
  ok(map.united_spotting.map[map.tiles[3][4].id])
  ok(not map.united_spotting.map[map.tiles[5][6].id])
  ok(not map.united_spotting.map[map.tiles[3][5].id])

  local allied_art = map.tiles[3][5]:get_unit('surface')
  ok(allied_art)
  ok(not allied_art.data.visible_to_current_player)
  ok(map.tiles[4][3]:get_unit('surface').data.visible_to_current_player)

  engine:end_turn()
  local aircraft = map.tiles[7][7]:get_unit('air')
  ok(aircraft)
  aircraft:update_actions_map()
  aircraft:move_to(map.tiles[2][8])
  ok(map.united_spotting.map[map.tiles[2][7].id], "now tile 2:7 is visible by aircraft")
end)

subtest("map spotting on unit movement", function()
  local engine = get_fresh_data()
  local map = engine.gear:get("map")

  ok(not map.tiles[11][5]:get_unit('surface').data.visible_to_current_player,
    "nobody sees german infantry beyond the forest")

  local aircraft = map.tiles[7][7]:get_unit('air')
  ok(aircraft)
  aircraft:update_actions_map()
  aircraft:move_to(map.tiles[9][5])
  ok(map.tiles[11][5]:get_unit('surface').data.visible_to_current_player,
    "not the german infantry is visible")

  aircraft:update_actions_map()
  aircraft:move_to(map.tiles[3][7])
  ok(map.tiles[11][5]:get_unit('surface').data.visible_to_current_player,
    "the german infantry is still visible, even if it is out of the united spot")

end)

done_testing()
