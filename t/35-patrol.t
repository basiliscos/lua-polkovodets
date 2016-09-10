#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local _ = require ("moses")
local inspect = require('inspect')
local PT = require('t.PolkovodetsTest')


subtest("patrol attacks patrol: attack & defend switch", function()
    local engine = PT.get_fresh_data()
    local map = engine.gear:get("map")

    local inf_ru_aux = map.tiles[4][3]:get_unit('surface')
    inf_ru_aux:update_actions_map()
    inf_ru_aux:perform_action('move', map.tiles[3][6])

    local inf_ru = map.tiles[3][3]:get_unit('surface')
    inf_ru:update_actions_map()
    is(inf_ru:is_action_possible('patrol', map.tiles[4][3]), true, "can patrol tile [3:4]")
    inf_ru:perform_action('patrol', map.tiles[4][3])
    engine:end_turn()

    local inf_ger = map.tiles[5][3]:get_unit('surface')
    inf_ger:update_actions_map()
    inf_ger:perform_action('patrol', map.tiles[5][4])
    engine:end_turn()

    inf_ru:update_actions_map()
    is(inf_ru.data.state, 'patrolling')
    is(inf_ger.data.state, 'patrolling')
    ok(inf_ru:is_action_possible('attack', {map.tiles[5][4], 'surface', 'battle'}), "can attack enemy patrolling unit")

    inf_ru:perform_action('attack', {map.tiles[5][4], 'battle'})
    is(inf_ru.data.state, 'attacking')
    is(inf_ger.data.state, 'defending')

end)

done_testing()
