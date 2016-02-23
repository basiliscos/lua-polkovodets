--[[

Copyright (C) 2015, 2016 Ivan Baidakou

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

local inspect = require('inspect')
local _ = require ("moses")

local Image = require 'polkovodets.utils.Image'

-- preload
local GamePanel = require ('polkovodets.gui.GamePanel')
local UnitPanel = require ('polkovodets.gui.UnitPanel')
local Cursor = require ('polkovodets.gui.Cursor')
require ('polkovodets.gui.BattleDetailsWindow')
require ('polkovodets.gui.BattleSelectorPopup')
require ('polkovodets.gui.UnitInfoWindow')
require ('polkovodets.gui.WeaponCasualitiesDetailsWindow')

local Interface = {}
Interface.__index = Interface

function Interface.create(engine)
  local o = {
    engine = engine,
    context = nil,
    drawing = {
      fn          = nil,
      cursor      = Cursor.create(engine),
      helpers     = {
        active_tile_drawer = nil,
        mouse_hint_drawer = nil,
      },
      mouse_click = nil,
      objects     = {},
      obj_by_type = {
        game_panel = nil,
      },
      opened_windows = 0,
      reference_corner = nil, -- only for top window
      window_order = {}, -- key: window, value order = z-index
      active_tile_change_listener = nil,
    }
  }
  setmetatable(o, Interface)

  local game_panel = GamePanel.create(engine)
  table.insert(o.drawing.objects, game_panel)
  o.drawing.obj_by_type.game_panel = game_panel

  local unit_panel = UnitPanel.create(engine)
  table.insert(o.drawing.objects, unit_panel)
  o.drawing.obj_by_type.unit_panel = unit_panel

  engine.interface = o

  return o
end

function Interface:bind_ctx(context)
  local font = context.theme.fonts.active_hex
  local outline_color = context.theme.data.active_hex.outline_color
  local color = context.theme.data.active_hex.color

  local w, h = context.renderer.window:getSize()
  local sdl_renderer = context.renderer.sdl_renderer

  local layout_fn = function(window, content_w, content_h)
    -- calculate window center
    local order = assert(self.drawing.window_order[window])
    local x = math.modf(w/2 - content_w/2)
    local y = math.modf(h/2 - content_h/2)
    -- calculate top-level window, and put it always in the center
    if (order == self.drawing.opened_windows and not(self.drawing.reference_corner)) then
      self.drawing.reference_corner = {x, y}
    else
      -- non-top-level windows should be moved a bit top-left relative
      -- to the corner of the top one
      if (self.drawing.reference_corner) then
          -- calculate them only if we already calculated top-level window position
        local total = assert(self.drawing.opened_windows)
        local z_index = total - order
        x, y = table.unpack(self.drawing.reference_corner)
        x = x - (25 * z_index)
        y = y - (25 * z_index)
      end
    end
    return x, y
  end

  local interface_ctx = _.clone(context, true)
  interface_ctx.window = {w = w, h = h}
  interface_ctx.layout_fn = layout_fn

  local active_tile_change_listener = function(event, tile)
    local draw_fn
    if (tile) then
      local str = string.format('%s (%d:%d)', tile.data.name, tile.data.x, tile.data.y)
      local my_label = Image.create(sdl_renderer, font:renderUtf8(str, "solid", color))
      local w, h = context.renderer.window:getSize()
      local bg_texture = context.theme.window.background.texture

      local padding = 10
      local margin = 10

      local bg_region = {
        x = w - (padding + margin + my_label.w),
        y = margin,
        w = my_label.w + padding,
        h = my_label.h + padding,
      }

      local label_region = {
        x = math.modf(bg_region.x + bg_region.w/2 - my_label.w/2),
        y = margin + padding/2,
        w = my_label.w,
        h = my_label.h,
      }

       draw_fn = function()
        assert(sdl_renderer:copy(bg_texture, nil, bg_region))
        assert(sdl_renderer:copy(my_label.texture, nil, label_region))
      end
    else
      draw_fn = function() end
    end
    self.drawing.helpers.active_tile_drawer = draw_fn
  end

  local mouse_hint_change_listener = function(event, hint)
    local draw_fn
    if (hint and #hint > 0) then
      local my_label = Image.create(sdl_renderer, font:renderUtf8(hint, "solid", color))
      local w, h = context.renderer.window:getSize()
      local bg_texture = context.theme.window.background.texture

      local padding = 10
      local margin = 10

      local bg_region = {
        x = margin,
        y = margin,
        w = my_label.w + padding,
        h = my_label.h + padding,
      }

      local label_region = {
        x = math.modf(bg_region.x + bg_region.w/2 - my_label.w/2),
        y = margin + padding/2,
        w = my_label.w,
        h = my_label.h,
      }

      draw_fn = function()
        assert(sdl_renderer:copy(bg_texture, nil, bg_region))
        assert(sdl_renderer:copy(my_label.texture, nil, label_region))
      end
    else
      draw_fn = function() end
    end
    self.drawing.helpers.mouse_hint_drawer = draw_fn
  end

  self.engine.reactor:subscribe('map.active_tile.change', active_tile_change_listener)
  self.engine.reactor:subscribe('mouse-hint.change', mouse_hint_change_listener)
  active_tile_change_listener()
  mouse_hint_change_listener()

  local draw_fn = function()
    self.drawing.helpers.active_tile_drawer()
    self.drawing.helpers.mouse_hint_drawer()
    _.each(self.drawing.objects, function(k, v) v:draw() end)
    self.drawing.cursor:draw()
  end

  _.each(self.drawing.objects, function(k, v) v:bind_ctx(interface_ctx) end)
  self.drawing.cursor:bind_ctx(interface_ctx)


  self.drawing.fn = draw_fn
  self.drawing.active_tile_change_listener = active_tile_change_listener
  self.drawing.mouse_hint_change_listener = mouse_hint_change_listener
  self.context = interface_ctx
end

function Interface:unbind_ctx(context)
  self.drawing.cursor:unbind_ctx(context)
  _.each(self.drawing.objects, function(k, v) v:unbind_ctx(context) end)
  self.drawing.fn = nil
  self.engine.reactor:unsubscribe('map.active_tile.change', self.drawing.active_tile_change_listener)
  self.engine.reactor:unsubscribe('mouse-hint.change', self.drawing.mouse_hint_change_listener)
end

function Interface:draw()
  self.drawing.fn()
end

function Interface:add_window(id, data)
  -- constuct short class name, by removing _ and capitalizing
  -- 1st letters
  local class_name = ''
  local start_search = 1
  local do_search = true
  while (do_search) do
    local s, e = string.find(id, '_', start_search, true)
    if (s) then
      local capital = string.upper(string.sub(id, start_search, start_search))
      local tail = string.sub(id, start_search + 1, s - 1)
      class_name = class_name .. capital .. tail
      start_search = e + 1
    else
      do_search = false
      local capital = string.upper(string.sub(id, start_search, start_search))
      local tail = string.sub(id, start_search + 1)
      class_name = class_name .. capital .. tail
    end
  end
  -- print("class for " .. id .. " " .. class_name)
  local class = require ('polkovodets.gui.' .. class_name)
  local window = class.create(self.engine, data)

  table.insert(self.drawing.objects, window)

  local opened_windows = self.drawing.opened_windows
  opened_windows = opened_windows + 1
  self.drawing.opened_windows = opened_windows
  self.drawing.window_order[window] = opened_windows
  self.drawing.reference_corner = nil -- will be filled by layering_fn

  window:bind_ctx(self.context)

  print("created window: " .. class_name)
  self.engine.reactor:publish("view.update")
end

function Interface:remove_window(window, do_not_emit_update)
  local idx
  for i, o in ipairs(self.drawing.objects) do
    if (o == window) then
      idx = i
      break
    end
  end
  assert(idx, "cannot find window to remove")
  window:unbind_ctx(self.context)

  local opened_windows = self.drawing.opened_windows
  opened_windows = opened_windows - 1
  self.drawing.opened_windows = opened_windows
  self.drawing.window_order[window] = nil
  self.drawing.reference_corner = nil -- will be filled by layering_fn

  -- need to trigger windows re-layering
  local prev_window
  for window, order in pairs(self.drawing.window_order) do
    if (order == opened_windows) then
      prev_window = window
    end
  end
  if (prev_window) then
    prev_window:unbind_ctx(self.context)
    prev_window:bind_ctx(self.context)
  end

  table.remove(self.drawing.objects, idx)
  print("window " .. idx .. " removed")
  if (not do_not_emit_update) then
    self.engine.reactor:publish("view.update")
  end
end

return Interface
