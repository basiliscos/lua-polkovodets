local Renderer = {}
Renderer.__index = Renderer

local image = require "SDL.image"


function Renderer.create(engine, window, sdl_renderer)
   local o = {
	  engine = engine,
	  window = window,
	  sdl_renderer = sdl_renderer,
   }
   setmetatable(o, Renderer)
   return o
end

function Renderer:get_size()
   return 640, 480
end

function Renderer:load_texture(path)
   local surface = assert(image.load(path))
   assert(surface:setColorKey(1, 0x0))
   local texture = assert(self.sdl_renderer:createTextureFromSurface(surface))
   return texture
end


function Renderer:draw_map()
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
	  for j = 1,map_sh do
		 local tile = map.tiles[i][j]
		 local abs_y = (j % 2 == 1) and y + hex_y_offset or y
		 tile:draw(sdl_renderer, x, abs_y)
		 x = x + hex_x_offset
	  end
	  y = y + hex_h
	  x = engine.gui.map_sx - ( start_map_x - engine.gui.map_x ) * hex_x_offset
   end

end


return Renderer
