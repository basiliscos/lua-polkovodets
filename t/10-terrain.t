#!/usr/bin/env lua

package.path = "t/?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'

local Terrain = require 'polkovodets.Terrain'
local Engine = require 'polkovodets.Engine'

local engine = Engine.create()
local terrain = Terrain.create(engine)
ok(terrain)
terrain:load('pg.tdb')

local clear = terrain:get_type('c')
ok(clear)
is(clear.move_cost.air.I, "1")

done_testing();	
