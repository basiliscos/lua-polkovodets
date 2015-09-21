local Terrain = {}
Terrain.__index = Terrain


local Parser = require 'polkovodets.Parser'


function Terrain.create(engine)
   local o = { engine = engine }
   setmetatable(o, Terrain)
   return o
end


function Terrain:load(terrain_file)
   local engine = self.engine
   local path = engine.get_terrains_dir() .. '/' .. terrain_file
   print('loading terrain ' .. path)
   local parser = Parser.create(path)
   self.parser = parser

   -- hex tile geometry
   self.hex_width = tonumber(parser:get_value('hex_width'))
   self.hex_height = tonumber(parser:get_value('hex_height'))
   self.hex_x_offset = tonumber(parser:get_value('hex_x_offset'))
   self.hex_y_offset = tonumber(parser:get_value('hex_y_offset'))

   local icons = {}
   local icons_dir = self.engine:get_terrain_icons_dir()
   local load_icon = function(key)
	  local icon_file = parser:get_value(key)
	  assert(icon_file, "cannot find icon for '" .. key .. "' in " .. path)
	  local path = icons_dir .. '/' .. icon_file
	  local texture = engine.renderer:load_texture(path)
	  icons[key] = texture
   end
   load_icon('grid')

   self.icons = icons
end

function Terrain:get_type(name)
   -- name 1-symbol
   local terrains_for = self.parser:get_value('terrain')
   assert(terrains_for)

   local terrain_type = terrains_for[name]
   assert(terrain_type, "terrain " .. name .. " not found")
   return terrain_type
end

function Terrain:get_icon(name)
   local surface = assert(self.icons[name])
   return surface
end

return Terrain
