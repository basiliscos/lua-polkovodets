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
   print("map size: " .. self.width .. "x" .. self.height)
   assert(self.width > 3, "map width must me > 3")
   assert(self.height > 3, "map height must me > 3")

   local terrain_file = parser:get_value('terrain_db')
   assert(terrain_file)

   local engine = self.engine
   local terrain = Terrain.create(engine)
   terrain:load(terrain_file)
   self.terrain = terrain

   local tiles_data = parser:get_list_value('tiles')
   local tile_names = parser:get_list_value('names')

   -- 2 dimentional array, [x:y]
   local tiles = {}
   for x = 1,self.width do
	  local column = {}
	  for y = 1,self.height do
		 local idx = (y-1) * self.width + x
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
		 column[ y ] = Tile.create(engine, tile_data)
	  end
	  tiles[x] = column
   end
   self.tiles = tiles
   -- print(inspect(tiles[1][1]))
end

function Map:prepare()
   for x = 1,self.width do
	  for y = 1,self.height do
		 self.tiles[x][y]:prepare()
	  end
   end
end

return Map
