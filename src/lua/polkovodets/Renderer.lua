local Renderer = {}
Renderer.__index = Renderer

local SDL	= require "SDL"
local image = require "SDL.image"
local inspect = require('inspect')

local CURSOR_SIZE = 22
local SCROLL_TOLERANCE = 5
local EVENT_DELAY = 50

function Renderer.create(engine, window, sdl_renderer)
   local o = {
	  size = table.pack(window:getSize()),
      current_cursor = 0,
	  engine = engine,
	  window = window,
	  sdl_renderer = sdl_renderer,
	  textures_cache = {},
      resources = {},
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
   local dir = self.engine:get_theme_dir()
   local cursors_file = 'cursors.bmp'
   local cursors_path = dir .. '/' .. cursors_file
   self.resources.cursors = cursors_path
   self:load_texture(cursors_path)
end


function Renderer:_load_image(path)
   print("loading image " .. path)
   local surface = assert(image.load(path))
   assert(surface:setColorKey(1, 0x0))
   return surface
end


function Renderer:load_joint_texture(path, frame)
   local textures_cache = self.textures_cache
   if (textures_cache[path]) then return end

   local surface = self:_load_image(path)
   local w,h = surface:getSize()
   local frame_w, frame_h
   if (frame[1] > 0) then
      assert( w % frame[1] == 0)
      frame_w = frame[1]
      frame_h = h
   else
      assert( h % frame[2] == 0)
      frame_w = w
      frame_h = frame[2]
   end
   local x, y = 0, 0
   local cache = {}
   while (x ~= w and y ~= h) do
      local dst = { x = 0, y = 0, w = frame_w, h = frame_h}
      local sub_surface = assert(SDL.createRGBSurface(frame_w, frame_h))
      local src = { x = x, y = y, w = frame_w, h = frame_h }
      -- print("src:  " .. inspect(src) .. " -> dst: " .. inspect(dst))
      assert(surface:blit(sub_surface, src));
      local texture = assert(self.sdl_renderer:createTextureFromSurface(sub_surface))
      -- self.sdl_renderer:clear()
      -- self.sdl_renderer:copy(texture, dst, src)
      -- self.sdl_renderer:present()
      -- local unistd = require 'posix.unistd'
      -- unistd.sleep(1)

      table.insert(cache, texture)
      x = x + frame[1]
      y = y + frame[2]
   end
   textures_cache[path] = cache
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
	  local y_shift = ((i + start_map_x) % 2 == 0) and  hex_y_offset or 0
	  for j = 1,map_sh do
		 local tile = map.tiles[i + start_map_x][j + start_map_y]
		 tile:draw(sdl_renderer, x, y + y_shift)
		 y = y + hex_h
	  end
	  x = x + hex_x_offset
	  y = engine.gui.map_sy - ( start_map_y - engine.gui.map_y ) * hex_h
   end
end


function Renderer:_check_scroll()
   local engine = self.engine
   local map_x, map_y = engine.gui.map_x, engine.gui.map_y
   local map_w, map_h = engine.map.width, engine.map.height
   local map_sw, map_sh = engine.gui.map_sw, engine.gui.map_sh
   local state, x, y = SDL.getMouseState()

   local direction
   if (y < SCROLL_TOLERANCE and map_y > 0) then
      engine.gui.map_y = engine.gui.map_y - 1
      direction = "up"
   elseif ((y > self.size[2] - SCROLL_TOLERANCE) and map_y < map_h - map_sh) then
      engine.gui.map_y = engine.gui.map_y + 1
      direction = "down"
   elseif (x < SCROLL_TOLERANCE and map_x > 0) then
      engine.gui.map_x = engine.gui.map_x - 1
      direction = "left"
   elseif ((x > self.size[1] - SCROLL_TOLERANCE) and map_x < map_w - map_sw) then
      engine.gui.map_x = engine.gui.map_x + 1
      direction = "right"
   end

   if (direction) then
       print("scrolling " .. direction .. " " .. engine.gui.map_x .. ":" .. engine.gui.map_y)
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
   -- print(string.format("final tile = %d:%d", map_x, map_y))
end


function Renderer:_draw_cursor()
   -- print("x = " .. x .. ", y = " .. y)
   local state, x, y = SDL.getMouseState()
   local joint_cursors_texture = self:load_texture(self.resources.cursors)
   local src = { w = CURSOR_SIZE, h = CURSOR_SIZE, x = (self.current_cursor * CURSOR_SIZE), y = 0}
   local dst = { w = CURSOR_SIZE, h = CURSOR_SIZE, x = x, y = y }
   assert(self.sdl_renderer:copy(joint_cursors_texture, src, dst))
end


function Renderer:_draw_world()
   self:_check_scroll()
   self:_draw_map()
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
      elseif (t == SDL.event.MouseMotion) then
         --self:_recalc_active_tile()
	  end
	  sdl_renderer:clear()
	  self:_draw_world()
	  sdl_renderer:present()
   end
end


return Renderer
