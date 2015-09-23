local Renderer = {}
Renderer.__index = Renderer

local SDL	= require "SDL"
local image = require "SDL.image"

local CURSOR_SIZE = 22


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


function Renderer:load_texture(path)
   local textures_cache = self.textures_cache
   if (textures_cache[path] ) then
	  return textures_cache[path]
   end
   print("loading image " .. path)
   local surface = assert(image.load(path))
   assert(surface:setColorKey(1, 0x0))
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
	  local y_shift = (i % 2 == 0) and  hex_y_offset or 0
	  for j = 1,map_sh do
		 local tile = map.tiles[i][j]
		 tile:draw(sdl_renderer, x, y + y_shift)
		 y = y + hex_h
	  end
	  x = x + hex_x_offset
	  y = engine.gui.map_sy - ( start_map_y - engine.gui.map_y ) * hex_h
   end
end


function Renderer:_draw_cursor()
   local state, x, y = SDL.getMouseState()
   -- print("x = " .. x .. ", y = " .. y)
   local joint_cursors_texture = self:load_texture(self.resources.cursors)
   local src = { w = CURSOR_SIZE, h = CURSOR_SIZE, x = (self.current_cursor * CURSOR_SIZE), y = 0}
   local dst = { w = CURSOR_SIZE, h = CURSOR_SIZE, x = x, y = y }
   assert(self.sdl_renderer:copy(joint_cursors_texture, src, dst))
end


function Renderer:_draw_world()
   self:_draw_map()
   self:_draw_cursor()
end


function Renderer:main_loop()
   local engine = self.engine
   local running = true
   local sdl_renderer = self.sdl_renderer
   local kind = SDL.eventWindow
   while (running) do
	  local e = SDL.waitEvent()
	  local t = e.type
	  if t == SDL.event.Quit then
		 running = false
	  elseif (t == SDL.event.WindowEvent) then
		 if (e.event == kind.Resized or e.event == kind.SizeChanged
			 or e.event == kind.Minimized or e.event ==  kind.Maximized) then
			self.size = table.pack(self.window:getSize())
			engine:update_shown_map()
		 end
	  end
	  sdl_renderer:clear()
	  self:_draw_world()
	  sdl_renderer:present()
   end
end


return Renderer
