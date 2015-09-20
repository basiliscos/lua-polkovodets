local Engine = {}
Engine.__index = Engine


function Engine.create()
   local e = {map = map}
   setmetatable(e,Engine)
   return e
end


function Engine:set_map(map)
   self.map = map
end


function  Engine:get_maps_dir()
   return 'data/maps/pg'
end


function  Engine:get_terrains_dir()
   return 'data/maps'
end


function Engine:draw_map()
   local map = self.map
   print("draw_map: " .. map.width .. "x" .. map.height)
   for x = 1,map.width do
   	  for y = 1,map.height do
   	  end
   end
end

return Engine
