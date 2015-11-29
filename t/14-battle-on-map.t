#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local _ = require ("moses")
local inspect = require('inspect')


local Scenario = require 'polkovodets.Scenario'
local Engine = require 'polkovodets.Engine'
local DummyRenderer = require 't.DummyRenderer'
local BattleScheme = require 'polkovodets.BattleScheme'


local get_fresh_map = function()
  local engine = Engine.create()
  DummyRenderer.create(engine, 640, 480)

  local scenario = Scenario.create(engine)
  scenario:load('Test')

  return engine:get_map()
end

subtest("german tank vs russian AT",
  function()
    local map = get_fresh_map()
    local bs = map.engine.battle_scheme

    local rus_at = map.tiles[5][9]:get_unit('surface')
    ok(rus_at)
    rus_at:update_actions_map()
    is_deeply(rus_at.data.actions_map.attack[map.tiles[4][9].id],
      {
        surface = {
          battle = { "u:7/w:17" }
        }
      }
    )
    local ger_tank = map.tiles[4][9]:get_unit('surface')
    ger_tank:update_actions_map()
    ok(ger_tank)
    ger_tank:attack_on(rus_at.tile, 'battle')
    is(rus_at.data.state, 'dead')
    isnt(ger_tank.data.state, 'dead')
  end
)

subtest("german tank vs russian tank",
  function()
    local map = get_fresh_map()
    local bs = map.engine.battle_scheme

    local rus_tank = map.tiles[6][9]:get_unit('surface')
    ok(rus_tank)
    rus_tank:update_actions_map()
    rus_tank:move_to(map.tiles[5][10])
    is(rus_tank.data.state, 'defending')

    local ger_tank = map.tiles[4][9]:get_unit('surface')
    ger_tank:update_actions_map()
    ok(ger_tank)
    local ger_deaths, rus_deaths = bs:perform_battle(ger_tank, rus_tank, 'battle')
  end
)

subtest("german tank vs russian Tank+AT",
  function()
    local map = get_fresh_map()
    local bs = map.engine.battle_scheme

    local rus_at = map.tiles[5][9]:get_unit('surface')
    ok(rus_at)
    rus_at:update_actions_map()

    local rus_tank = map.tiles[6][9]:get_unit('surface')
    ok(rus_tank)
    rus_tank:update_actions_map()
    rus_tank:merge_at(map.tiles[5][9])
    is(rus_tank.data.state, 'defending')

    local ger_tank = map.tiles[4][9]:get_unit('surface')
    ger_tank:update_actions_map()
    ok(ger_tank)
    local ger_deaths, rus_deaths = bs:perform_battle(ger_tank, rus_tank, 'battle')
   end
)

done_testing()
