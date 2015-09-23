local Tile = {}
Tile.__index = Tile

local inspect = require('inspect')

function Tile.create(engine, data)
   assert(data.image_idx)
   assert(data.x)
   assert(data.y)
   assert(data.terrain_type)
   assert(data.terrain_name)

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
   local scenario = engine:get_scenario()
   local terrain = map.terrain
   local turn = engine:current_turn()
   local weather = assert(scenario.weather[turn])

   local joint_weather_image = assert(self.data.terrain_type.image[weather])

   local hex_h = terrain.hex_height
   local hex_w = terrain.hex_width

   local dst = {x = x, y = y, w = hex_w, h = hex_h}
   local texture = terrain:get_hex_image(self.data.terrain_name, weather, self.data.image_idx)

   -- draw terrain
   assert(sdl_renderer:copy(texture, {x = 0, y = 0, w = hex_w, h = hex_h} , dst))
   local show_grid = engine.options.show_grid

   -- draw nation flag
   local nation = self.data.nation
   if (nation) then
	  -- print("flag for " .. nation.data.name)
	  local nation_flag_width = nation.shared_data.icon_width
	  local nation_flag_height = nation.shared_data.icon_height
	  local flag_x = x  + (hex_w - nation_flag_width) / 2
	  local flag_y = y + hex_h - nation_flag_height - 2
	  local objective = self.data.objective
	  nation:draw_flag(sdl_renderer, flag_x, flag_y, objective)
   end

   -- draw grid
   if (show_grid) then
      local icon_texture = terrain:get_icon('grid')
      assert(sdl_renderer:copy(icon_texture, self.grid_rectange, dst))
   end
end

return Tile
