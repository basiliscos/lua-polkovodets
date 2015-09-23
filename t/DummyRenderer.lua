local DummyRenderer = {}
DummyRenderer.__index = DummyRenderer

function DummyRenderer.create(width, height)
   local o = {
	  w = width,
	  h = height,
      textures = {},
   }
   setmetatable(o, DummyRenderer)
   return o
end

function DummyRenderer:get_size()
   return self.w, self.h
end

function DummyRenderer:load_joint_texture(path, frame)
   self.textures[path] = true
end

function DummyRenderer:load_texture(path)
   return "dummy-texture[" .. path .. "]"
end

return DummyRenderer
