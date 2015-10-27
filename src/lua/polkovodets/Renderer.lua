--[[

Copyright (C) 2015 Ivan Baidakou

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

]]--

local Renderer = {}
Renderer.__index = Renderer

local SDL	= require "SDL"
local image = require "SDL.image"
local inspect = require('inspect')
local ttf = require "SDL.ttf"
local Theme = require 'polkovodets.Theme'

local SCROLL_TOLERANCE = 5
local EVENT_DELAY = 50

function Renderer.create(engine, window, sdl_renderer)
   assert(ttf.init())
   local o = {
      active_tile = {1, 1},
	  size = table.pack(window:getSize()),
      current_cursor = 0,
	  engine = engine,
	  window = window,
	  sdl_renderer = sdl_renderer,
	  textures_cache = {},
      resources = {},
      fonts = {},
   }
   -- hide system mouse pointer
   assert(SDL.showCursor(false))
   setmetatable(o, Renderer)
   engine:set_renderer(o)
   local theme = Theme.create(engine,
                              {
                                 name = 'default',
                                 active_hex = {
                                    outline_color = 0x0,
                                    outline_width = 2,
                                    color = 0xFFFFFF,
                                    font_size = 15,
                                    font = 'DroidSansMono.ttf'
                                 },
                                 cursors = {
                                    path = 'cursors.bmp',
                                    size = 22,
                                    actions = {
                                       ['default'     ] = 1,
                                       ['move'        ] = 2,
                                       ['merge'       ] = 3,
                                       ['attack'      ] = 4,
                                    }
                                 },

                              }
   )
   o.theme = theme
   return o
end


function Renderer:get_size()
   return table.unpack(self.size)
end


function Renderer:_load_image(path)
   local surface = assert(image.load(path), "error loading image " .. path)
   if (string.find(path, '.bmp', nil, true)) then
      assert(surface:setColorKey(1, 0x0))
   end
   return surface
end


