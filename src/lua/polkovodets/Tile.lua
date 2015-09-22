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

function Tile:precalculate()
   local engine = self.engine
   local map = engine:get_map()
   local scenario = engine:get_scenario()
   local terrain = map.terrain
   local hex_h = terrain.hex_height
   local hex_w = terrain.hex_width


   local image_offset = self.data.image_idx * hex_w
   self.image_rectange = {x = image_offset, y = 0, w = hex_w, h = hex_h}
   self.grid_rectange = {x = 0, y = 0, w = hex_w, h = hex_h}
end


function Tile:draw(sdl_renderer, x, y)
   assert(sdl_renderer)
   local sx, sy = self.data.x, self.data.y
   -- print(inspect(self.data))
   -- print("drawing tile [" .. sx .. ":" .. sy .. "] at (" .. x .. ":" .. y .. ")")

   local engine = self.engine
   local map = engine:get_map()
   local scenario = engine:get_scenario()
   local terrain = map.terrain
   local turn = engine:current_turn()
   local weather = assert(scenario.weather[turn])

   local joint_weather_image = assert(self.data.terrain_type.image[weather])

   local hex_h = terrain.hex_height
   local hex_w = terrain.hex_width

   local dst = {x = x, y = y, w = hex_w, h = hex_h}
   local icons_dir = engine:get_terrain_icons_dir()
   local icon_path = icons_dir .. '/' .. joint_weather_image
   local joint_texture = engine.renderer:load_texture(icon_path)

   assert(sdl_renderer:copy(joint_texture, self.image_rectange, dst))
   local show_grid = engine.options.show_grid
   local src = {x = 0, y = 0, w = hex_w, h = hex_h}
   if (show_grid) then
	  local icon_texture = terrain:get_icon('grid')
	  assert(sdl_renderer:copy(icon_texture, self.grid_rectange, dst))
   end
end

return Tile
