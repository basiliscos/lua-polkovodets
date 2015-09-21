local Tile = {}
Tile.__index = Tile

local inspect = require('inspect')

function Tile.create(engine, data)
   local o = {
	  engine = engine,
	  data = data,
   }
   setmetatable(o, Tile)
   return o
end


function Tile:draw(sdl_renderer, x, y)
   assert(sdl_renderer)
   local sx, sy = self.data.x, self.data.y
   -- print(inspect(self.data))
   -- print("drawing tile [" .. sx .. ":" .. sy .. "] at (" .. x .. ":" .. y .. ")")

   local engine = self.engine
   local map = engine:get_map()
   local terrain = map.terrain

   local hex_h = terrain.hex_height
   local hex_w = terrain.hex_width

   local show_grid = engine.options.show_grid
   local dst = {x = x, y = y, w = hex_w, h = hex_h}
   local src = {x = 0, y = 0, w = hex_w, h = hex_h}
   if (show_grid) then
	  local icon_texture = terrain:get_icon('grid')
	  assert(sdl_renderer:copy(icon_texture, src, dst))
   end
end

return Tile
