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

local Renderer = {}
Renderer.__index = Renderer

local SDL	= require "SDL"
local image = require "SDL.image"
local inspect = require('inspect')
local ttf = require "SDL.ttf"

local CURSOR_SIZE = 22
local SCROLL_TOLERANCE = 5
local EVENT_DELAY = 50

function Renderer.create(engine, window, sdl_renderer)
   assert(ttf.init())
   local o = {
      active_tile = {0, 0},
	  size = table.pack(window:getSize()),
      current_cursor = 0,
	  engine = engine,
	  window = window,
	  sdl_renderer = sdl_renderer,
	  textures_cache = {},
      resources = {},
      fonts = {},
   }
   -- hide system mouse pointer
   assert(SDL.showCursor(false))
   setmetatable(o, Renderer)
   o:_load_theme();
   return o
end


function Renderer:get_size()
   return table.unpack(self.size)
end


function Renderer:_load_theme()
   local engine = self.engine
   local dir = engine:get_theme_dir()
   local cursors_file = 'cursors.bmp'
   local cursors_path = dir .. '/' .. cursors_file
   self.resources.cursors = cursors_path
   self:load_texture(cursors_path)
   local active_hex_font = dir .. '/' .. engine.theme.active_hex.font
   local active_hex_size = engine.theme.active_hex.font_size
   self.fonts.active_tile = assert(ttf.open(active_hex_font, active_hex_size))
end


