local stdlib = require 'posix.stdlib'
local unistd = require 'posix.unistd'

local SDL = require "SDL"
local image = require "SDL.image"

local Engine = require 'polkovodets.Engine'
local Map = require 'polkovodets.Map'

assert(SDL.init({
			 SDL.flags.Video,
			 SDL.flags.Audio
}))

print(string.format("SDL %d.%d.%d",
    SDL.VERSION_MAJOR,
    SDL.VERSION_MINOR,
    SDL.VERSION_PATCH
))

local win, err = SDL.createWindow {
   title   = "02 - Opening a window",
   width   = 640,
   height  = 480,
   flags   = { SDL.window.Resizable },
}

assert(win, err)

-- Create the renderer
local renderer, err = SDL.createRenderer(win, -1)
assert(renderer, err)
renderer:setDrawColor(0xFFFFFF)

-- Load the image as a surface
local image, err = image.load("data/gfx/title.png")
assert(image, err)

local title, err = renderer:createTextureFromSurface(image)

local f,a,w,h = title:query()
print("w = " .. w .. ", h = " .. h)

win:setSize(w,h)

renderer:clear()
renderer:copy(title)
renderer:present()

local engine = Engine.create()
local map = Map.create(engine)
map:load('map01')
engine:set_map(map)
engine:draw_map()

unistd.sleep(1)

SDL.quit()
print("normal exit from main.lua")