function Renderer:load_joint_texture(path, iterator_factory)
   local textures_cache = self.textures_cache
   if (textures_cache[path]) then return end

   local surface = self:_load_image(path)

   local cache = {}
   local iterator = iterator_factory(surface)
   for rectangle in iterator() do
      -- print("rectangle: " .. inspect(rectangle))
      local sub_surface = assert(SDL.createRGBSurface(rectangle.w, rectangle.h))
      assert(surface:blit(sub_surface, rectangle));
      local texture = assert(self.sdl_renderer:createTextureFromSurface(sub_surface))
      table.insert(cache, texture)
   end
   print(path .. ": " .. #cache .. " textures")
   textures_cache[path] = cache
end


function Renderer:create_simple_iterator(surface, x_advance, y_advance)
   local w,h = surface:getSize()
   local frame_w, frame_h
   if (x_advance > 0) then
      assert( w % x_advance == 0, "surface width " .. w .. " must be divisable to " .. x_advance)
      frame_w = x_advance
      frame_h = h
   else
      assert( h % y_advance == 0, "surface height " .. h .. " must be divisable to " .. y_advance)
      frame_w = w
      frame_h = y_advance
   end
   local frame = {x = -x_advance, y = -y_advance, w = frame_w, h = frame_h}
   local iterator = function(state, value) -- all values are unused
      if (frame.x < w and frame.y < h) then
         frame.x = frame.x + x_advance
         frame.y = frame.y + y_advance
         return frame
      end
   end
   return function() return iterator, nil, frame end
end

function Renderer:get_joint_texture(path, index)
   assert(index, "texture index should be defined")
   local textures = self.textures_cache[path]
   --print(inspect(textures))
   assert(textures, "texture " .. path .. " wasn't loaded")
   assert(type(textures) == 'table', path .. " isn't joint image")
   local texture = textures[index]
   if (not texture) then
      print("no " .. index .. "-th texture at " .. path .. ", using 1st")
      texture = textures[1]
   end
   return texture;
end


function Renderer:load_texture(path)
   local textures_cache = self.textures_cache
   if (textures_cache[path] ) then
	  return textures_cache[path]
   end
   local surface = self:_load_image(path)
   local texture = assert(self.sdl_renderer:createTextureFromSurface(surface))
   textures_cache[path] = texture
   return texture
end


function Renderer:_draw_map()
   local engine = self.engine
   local map = engine:get_map()
   local sdl_renderer = self.sdl_renderer
   local terrain = map.terrain

   local hex_x_offset = terrain.hex_x_offset
   local hex_y_offset = terrain.hex_y_offset
   local hex_h = terrain.hex_height

   local start_map_x = engine.gui.map_x
   local start_map_y = engine.gui.map_y

   local map_sw = (engine.gui.map_sw > map.width) and map.width or engine.gui.map_sw
   local map_sh = (engine.gui.map_sh > map.height) and map.height or engine.gui.map_sh

   local draw = function(draw_at_tile)
      local x = engine.gui.map_sx - ( start_map_x - engine.gui.map_x ) * hex_x_offset
      local y = engine.gui.map_sy - ( start_map_y - engine.gui.map_y ) * hex_h

      for i = 1,map_sw do
         local tx = i + start_map_x
         local y_shift = (tx % 2 == 0) and  hex_y_offset or 0
         for j = 1,map_sh do
            local ty = j + start_map_y
            if (tx <= map.width and ty <= map.height) then
               draw_at_tile(tx, ty, x, y + y_shift)
               y = y + hex_h
            end
         end
         x = x + hex_x_offset
         y = engine.gui.map_sy - ( start_map_y - engine.gui.map_y ) * hex_h
      end
   end

   local u = engine:get_selected_unit()
   local context = {
      selected_unit = u,
      subordinated = {}, -- k: tile_id, v: unit
   }

   local active_x, active_y = table.unpack(self.active_tile)
   local active_tile = map.tiles[active_x][active_y]
   local hilight_unit = u or (active_tile and active_tile.unit)
   if (hilight_unit) then
      for idx, subordinated_unit in pairs(hilight_unit:get_subordinated(true)) do
         local tile_id = subordinated_unit.tile.uniq_id
         context.subordinated[tile_id] = true
      end
   end

   draw(function(tx, ty, x, y)
         local tile = assert(map.tiles[tx][ty], string.format("tile [%d:%d] not found", tx, ty))
         tile:draw(sdl_renderer, x, y, context)
        end
   )
end


function Renderer:_check_scroll(scroll_dx, scroll_dy)
   local engine = self.engine
   local map_x, map_y = engine.gui.map_x, engine.gui.map_y
   local map_w, map_h = engine.map.width, engine.map.height
   local map_sw, map_sh = engine.gui.map_sw, engine.gui.map_sh
   local state, x, y = SDL.getMouseState()

   local direction
   if ((y < SCROLL_TOLERANCE or scroll_dy > 0) and map_y > 0) then
      engine.gui.map_y = engine.gui.map_y - 1
      direction = "up"
   elseif (((y > self.size[2] - SCROLL_TOLERANCE) or scroll_dy < 0) and map_y < map_h - map_sh) then
      engine.gui.map_y = engine.gui.map_y + 1
      direction = "down"
   elseif ((x < SCROLL_TOLERANCE or scroll_dx < 0)  and map_x > 0) then
      engine.gui.map_x = engine.gui.map_x - 1
      direction = "left"
   elseif (((x > self.size[1] - SCROLL_TOLERANCE) or scroll_dx > 0) and map_x < map_w - map_sw) then
      engine.gui.map_x = engine.gui.map_x + 1
      direction = "right"
   end

   if (direction) then
      -- print("scrolling " .. direction .. " " .. engine.gui.map_x .. ":" .. engine.gui.map_y)
      engine:update_shown_map()
   end
end


function Renderer:_recalc_active_tile()
   local engine = self.engine
   local map = engine.map
   local terrain = engine:get_map().terrain
   local hex_h = terrain.hex_height
   local hex_w = terrain.hex_width
   local hex_x_offset = terrain.hex_x_offset
   local hex_y_offset = terrain.hex_y_offset
   local state, x, y = SDL.getMouseState()

   local hex_x_delta = hex_w - hex_x_offset

   local left_col = math.modf((x - hex_x_delta) / hex_x_offset) + 1
   local right_col = left_col + 1
   local top_row = math.modf(y / hex_h) + 1
   local bot_row = top_row + 1
   -- print(string.format("mouse [%d:%d] ", x, y))
   -- print(string.format("[l:r] [t:b] = [%d:%d] [%d:%d] ", left_col, right_col, top_row, bot_row))
   local adj_tiles = {
      {left_col, top_row},
      {left_col, bot_row},
      {right_col, top_row},
      {right_col, bot_row},
   }
   -- print("adj-tiles = " .. inspect(adj_tiles))
   local tile_center_off = {math.modf(hex_w/2), math.modf(hex_h/2)}
   local get_tile_center = function(tx, ty)
      local top_x = (tx - 1) * hex_x_offset
      local top_y = ((ty - 1) * hex_h) - ((tx % 2 == 1) and hex_y_offset or 0)
      return {top_x + tile_center_off[1], top_y + tile_center_off[2]}
   end
   local tile_centers = {}
   for idx, t_coord in pairs(adj_tiles) do
      local center = get_tile_center(t_coord[1], t_coord[2])
      table.insert(tile_centers, center)
   end
   -- print(inspect(tile_centers))
   local nearest_idx, nearest_distance = -1, math.maxinteger
   for idx, t_center in pairs(tile_centers) do
      local dx = x - t_center[1]
      local dy = y - t_center[2]
      local d = math.sqrt(dx*dx + dy*dy)
      if (d < nearest_distance) then
         nearest_idx = idx
         nearest_distance = d
      end
   end
   local active_tile = adj_tiles[nearest_idx]
   -- print("active_tile = " .. inspect(active_tile))
   local tx = active_tile[1] + 1 + engine.gui.map_x
   local ty = active_tile[2] + ((tx % 2 == 1) and 1 or 0) + engine.gui.map_y

   if (tx > 0 and tx <= map.width and ty > 0 and ty <= map.height) then
       self.active_tile = {tx, ty}
       -- print(string.format("active tile = %d:%d", tx, ty))
   end
end

function Renderer:_action_kind(tile)
   local kind = 'default'
   local u = self.engine:get_selected_unit()
   if (u and tile) then
      local tx, ty = table.unpack(tile)
      local tile = self.engine.map.tiles[tx][ty]
      local actions_map = u.data.actions_map
      if (actions_map.merge[tile.uniq_id]) then
         kind = 'merge'
      elseif (actions_map.attack[tile.uniq_id]) then
         kind = 'attack'
      -- move to the tile if it is free
      -- hilight it the tile, even if there is our unit, i.e. we can pass *through* it
      elseif (actions_map.move[tile.uniq_id] and not(tile.unit)) then
         kind = 'move'
      end
   end
   return kind
end


function Renderer:_draw_cursor()
   local state, x, y = SDL.getMouseState()
   local kind = self:_action_kind(self.active_tile)
   local texture = self.theme:get_cursor(kind)
   local cursor_size = self.theme.data.cursors.size
   local dst = { w = cursor_size, h = cursor_size, x = x, y = y }
   assert(self.sdl_renderer:copy(texture, nil, dst))
end


function Renderer:_draw_active_hex_info()
   local engine = self.engine
   local map = engine.map
   local sdl_renderer = self.sdl_renderer
   local x, y = table.unpack(self.active_tile)
   local w,h = self.window:getSize()

   local render_label = function(surface)
      assert(surface)
      local texture = assert(self.sdl_renderer:createTextureFromSurface(surface))
      local sw, sh = surface:getSize()
      local label_x = math.modf(w/2 - sw/2)
      local label_y = 25 - (sh/2)
      assert(sdl_renderer:copy(texture, nil , {x = label_x, y = label_y, w = sw, h = sh}))
   end
   if (x > 0 and x <= map.width and y > 0 and y <= map.height) then
      local tile = map.tiles[x][y]
      --local str = string.format('%s (%d:%d)', tile.data.name, x-2, map.width - y - math.modf((x-2) * 0.5))
      local str = string.format('%s (%d:%d)', tile.data.name, x, y)
      local font = self.theme.fonts.active_hex
      local outline_color = self.theme.data.active_hex.outline_color
      local color = self.theme.data.active_hex.color
      font:setOutline(self.theme.data.active_hex.outline_width)
      render_label(font:renderUtf8(str, "solid", outline_color))
      font:setOutline(0)
      render_label(font:renderUtf8(str, "solid", color))
   end
end


function Renderer:_draw_world()
   self:_check_scroll(0, 0) -- check scroll by mouse position
   self:_draw_map()
   self:_draw_active_hex_info()
   self:_draw_cursor()
end


function Renderer:main_loop()
   local engine = self.engine
   local running = true
   local sdl_renderer = self.sdl_renderer
   local kind = SDL.eventWindow
   while (running) do
	  local e = SDL.waitEvent(EVENT_DELAY)
	  local t = e.type
	  if t == SDL.event.Quit then
		 running = false
	  elseif (t == SDL.event.WindowEvent) then
		 if (e.event == kind.Resized or e.event == kind.SizeChanged
			 or e.event == kind.Minimized or e.event ==  kind.Maximized) then
			self.size = table.pack(self.window:getSize())
			engine:update_shown_map()
		 end
      elseif (t == SDL.event.KeyUp) then
         if (e.keysym.sym == SDL.key.e) then
            engine:end_turn()
         end
      elseif (t == SDL.event.MouseMotion) then
         self:_recalc_active_tile()
      elseif (t == SDL.event.MouseButtonUp) then
         self:_recalc_active_tile()
         local x, y = table.unpack(self.active_tile)
         if (e.button == SDL.mouseButton.Left) then
            local action_kind = self:_action_kind(self.active_tile)
            engine:click_on_tile(x,y, action_kind)
         elseif(e.button == SDL.mouseButton.Right) then
            engine:unselect_unit()
         end
      elseif (t == SDL.event.MouseWheel) then
         self:_check_scroll(e.x, e.y) -- check scroll by mouse wheel
	  end
	  sdl_renderer:clear()
	  self:_draw_world()
	  sdl_renderer:present()
   end
end


return Renderer
