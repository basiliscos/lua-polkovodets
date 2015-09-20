local DummyRenderer = {}
DummyRenderer.__index = DummyRenderer

function DummyRenderer.create(width, height)
   local o = {
	  w = width,
	  h = height,
   }
   setmetatable(o, DummyRenderer)
   return o
end

function DummyRenderer:get_size()
   return self.w, self.h
end

return DummyRenderer
