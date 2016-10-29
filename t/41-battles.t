#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local _ = require ("moses")
local inspect = require('inspect')
local PT = require('t.PolkovodetsTest')

-- always the same results
math.randomseed(0)

subtest("simple shot 250 vs 30 infantry units", function()
    local engine = PT.get_fresh_data()
    local map = engine.gear:get("map")
    local ru_1 = map.tiles[4][3]:get_unit('surface')
    ok(ru_1)
    ru_1:update_actions_map();
    ru_1:perform_action('attack', {map.tiles[5][3]})

    local record = (engine.state:get_actual_records())[1]
    print(inspect(record.results))

    is(record.results.i.participants["u:rus_unit_2/w:rus_trasport_1"], 300);
    is(record.results.i.participants["u:rus_unit_2/w:rus_weapon_1"], 250);
    is(record.results.i.casualities["u:rus_unit_2/w:rus_trasport_1"], 0, "transport does not participate");

    is(record.results.p.participants["u:ger_unit_1/w:ger_weapon_1"], 30);
    ok(record.results.p.casualities["u:ger_unit_1/w:ger_weapon_1"] > 0, "somebody from enemies should be killed");
end)

done_testing()
