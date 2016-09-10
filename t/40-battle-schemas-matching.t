#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local _ = require ("moses")
local inspect = require('inspect')
local PT = require('t.PolkovodetsTest')


subtest("patrol attacks patrol: attack & defend switch", function()
    local engine = PT.get_fresh_data()
    local map = engine.gear:get("map")

    local inf_ru = map.tiles[4][3]:get_unit('surface')
    inf_ru:update_actions_map()
    inf_ru:perform_action('change_orientation')

    engine:end_turn()

    local inf_ger = map.tiles[5][3]:get_unit('surface')
    inf_ger.data.state = 'attacking'
    inf_ger:update_actions_map()

    local bs = engine.gear:get("battle_scheme")
    local block = bs:_find_block(inf_ger, inf_ru, 'battle')
    ok(block, "block found")
    is(block.id, '1')

end)

done_testing()
