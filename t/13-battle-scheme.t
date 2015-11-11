#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'

local inspect = require('inspect')
local Engine = require 'polkovodets.Engine'
local BattleScheme = require 'polkovodets.BattleScheme'

local engine = Engine.create()
local bs = BattleScheme.create(engine)

subtest("parse condition",
        function()
           subtest("negation",
                   function()
                      local r = bs:_parse_condition("!block('1.1')")
                      print(inspect(r))
                      ok(r)
                      is(r.kind, 'Negation')
                      ok(r.expr)
                      is(r.expr.kind, 'Block')
                      is(r.expr.id, '1.1')
                   end
           )
           subtest("do not allow bare block",
                   function()
                      local r = bs:_parse_condition("block('1.3')")
                      nok(r)
                   end
           )


           subtest("simple and",
                   function()
                      local r = bs:_parse_condition("(!block('1.1') && !block('2.2'))")
                      print(inspect(r))
                      ok(r)
                      is(r.kind, 'LogicalOperation')
                      is(r.operator, '&&')
                      is(r.e2.expr.id, '2.2')
                   end
           )

           subtest("simple and",
                   function()
                      local r = bs:_parse_condition("(!block('1.1') && !block('2.2'))")
                      print(inspect(r))
                      ok(r)
                      is(r.kind, 'LogicalOperation')
                      is(r.operator, '&&')
                      is(r.e2.expr.id, '2.2')
                   end
           )

           subtest("orientation eq",
                   function()
                      local r = bs:_parse_condition("I.orientation == P.orientation")
                      print(inspect(r))
                      ok(r)
                      is(r.kind, 'Relation')
                      is(r.v1.object, 'I')
                      is(r.v1.property, 'orientation')
                   end
           )

           subtest("check state",
                   function()
                      local r = bs:_parse_condition("I.state == 'A'")
                      print(inspect(r))
                      ok(r)
                      is(r.kind, 'Relation')
                      is(r.v1.object, 'I')
                      is(r.v1.property, 'state')
                      is(r.v2.kind, 'Literal')
                      is(r.v2.value, 'A')
                   end
           )

           subtest("tripple and",
                   function()
                      local r = bs:_parse_condition("((I.state == 'A' && P.state == 'D') && (I.orientation != P.orientation))")
                      print(inspect(r))
                      ok(r)
                      is(r.kind, 'LogicalOperation')
                      is(r.operator, '&&')
                      is(r.e2.operator, '!=')
                      is(r.e2.v1.object, 'I')
                      is(r.e2.v2.object, 'P')
                   end
           )

           subtest("non-valid cases",
                   function()
                      nok(bs:_parse_condition("I.state == A'"))
                      nok(bs:_parse_condition('I.state == "A"'))
                      nok(bs:_parse_condition("I.state() == 'A'"))
                   end
           )

        end
)

done_testing()
