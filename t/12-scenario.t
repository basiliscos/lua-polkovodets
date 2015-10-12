#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local inspect = require('inspect')


local Scenario = require 'polkovodets.Scenario'
local Engine = require 'polkovodets.Engine'
local DummyRenderer = require 't.DummyRenderer'

local engine = Engine.create()
engine:set_renderer(DummyRenderer.create(640, 480))

local scenario = Scenario.create(engine)
scenario:load('Test')
ok(engine:get_scenario())
ok(engine:get_map())

-- is(scenario.turns, 10)
local map = engine:get_map()
local berlin = map.tiles[2+1][4+1]
ok(berlin.data.nation)
is(berlin.data.nation.data.name, "Deutschland")

ok(engine.unit_lib)
ok(engine.unit_lib.units.definitions)

-- no requnired units on the map
-- local unit_rus_art = map.tiles[7][5].unit
-- ok(unit_rus_art)
-- is(unit_rus_art:available_movement(), 1)

-- local unit_rus_inf = map.tiles[8][5].unit
-- ok(unit_rus_inf)
-- is(unit_rus_inf:available_movement(), 3)

-- local unit_rus_tank = map.tiles[8][4].unit
-- ok(unit_rus_tank)
-- is(unit_rus_tank:available_movement(), 6)

-- local tile_83 = map.tiles[8][3]
-- unit_rus_tank:update_actions_map()
-- is(unit_rus_tank:available_movement(), 6)
-- is(unit_rus_tank.data.fuel, 55)
-- unit_rus_tank:move_to(tile_83)
-- is(unit_rus_tank:available_movement(), 0)
-- is(unit_rus_tank.data.fuel, 54)
-- engine:end_turn()

-- is(unit_rus_tank:available_movement(), 6)
-- unit_rus_tank:update_actions_map()
-- unit_rus_tank:move_to(map.tiles[4][6])
-- engine:end_turn()
-- unit_rus_tank:update_actions_map()

-- subtest("tank actions",
--         function()
--            local actions_map = unit_rus_tank.data.actions_map
--            ok(actions_map.move[map.tiles[3][6].uniq_id])
--            ok(actions_map.move[map.tiles[9][3].uniq_id])
--            ok(not actions_map.move[map.tiles[2][4].uniq_id])
--            ok(not actions_map.move[map.tiles[2][5].uniq_id])
--            ok(not actions_map.move[map.tiles[2][6].uniq_id])
--            ok(not actions_map.move[map.tiles[4][8].uniq_id])

--            ok(actions_map.attack[map.tiles[3][7].uniq_id])
--            ok(actions_map.attack[map.tiles[4][7].uniq_id])
--            ok(not actions_map.attack[map.tiles[3][6].uniq_id])
--            ok(not actions_map.attack[map.tiles[3][5].uniq_id])
--         end
-- )


done_testing()
