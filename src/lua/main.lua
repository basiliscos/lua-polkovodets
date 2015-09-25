local SDL = require "SDL"
local image = require "SDL.image"

local Engine = require 'polkovodets.Engine'
local Map = require 'polkovodets.Map'
local Renderer = require 'polkovodets.Renderer'
local Scenario = require 'polkovodets.Scenario'

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
engine:set_renderer(gui_renderer)

local scenario = Scenario.create(engine)
scenario:load('pg/Poland')

gui_renderer:main_loop()

SDL.quit()
print("normal exit from main.lua")

