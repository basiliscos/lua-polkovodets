#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'

local inspect = require('inspect')
local Gear = require "gear"

local Engine = require 'polkovodets.Engine'
local BattleFormula = require 'polkovodets.BattleFormula'
local BattleScheme = require 'polkovodets.BattleScheme'

local gear = Gear.create()
local engine = Engine.create(gear, "en")

local bs = BattleScheme.create()


subtest("parse condition", function()
  subtest("orientation eq", function()
    local r = bs:_parse_condition('I.orientation == P.orientation')
    print(inspect(r))
    ok(r)
    is(r.kind, 'Relation')
    is(r.v1.object, 'I')
    is(r.v1.property, 'orientation')
  end)

  subtest("check state", function()
    local r = bs:_parse_condition('I.state == "A"')
    print(inspect(r))
    ok(r)
    is(r.kind, 'Relation')
    is(r.v1.object, 'I')
    is(r.v1.property, 'state')
    is(r.v2.kind, 'Literal')
    is(r.v2.value, 'A')
  end)

  subtest("tripple and", function()
    -- local r = bs:_parse_condition('(I.state == "A") && (P.state == "D") && (I.orientation != P.orientation)')
    local r = bs:_parse_condition('(I.state == "A") && (P.state == "D") && (I.orientation != P.orientation)')
    print("r == " .. inspect(r))
    ok(r)
    is(r.kind, 'LogicalOperation')
    is(r.operator, '&&')
    is(r.relations[3].operator, '!=')
    is(r.relations[3].v1.object, 'I')
    is(r.relations[3].v2.object, 'P')
  end)

  subtest("non-valid cases", function()
    nok(bs:_parse_condition('I.state == A"'))
    nok(bs:_parse_condition("I.state == 'A'"))
    nok(bs:_parse_condition('I.state() == "A"'))
  end)

end)

subtest("parse selection", function()
  subtest("simple selector", function()
    ok(bs:_parse_selection('I.category("wc_artil")'))
    ok(bs:_parse_selection('!I.category("wc_tank")'))
    ok(bs:_parse_selection('P.category("wc_hweap") && P.category("wc_antitank")'))
    ok(bs:_parse_selection('P.category("wc_hweap") || P.category("wc_antitank")'))
    ok(bs:_parse_selection('I.category("wc_infant") || I.category("wc_hweap") || I.category("wc_antitank")'))
    ok(bs:_parse_selection('P.category("wc_infant") && !P.category("wc_tank")'))
  end)
end)


subtest("blocks", function()
  local condition = bs:_parse_condition("I.orientation == P.orientation")
  assert(condition)
  local b_parent = bs:_create_block('1', 'battle', condition)
  ok(b_parent)
  b_parent:validate()

  local b_child = bs:_create_block('1.1', nil,
    bs:_parse_condition('I.category("wc_artil")'),
    bs:_parse_condition('P.category("wc_hweap") || P.category("wc_antitank")'),
    'fire'
  )
  ok(b_child)
  b_child:validate()
end)

subtest("initialization", function()
  gear:set("data/battle_blocks", {
    { block_id = "1", fire_type = "battle", condition = '(I.state == "attacking") && (P.state == "defending")'},
    { block_id = "1.1", active_weapon = 'I.category("wc_infant")', passive_weapon = 'P.target("any")', action = "battle" },
  })

  local bs2 = gear:get("battle_scheme")
  ok(bs2)
end)

done_testing()
