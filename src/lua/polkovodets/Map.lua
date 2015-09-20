local Map = {}
Map.__index = Map

local Parser = require 'polkovodets.Parser'
local Terrain = require 'polkovodets.Terrain'
local Tile = require 'polkovodets.Tile'
local inspect = require('inspect')


function Map.create(engine)
   local m = { engine = engine }
   setmetatable(m, Map)
   return m
end


function Map:load(map_file)
   local path = self.engine.get_maps_dir() .. '/' .. map_file
   print('loading map at ' .. path)
   local parser = Parser.create(path)
   self.width = tonumber(parser:get_value('width'))
   self.height = tonumber(parser:get_value('height'))
   assert(self.width > 3, "map width must me > 3")
   assert(self.height > 3, "map height must me > 3")

   local terrain_file = parser:get_value('terrain_db')
   assert(terrain_file)

   local terrain = Terrain.create(self.engine)
   terrain:load(terrain_file)
   self.terrain = terrain

   local tiles_data = parser:get_list_value('tiles')
   local tile_names = parser:get_list_value('names')

   local tiles = {}
   for y = 1,self.height do
	  local row = {}
	  for x = 1,self.width do
		 local idx = (y-1) * self.height + x
		 local datum = tiles_data[idx]
		 local terrain_name = string.sub(datum,1,1)
		 local image_idx = tonumber(string.sub(datum,2, -1))
		 local terrain_type = terrain:get_type(terrain_name)
		 local tile_data = {
			x = x,
			y = y,
			name = tile_names[idx],
			terrain_name = terrain_name,
			image_idx = image_idx,
			terrain_type = terrain_type,
		 }
		 row[ #row + 1] = Tile.create(tile_data)
	  end
	  tiles[y] = row
   end
   self.tiles = tiles
   -- print(inspect(tiles[1][1]))

end

return Map
