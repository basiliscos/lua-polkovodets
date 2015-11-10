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
                      ok(r.e)
                      is(r.e.kind, 'Block')
                      is(r.e.id, '1.1')
                   end
           )

           subtest("simple and",
                   function()
                      local r = bs:_parse_condition("(!block('1.1') && !block('2.2'))")
                      print(inspect(r))
                      ok(r)
                      is(r.kind, 'LogicalRelation')
                      is(r.operator, '&&')
                      is(r.e2.e.id, '2.2')
                   end
           )

           subtest("simple and",
                   function()
                      local r = bs:_parse_condition("(!block('1.1') && !block('2.2'))")
                      print(inspect(r))
                      ok(r)
                      is(r.kind, 'LogicalRelation')
                      is(r.operator, '&&')
                      is(r.e2.e.id, '2.2')
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
        end
)

done_testing()
