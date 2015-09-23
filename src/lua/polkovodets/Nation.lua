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

   local w, h = shared_data.icon_width, shared_data.icon_height
   local image_path = engine:get_nations_icons_dir() .. '/' .. shared_data.icons_image
   engine.renderer:load_joint_texture(image_path, {0, h} )

   local o = {
	  engine = engine,
	  data = nation_data,
	  shared_data = shared_data,
      flags_path = image_path,
      flag_frame = {x = 0, y = 0, w = w, h = h},
   }
   o.data.icon_id = tonumber(o.data.icon_id) + 1 -- 1-based index in lua

   setmetatable(o, Nation)
   return o
end

function Nation:draw_flag(sdl_renderer, x, y, objective)
   local engine = self.engine
   local shared_data = self.shared_data

   local texture = engine.renderer:get_joint_texture(self.flags_path, self.data.icon_id)
   local dst = {x = x, y = y, w = shared_data.icon_width, h = shared_data.icon_height}
   assert(sdl_renderer:copy(texture, self.flag_frame, dst))
end

return Nation
