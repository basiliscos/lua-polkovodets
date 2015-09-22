local Nation = {}
Nation.__index = Nation

local Parser = require 'polkovodets.Parser'

function Nation.create(engine, shared_data, nation_data)
   assert(nation_data.icon_id)
   assert(nation_data.name)
   assert(nation_data.key)

   assert(shared_data.icon_width)
   assert(shared_data.icon_height)
   assert(shared_data.icons_image)


   local o = {
	  engine = engine,
	  data = nation_data,
	  shared_data = shared_data,
   }
   o.data.icon_id = tonumber(o.data.icon_id)

   local image_offset = o.data.icon_id * shared_data.icon_height
   o.image_rectange = {x = 0, y = image_offset, w = shared_data.icon_width, h = shared_data.icon_height}

   setmetatable(o, Nation)
   return o
end

function Nation:draw_flag(sdl_renderer, x, y, objective)
   local engine = self.engine
   local shared_data = self.shared_data

   local image_path = engine:get_nations_icons_dir() .. '/' .. shared_data.icons_image
   local joint_texture = engine.renderer:load_texture(image_path)
   local dst = {x = x, y = y, w = shared_data.icon_width, h = shared_data.icon_height}
   assert(sdl_renderer:copy(joint_texture, self.image_rectange, dst))
end

return Nation
