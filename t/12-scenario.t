#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local _ = require ("moses")
local inspect = require('inspect')


local Scenario = require 'polkovodets.Scenario'
local Engine = require 'polkovodets.Engine'
local DummyRenderer = require 't.DummyRenderer'

local engine = Engine.create()
DummyRenderer.create(engine, 640, 480)

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

subtest("move rus infantry",
        function()
           local inf = map.tiles[8][4]:get_unit('surface')
           ok(inf)
           local marched_weapons = inf:_marched_weapons()
           ok(marched_weapons)
           is(#marched_weapons, 7)
           local types = _.sort(_.map(marched_weapons, function(k, v) return v.weapon.weapon_type end))
           -- print(inspect(types))
           is_deeply(
              types,
              {
                 "wt_MG",
                 "wt_antitankRifl",
                 "wt_infant",
                 "wt_minBn",
                 "wt_minComp",
                 "wt_tankInfMid",
                 "wt_tractorL"
              }
           )
           local move_cost = inf:move_cost(map.tiles[7][4])
           -- print(inspect(move_cost))
           ok(move_cost)
           is_deeply(move_cost.data,
                     {
                        ["1:1"]  = 1,
                        ["1:14"] = 1,
                        ["1:18"] = 1,
                        ["1:2"]  = 1,
                        ["1:3"]  = 1,
                        ["1:4"]  = 1,
                        ["1:5"]  = 1,
                     },
                     "move cost to 7:4 is correct"
           )
           local available_movement = inf:available_movement()
           -- print(inspect(available_movement))
           ok(available_movement)
           is_deeply(available_movement,
                     {
                        ["1:1"]  = 5,
                        ["1:14"] = 3,
                        ["1:18"] = 4,
                        ["1:2"]  = 3,
                        ["1:3"]  = 3,
                        ["1:4"]  = 3,
                        ["1:5"]  = 3,
                     },
                     "available movements are correct"
           )
           inf:update_actions_map()
           -- print(inspect(inf.data.actions_map.move))
           ok(inf.data.actions_map.move[map.tiles[5][4].uniq_id])
           ok(inf.data.actions_map.move[map.tiles[9][7].uniq_id])
           ok(inf.data.actions_map.merge[map.tiles[8][5].uniq_id])
        end
)

subtest("move rus aircraft",
        function()
           local aircraft = map.tiles[9][7]:get_unit('surface')
           ok(aircraft)
           is(aircraft:get_layer(), 'surface')
           aircraft:update_actions_map()

           local enemy_tank = map.tiles[4][9]:get_unit('surface')
           ok(enemy_tank)
           ok(aircraft.data.actions_map.move[map.tiles[4][9].uniq_id])

           aircraft:move_to(map.tiles[4][9])
           print(inspect(aircraft.data.actions_map.attack))
           is_deeply(aircraft.data.actions_map.attack[map.tiles[4][9].uniq_id],
                     {
                        surface = {
                           ["fire/bombing"] = { "15:37", "15:38" }
                        }
                     }
           )

           local rus_at = map.tiles[5][9]:get_unit('surface')
           ok(rus_at)
           rus_at:update_actions_map()
           print(inspect(rus_at.data.actions_map.attack))
           is_deeply(rus_at.data.actions_map.attack[map.tiles[4][9].uniq_id],
                     {
                        surface = {
                            battle = { "7:17" }
                        }
                     }
           )
           rus_at:move_to(map.tiles[4][8])
           is(rus_at.data.state, 'defending')

           local ger_artillery = map.tiles[4][7]:get_unit('surface')
           ok(ger_artillery)
           ger_artillery:update_actions_map()
           print(inspect(ger_artillery.data.actions_map.attack))
           is_deeply(ger_artillery.data.actions_map.attack[map.tiles[4][8].uniq_id],
                     {
                        surface = {
                           battle = { "5:27", "5:28", "5:29" },
                           ["fire/artillery"] = { "5:27", "5:28", "5:29" }
                        }
                     }
           )
           is(ger_artillery:get_attack_kind(map.tiles[4][8]), 'fire/artillery')

           ger_artillery:switch_attack_priorities()
           is(ger_artillery:get_attack_kind(map.tiles[4][8]), 'fire/artillery')
           ger_artillery:switch_attack_priorities()
           is(ger_artillery:get_attack_kind(map.tiles[4][8]), 'battle')
           ger_artillery:switch_attack_priorities()
           is(ger_artillery:get_attack_kind(map.tiles[4][8]), 'fire/artillery')

        end
)


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
