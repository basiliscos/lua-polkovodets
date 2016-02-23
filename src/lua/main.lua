--[[

Copyright (C) 2015 Ivan Baidakou

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

local SDL = require "SDL"
local image = require "SDL.image"

local Engine = require 'polkovodets.Engine'
local Map = require 'polkovodets.Map'
local Renderer = require 'polkovodets.Renderer'
local Scenario = require 'polkovodets.Scenario'

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

local engine = Engine.create()
local gui_renderer = Renderer.create(engine, window, renderer)

local scenario = Scenario.create(engine)
scenario:load('Test3')

gui_renderer:prepare_drawers()
gui_renderer:main_loop()

SDL.quit()
print("normal exit from main.lua")
