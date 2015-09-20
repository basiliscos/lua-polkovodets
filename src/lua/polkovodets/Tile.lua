local Tile = {}
Tile.__index = Tile


function Tile.create(data)
   setmetatable(data, Tile)
   return data
end


return Tile
