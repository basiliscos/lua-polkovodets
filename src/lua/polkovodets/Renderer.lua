--[[

Copyright (C) 2015,2016 Ivan Baidakou

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

local Renderer = {}
Renderer.__index = Renderer

local _ = require ("moses")
local SDL	= require "SDL"
local image = require "SDL.image"
local inspect = require('inspect')
local ttf = require "SDL.ttf"

local Image = require 'polkovodets.utils.Image'
local OrderedHandlers = require 'polkovodets.utils.OrderedHandlers'
local Interface = require 'polkovodets.Interface'
local Tile = require 'polkovodets.Tile'

local EVENT_DELAY = 200

function Renderer.create(engine, window, sdl_renderer)
  assert(ttf.init())
  local o = {
    size           = table.pack(window:getSize()),
    current_cursor = 0,
    engine         = engine,
    window         = window,
    sdl_renderer   = sdl_renderer,
    draw_function  = nil,
    textures_cache = {},
    resources      = {},
    fonts          = {},
    handlers       = {
      mouse_click = OrderedHandlers.new(),
      mouse_move  = OrderedHandlers.new(),
      idle        = OrderedHandlers.new(),
    },
  }
  -- hide system mouse pointer
  assert(SDL.showCursor(false))
  setmetatable(o, Renderer)
  return o
end


function Renderer:get_size()
   return table.unpack(self.size)
end


function Renderer:_load_image(path)
   local surface = assert(image.load(path), "error loading image " .. path)
   if (string.find(path, '.bmp', nil, true)) then
      assert(surface:setColorKey(1, 0x0))
   end
   return surface
end


function Renderer:add_handler(event_type, cb)
  assert(cb)
  local handlers = assert(self.handlers[event_type], "handlers for " .. event_type .. " is n/a")
  handlers:insert(cb)
  -- print(string.format("added handler for %s: %s ", event_type, cb))
end

function Renderer:remove_handler(event_type, cb)
  assert(cb, "cannot non-defined callback for " .. event_type)
  local handlers = assert(self.handlers[event_type], "event " .. event_type .. " cannot be handled")
  handlers:remove(cb)
  -- print(string.format("removed handler for %s: %s ", event_type, cb))
end


function Renderer:load_joint_texture(path, iterator_factory)
   local textures_cache = self.textures_cache
   if (textures_cache[path]) then return end

   local surface = self:_load_image(path)

   local cache = {}
   local iterator = iterator_factory(surface)
   for rectangle in iterator() do
      -- print("rectangle: " .. inspect(rectangle))
      local sub_surface = assert(SDL.createRGBSurface(rectangle.w, rectangle.h))
      assert(surface:blit(sub_surface, rectangle));
      local my_image = Image.create(self.sdl_renderer, sub_surface)
      table.insert(cache, my_image)
   end
   print(path .. ": " .. #cache .. " images")
   textures_cache[path] = cache
end


function Renderer:create_simple_iterator(surface, x_advance, y_advance)
   local w,h = surface:getSize()
   local frame_w, frame_h
   if (x_advance > 0) then
      assert( w % x_advance == 0, "surface width " .. w .. " must be divisable to " .. x_advance)
      frame_w = x_advance
      frame_h = h
   else
      assert( h % y_advance == 0, "surface height " .. h .. " must be divisable to " .. y_advance)
      frame_w = w
      frame_h = y_advance
   end
   local frame = {x = -x_advance, y = -y_advance, w = frame_w, h = frame_h}
   local iterator = function(state, value) -- all values are unused
      if (frame.x < w and frame.y < h) then
         frame.x = frame.x + x_advance
         frame.y = frame.y + y_advance
         return frame
      end
   end
   return function() return iterator, nil, frame end
end

function Renderer:get_joint_texture(path, index)
   assert(index, "texture index should be defined")
   local textures = self.textures_cache[path]
   --print(inspect(textures))
   assert(textures, "texture " .. path .. " wasn't loaded")
   assert(type(textures) == 'table', path .. " isn't joint image")
   local texture = textures[index]
   if (not texture) then
      print("no " .. index .. "-th texture at " .. path .. ", using 1st")
      texture = textures[1]
   end
   return texture;
end


function Renderer:load_texture(path)
   local textures_cache = self.textures_cache
   if (textures_cache[path] ) then
	  return textures_cache[path]
   end
   local surface = self:_load_image(path)
   local my_image = Image.create(self.sdl_renderer, surface)
   textures_cache[path] = my_image
   return my_image
end


function Renderer:prepare_drawers()
  local engine = self.engine

  local context = {
    renderer      = self,
    state         = engine.state,
    events_source = {
      add_handler    = function(event_type, cb) return self:add_handler(event_type, cb) end,
      remove_handler = function(event_type, cb) return self:remove_handler(event_type, cb) end,
    },
  }
  local interface = Interface.create(engine)

  local drawers = {
    engine.gear:get("map"),
    interface,
  }

  -- full.refresh handler
  engine.reactor:subscribe("full.refresh", function()

    print("full.refresh")
    _.each(drawers, function(k, v) v:unbind_ctx(context) end)

    local mouse_state, x, y = SDL.getMouseState()
    context.state:set_mouse(x, y)

    _.each(drawers, function(k, v) v:bind_ctx(context) end)
  end)

  -- create draw function
  self.draw_function = function()
    -- print("d = " .. #drawers)
    _.each(drawers, function(k, v) v:draw() end)
  end

  -- do initial bind
  _.each(drawers, function(k, v) v:bind_ctx(context) end)

  -- fire event to prepare all drawers
  engine.reactor:publish("full.refresh")
end

function Renderer:ttf(font_path, size)
  return assert(ttf.open(font_path, size))
end

function Renderer:main_loop()
  local engine = self.engine
  engine.reactor:mask_events(true)
  local running = true
  local sdl_renderer = self.sdl_renderer
  local kind = SDL.eventWindow

  local fn_idle = function()
    local state, x, y = SDL.getMouseState()
    local event = { x = x,  y = y, }
    -- process handlers in stack (FILO) order
    self.handlers.idle:apply(function(cb) return cb(event) end)
  end

  local custom_delay = nil
  engine.reactor:subscribe('event.delay', function(_, value) custom_delay = value end)


  while (running) do
    local e = SDL.waitEvent(custom_delay or EVENT_DELAY)
    custom_delay = nil
    if (e) then
      local t = e.type
      if t == SDL.event.Quit then
        running = false
      elseif (t == SDL.event.WindowEvent) then
        if (e.event == kind.Resized or e.event == kind.SizeChanged
        or e.event == kind.Minimized or e.event ==  kind.Maximized) then
        self.size = table.pack(self.window:getSize())
        engine.reactor:publish("full.refresh")
        end
      elseif (t == SDL.event.KeyUp) then
        if (e.keysym.sym == SDL.key.e) then
          engine:end_turn()
        elseif (e.keysym.sym == SDL.key.t) then
          engine:toggle_layer()
        elseif (e.keysym.sym == SDL.key.h) then
          engine:toggle_history()
        elseif (e.keysym.sym == SDL.key.k) then
          engine:toggle_attack_priorities()
        end
      elseif (t == SDL.event.MouseMotion) then
        local state, x, y = SDL.getMouseState()
        local event = {
          x       = x,
          y       = y,
        }
        engine.state:set_mouse(x, y)
        -- process handlers in stack (FILO) order
        self.handlers.mouse_move:apply(function(cb) return cb(event) end)
      elseif (t == SDL.event.MouseButtonUp) then
        local state, x, y = SDL.getMouseState()
        local button = (e.button == SDL.mouseButton.Left)
                    and 'left'
                    or  (e.button == SDL.mouseButton.Right)
                    and 'right'
                    or  nil
        local event = {
          x       = x,
          y       = y,
          button  = button,
        }
        -- process handlerss in stack (FILO) order
        self.handlers.mouse_click:apply(function(cb) return cb(event) end)
	   else
       fn_idle()
     end
    -- idle
    else
      fn_idle()
    end
    engine.reactor:replay_masked_events()
    sdl_renderer:clear()
    self.draw_function()
    sdl_renderer:present()
  end
end


return Renderer
