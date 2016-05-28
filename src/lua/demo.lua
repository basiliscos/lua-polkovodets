--[[

Copyright (C) 2016 Ivan Baidakou

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

]]--

local _ = require ("moses")
local SDL = require "SDL"
local image = require "SDL.image"

local Gear = require "gear"

local Engine = require 'polkovodets.Engine'
local Renderer = require 'polkovodets.Renderer'

local SampleData = require 'polkovodets.SampleData'

math.randomseed( os.time() )

assert(SDL.init({
			 SDL.flags.Video,
			 SDL.flags.Audio
}))

print(string.format("SDL %d.%d.%d",
    SDL.VERSION_MAJOR,
    SDL.VERSION_MINOR,
    SDL.VERSION_PATCH
))

local w,h = 640, 480

local window, err = SDL.createWindow {
   title   = "Полководец",
   width   = w,
   height  = h,
   flags   = { SDL.window.Resizable },
}

assert(window, err)

-- Create the renderer
local renderer, err = SDL.createRenderer(window, -1)
assert(renderer, err)

local gear = Gear.create()
local engine = Engine.create(gear, "ru")

gear:declare("renderer", {
  constructor = function() return Renderer.create(engine, window, renderer) end
})

SampleData.generate_battle_scheme(gear)
SampleData.generate_map(gear)
SampleData.generate_scenario(gear)
SampleData.generate_terrain(gear)

local validator = gear:get("validator")
validator.fn()
local scenario = gear:get("scenario")
engine:end_turn()
local gui_renderer = gear:get("renderer")

local component_names = {}
for k, _ in pairs(gear.components) do table.insert(component_names, k) end
table.sort(component_names)
for _, name in pairs(component_names) do
  print("[component] " .. name)
end

gui_renderer:prepare_drawers()
gui_renderer:main_loop()

SDL.quit()
print("normal exit from main.lua")
