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

local _ = require ("moses")
local SDL	= require "SDL"
local image = require "SDL.image"
local inspect = require('inspect')
local ttf = require "SDL.ttf"

local Image = require 'polkovodets.utils.Image'
local Theme = require 'polkovodets.Theme'
local Tile = require 'polkovodets.Tile'

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
                                       ['default'       ] = 1,
                                       ['move'          ] = 2,
                                       ['merge'         ] = 3,
                                       ['battle'        ] = 6,
                                       ['fire/artillery'] = 4,
                                       ['fire/anti-air' ] = 7,
                                       ['fire/bombing'  ] = 5,
                                       ['land'          ] = 8,
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
      local my_image = Image.create(self.sdl_renderer, sub_surface)
      table.insert(cache, my_image)
   end
   print(path .. ": " .. #cache .. " images")
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
   local my_image = Image.create(self.sdl_renderer, surface)
   textures_cache[path] = my_image
   return my_image
end


function Renderer:_draw_map()
  local engine = self.engine
  local map = engine:get_map()
  local sdl_renderer = self.sdl_renderer
  local terrain = map.terrain

  local start_map_x = engine.gui.map_x
  local start_map_y = engine.gui.map_y

  local map_sw = (engine.gui.map_sw > map.width) and map.width or engine.gui.map_sw
  local map_sh = (engine.gui.map_sh > map.height) and map.height or engine.gui.map_sh

  local draw = function(draw_at_tile)
    for i = 1,map_sw do
      local tx = i + start_map_x
      for j = 1,map_sh do
        local ty = j + start_map_y
        if (tx <= map.width and ty <= map.height) then
          draw_at_tile(tx, ty)
        end
      end
    end
  end

  local u = engine:get_selected_unit()
  local context = {
    cache = {
      drawn_battle_tiles = {},
    },
    tile_visibility_test = function(tile)
      local x, y = tile.x, tile.y
      local result
        =   (x >= start_map_x and x <= map_sw)
        and (x >= start_map_y and x <= map_sh)
    end,
    tile_geometry = {
      w        = terrain.hex_width,
      h        = terrain.hex_height,
      x_offset = terrain.hex_x_offset,
      y_offset = terrain.hex_y_offset,
    },
    map           = map,
    theme         = self.theme,
    selected_unit = u,
    screen        = {
      offset = {
        engine.gui.map_sx - (engine.gui.map_x * terrain.hex_x_offset),
        engine.gui.map_sy - (engine.gui.map_y * terrain.hex_height),
      }
    },
    active_layer = engine.active_layer,
    subordinated = {}, -- k: tile_id, v: unit
  }

  local active_x, active_y = table.unpack(self.active_tile)
  local active_tile = map.tiles[active_x][active_y]
  local hilight_unit = u or (active_tile and active_tile:get_unit(engine.active_layer))
  if (hilight_unit) then
    for idx, subordinated_unit in pairs(hilight_unit:get_subordinated(true)) do
      local tile = subordinated_unit.tile
      -- tile could be nil if unit is attached to some other
      if (tile) then
        context.subordinated[tile.id] = true
      end
    end
  end

  -- draw landscape
  draw(function(tx, ty)
    local tile = assert(map.tiles[tx][ty], string.format("tile [%d:%d] not found", tx, ty))
    tile:draw(sdl_renderer, context)
  end)

  -- draw current turn current unit history
  local get_shown_records = function()
    local records = {}
    local current_turn = engine:current_turn()
    if (u) then
      records = _.select(engine.history:get_records(current_turn), function(k, v)
        local unit_id = v.context.unit_id
        return (unit_id and unit_id == u.id)
      end)
    else
      if (engine:show_history()) then
        local last_opponent_turn = (engine.current_player_idx == engine.total_players) and current_turn or current_turn - 1
        records = _.select(engine.history:get_records(last_opponent_turn), function(k, v)
          local unit_id = v.context.unit_id
          local unit = self.engine:get_unit(unit_id)
          return unit.player ~= self.engine:get_current_player()
        end)
      end
    end
    return records
  end

  local records = get_shown_records()
  for idx, record in pairs(records) do
    record:draw(sdl_renderer, context)
  end
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
   local state, x, y = SDL.getMouseState()
   local active_tile = self.engine:pointer_to_tile(x,y)
   if (active_tile) then self.active_tile = active_tile end
end

function Renderer:_action_kind(tile)
   local kind = 'default'
   local u = self.engine:get_selected_unit()
   if (u and tile) then
      local tx, ty = table.unpack(tile)
      local tile = self.engine.map.tiles[tx][ty]
      local actions_map = u.data.actions_map
      if (actions_map.merge[tile.id]) then
         kind = 'merge'
      elseif (actions_map.attack[tile.id]) then
         kind = u:get_attack_kind(tile)
      elseif (actions_map.landing[tile.id]) then
         kind = 'land'
      -- move to the tile if it is free
      -- hilight it the tile, even if there is our unit, i.e. we can pass *through* it
      elseif (actions_map.move[tile.id] and not(tile:get_unit(u:get_movement_layer()))) then
         kind = 'move'
      end
   end
   return kind
end


function Renderer:_draw_cursor()
   local state, x, y = SDL.getMouseState()
   local kind = self:_action_kind(self.active_tile)
   local cursor = self.theme:get_cursor(kind)
   local cursor_size = self.theme.data.cursors.size
   local dst = { w = cursor_size, h = cursor_size, x = x, y = y }
   assert(self.sdl_renderer:copy(cursor.texture, nil, dst))
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
         elseif (e.keysym.sym == SDL.key.t) then
            engine:toggle_layer()
         elseif (e.keysym.sym == SDL.key.h) then
            engine:toggle_history()
         elseif (e.keysym.sym == SDL.key.k) then
            engine:toggle_attack_priorities()
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