function Renderer:_load_image(path)
   local surface = assert(image.load(path), "error loading image " .. path)
   assert(surface:setColorKey(1, 0x0))
   return surface
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
      local texture = assert(self.sdl_renderer:createTextureFromSurface(sub_surface))
      table.insert(cache, texture)
   end
   print(path .. ": " .. #cache .. " textures")
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
   local texture = assert(self.sdl_renderer:createTextureFromSurface(surface))
   textures_cache[path] = texture
   return texture
end


function Renderer:_draw_map()
   local engine = self.engine
   local map = engine:get_map()
   local sdl_renderer = self.sdl_renderer
   local terrain = map.terrain

   local hex_x_offset = terrain.hex_x_offset
   local hex_y_offset = terrain.hex_y_offset
   local hex_h = terrain.hex_height

   local start_map_x = engine.gui.map_x
   local start_map_y = engine.gui.map_y

   local x = engine.gui.map_sx - ( start_map_x - engine.gui.map_x ) * hex_x_offset
   local y = engine.gui.map_sy - ( start_map_y - engine.gui.map_y ) * hex_h

   local map_sw = (engine.gui.map_sw > map.width) and map.width or engine.gui.map_sw
   local map_sh = (engine.gui.map_sh > map.height) and map.height or engine.gui.map_sh

   for i = 1,map_sw do
      local tx = i + start_map_x
	  local y_shift = (tx % 2 == 0) and  hex_y_offset or 0
	  for j = 1,map_sh do
         local ty = j + start_map_y
         -- print(string.format("tx:ty = (%d:%d), start_map_x = %d", tx, ty, start_map_x))
		 local tile = map.tiles[tx][ty]
		 tile:draw(sdl_renderer, x, y + y_shift)
		 y = y + hex_h
	  end
	  x = x + hex_x_offset
	  y = engine.gui.map_sy - ( start_map_y - engine.gui.map_y ) * hex_h
   end
end


function Renderer:_check_scroll(scroll_dx, scroll_dy)
   local engine = self.engine
   local map_x, map_y = engine.gui.map_x, engine.gui.map_y
   local map_w, map_h = engine.map.width, engine.map.height
   local map_sw, map_sh = engine.gui.map_sw, engine.gui.map_sh
   local state, x, y = SDL.getMouseState()

   local direction
   if ((y < SCROLL_TOLERANCE or scroll_dy > 0) and map_y > 0) then
      engine.gui.map_y = engine.gui.map_y - 1
      direction = "up"
   elseif (((y > self.size[2] - SCROLL_TOLERANCE) or scroll_dy < 0) and map_y < map_h - map_sh) then
      engine.gui.map_y = engine.gui.map_y + 1
      direction = "down"
   elseif ((x < SCROLL_TOLERANCE or scroll_dx < 0)  and map_x > 0) then
      engine.gui.map_x = engine.gui.map_x - 1
      direction = "left"
   elseif (((x > self.size[1] - SCROLL_TOLERANCE) or scroll_dx > 0) and map_x < map_w - map_sw) then
      engine.gui.map_x = engine.gui.map_x + 1
      direction = "right"
   end

   if (direction) then
      -- print("scrolling " .. direction .. " " .. engine.gui.map_x .. ":" .. engine.gui.map_y)
      engine:update_shown_map()
   end
end


function Renderer:_recalc_active_tile()
   local engine = self.engine
   local terrain = engine:get_map().terrain
   local map_sx, map_sy = engine.gui.map_sx, engine.gui.map_sy
   local hex_h = terrain.hex_height
   local hex_w = terrain.hex_width
   local hex_x_offset = terrain.hex_x_offset
   local hex_y_offset = terrain.hex_y_offset
   local state, x, y = SDL.getMouseState()

   local hex_x_delta = hex_w - hex_x_offset
   local hex_y_delta = hex_y_offset

   local map_x = (x - map_sx) // hex_x_offset
   local y_offset = (map_x % 2 == 1) and hex_y_offset or 0
   local map_y = (y - y_offset - map_sy) // hex_h

   local tile_x_offset = x - (map_x * hex_x_offset) - map_sx
   local tile_y_offset = (y - map_sy) % hex_h
   -- print(string.format("tile: %d:%d, offset: %d, %d", map_x, map_y, tile_x_offset, tile_y_offset))

   if (tile_x_offset < hex_x_delta) then
      local fix = { -1, 1 }
      if (tile_y_offset > hex_y_offset) then
         tile_y_offset = hex_h - tile_y_offset
         fix = { -1, 0 }
      end
      -- print(string.format("(A:B) = %d, %d, (tx, ty) = %d, %d", hex_y_delta, -hex_x_delta, tile_x_offset, tile_y_offset))
      local value = hex_y_delta * tile_x_offset - hex_x_delta * tile_y_offset
      -- print("hit " .. value)
      if (value < 0) then
         map_x = map_x + fix[1]
         map_y = map_y + fix[2]
      end
   end
   self.active_tile = {map_x + engine.gui.map_x + 1, map_y + engine.gui.map_y + 1}
   -- print(string.format("active tile = %d:%d", map_x, map_y))
end


function Renderer:_draw_cursor()
   -- print("x = " .. x .. ", y = " .. y)
   local state, x, y = SDL.getMouseState()
   local joint_cursors_texture = self:load_texture(self.resources.cursors)
   local src = { w = CURSOR_SIZE, h = CURSOR_SIZE, x = (self.current_cursor * CURSOR_SIZE), y = 0}
   local dst = { w = CURSOR_SIZE, h = CURSOR_SIZE, x = x, y = y }
   assert(self.sdl_renderer:copy(joint_cursors_texture, src, dst))
end


function Renderer:_draw_active_hex_info()
   local engine = self.engine
   local map = engine.map
   local sdl_renderer = self.sdl_renderer
   local x, y = table.unpack(self.active_tile)
   local w,h = self.window:getSize()

   local render_label = function(surface)
      assert(surface)
      local texture = assert(self.sdl_renderer:createTextureFromSurface(surface))
      local sw, sh = surface:getSize()
      local label_x = math.modf(w/2 - sw/2)
      local label_y = 25 - (sh/2)
      assert(sdl_renderer:copy(texture, nil , {x = label_x, y = label_y, w = sw, h = sh}))
   end
   if (x > 0 and x <= map.width and y > 0 and y <= map.height) then
      local tile = map.tiles[x][y]
      local str = string.format('%s (%d:%d)', tile.data.name, x, y)
      local font = self.fonts.active_tile
      local outline_color = self.engine.theme.active_hex.outline_color
      local color = self.engine.theme.active_hex.color
      font:setOutline(self.engine.theme.active_hex.outline_width)
      render_label(font:renderUtf8(str, "solid", outline_color))
      font:setOutline(0)
      render_label(font:renderUtf8(str, "solid", color))
   end
end


function Renderer:_draw_world()
   self:_check_scroll(0, 0) -- check scroll by mouse position
   self:_draw_map()
   self:_draw_active_hex_info()
   self:_draw_cursor()
end


function Renderer:main_loop()
   local engine = self.engine
   local running = true
   local sdl_renderer = self.sdl_renderer
   local kind = SDL.eventWindow
   while (running) do
	  local e = SDL.waitEvent(EVENT_DELAY)
	  local t = e.type
	  if t == SDL.event.Quit then
		 running = false
	  elseif (t == SDL.event.WindowEvent) then
		 if (e.event == kind.Resized or e.event == kind.SizeChanged
			 or e.event == kind.Minimized or e.event ==  kind.Maximized) then
			self.size = table.pack(self.window:getSize())
			engine:update_shown_map()
		 end
      elseif (t == SDL.event.KeyUp) then
         if (e.keysym.sym == SDL.key.e) then
            engine:end_turn()
         end
      elseif (t == SDL.event.MouseMotion) then
         self:_recalc_active_tile()
      elseif (t == SDL.event.MouseWheel) then
         self:_check_scroll(e.x, e.y) -- check scroll by mouse wheel
	  end
	  sdl_renderer:clear()
	  self:_draw_world()
	  sdl_renderer:present()
   end
end


return Renderer
