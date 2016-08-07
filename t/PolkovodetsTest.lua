local PolkovodetsTest = {}
PolkovodetsTest.__index = PolkovodetsTest

local DummyRenderer = require 't.DummyRenderer'

local Gear = require "gear"

local Engine = require 'polkovodets.Engine'
local SampleData = require 'polkovodets.SampleData'


function PolkovodetsTest.get_fresh_data()
  local gear = Gear.create()
  gear:declare("renderer", { constructor = function() return DummyRenderer.create(640, 480) end})
  local engine = Engine.create(gear, "en")

  SampleData.generate_test_data(gear)
  SampleData.generate_battle_scheme(gear)
  SampleData.generate_map(gear)
  SampleData.generate_scenario(gear)
  SampleData.generate_terrain(gear)

  gear:get("validator").fn()
  local scenario = gear:get("scenario")
  local map = gear:get("map")
  engine:end_turn()

  return engine
end


return PolkovodetsTest
