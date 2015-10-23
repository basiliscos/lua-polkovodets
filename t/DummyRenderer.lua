local DummyRenderer = {}
DummyRenderer.__index = DummyRenderer

local _DummyTexture = {}
_DummyTexture.__index = _DummyTexture

function _DummyTexture:setAlphaMod() return true end
function _DummyTexture:query() return 'a', 'b', 10, 20 end

function DummyRenderer.create(engine, width, height)
   local o = {
	  w = width,
	  h = height,
      textures = {},
   }
   setmetatable(o, DummyRenderer)
   engine:set_renderer(o)
   return o
end

function DummyRenderer:get_size()
   return self.w, self.h
end

function DummyRenderer:load_joint_texture(path, frame)
   self.textures[path] = true
end

function DummyRenderer:load_texture(path)
   local o = { path = path }
   setmetatable(o, _DummyTexture)
   return o
end

return DummyRenderer
