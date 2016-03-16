local DummyRenderer = {}
DummyRenderer.__index = DummyRenderer

local _DummyTexture = {}
_DummyTexture.__index = _DummyTexture

function _DummyTexture:setAlphaMod() return true end
function _DummyTexture:query() return 'a', 'b', 10, 20 end

local _DummyImage = {}
_DummyImage.__index = _DummyImage

function DummyRenderer.create(width, height)
  local image = {
    w = 0,
    h = 0,
    texture = setmetatable({}, _DummyTexture),
  }
  local o = {
    w        = width,
    h        = height,
    textures = {},
    image    = setmetatable(image, _DummyImage),
    state    = {},
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
   return self.image
end

return DummyRenderer
