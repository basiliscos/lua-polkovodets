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

local inspect = require('inspect')
local _ = require ("moses")

local Button = require ('polkovodets.gui.Button')
local HorizontalPanel = require ('polkovodets.gui.HorizontalPanel')
local Image = require 'polkovodets.utils.Image'

local BattleDetailsWindow = {}
BattleDetailsWindow.__index = BattleDetailsWindow
setmetatable(BattleDetailsWindow, HorizontalPanel)

function BattleDetailsWindow.create(engine)
  local o = HorizontalPanel.create(engine)
  setmetatable(o, BattleDetailsWindow)
  o.ctx_bound = false
  o.drawing.content_fn = nil

  local weapon_classes = engine.unit_lib.weapons.classes.list

  assert (#weapon_classes > 0)
  -- print(inspect(weapon_classes))
  local class_icon = weapon_classes[1]:get_icon()
  local classes_h = class_icon.h * #weapon_classes


  local text_size = 12
  local font = engine.renderer.theme:get_font('default', text_size)
  local text_color = 0xFFFFFF

  local create_image = function(surface)
    return Image.create(engine.renderer.sdl_renderer, surface)
  end

  local was_label = create_image(font:renderUtf8(engine:translate('ui.window.battle_details.header.was'), "solid", text_color))
  local casualities_label = create_image(font:renderUtf8(engine:translate('ui.window.battle_details.header.casualities'), "solid", text_color))

  o.content = {
    text = {
      font  = font,
      color = text_color,
      size  = text_size,
    },
    header = {
    },
    mouse_click = nil,
    mouse_move  = nil,
  }

  -- initiator columns
  local header_dx = 10
  local labels = {
    {
      label = was_label,
      dx    = class_icon.w + header_dx,
      dy    = 0,
    },
  }
  table.insert(labels, {
    label = casualities_label,
    dx    = labels[#labels].dx + header_dx + labels[#labels].label.w,
    dy    = labels[#labels].dy,
  })
  -- print(inspect(labels))

  -- separator
  local separator = {
    dx    = labels[#labels].dx + header_dx + labels[#labels].label.w + 5,
    dy    = labels[#labels].dy + labels[#labels].label.h + 1,
    w     = 1,
    h     = classes_h,
    color = text_color,
  }

  -- passive columns
  table.insert(labels, {
    label = was_label,
    dx    = separator.dx + separator.w + 5 + header_dx,
    dy    = labels[#labels].dy,
  })
  table.insert(labels, {
    label = casualities_label,
    dx    = labels[#labels].dx + header_dx + labels[#labels].label.w,
    dy    = labels[#labels].dy,
  })

  local header_w = labels[#labels].dx + header_dx + labels[#labels].label.w + header_dx
  local header_h = labels[1].label.h + 2
  o.content.header = {
    w         = header_w,
    h         = header_h,
    labels    = labels,
    separator = separator,
  }

  local content_w = header_w
  local content_h = classes_h + header_h

  o.content.size = {
    w = content_w,
    h = content_h,
  }

  -- print(string.format("content size %d x %d", content_w, content_h))
  return o
end

function BattleDetailsWindow:bind_ctx(context)
  local engine = self.engine
  if (engine.state.popups.battle_details_window) then
    self.ctx_bound = true

    local theme = assert(context.renderer.theme)
    local details_ctx = _.clone(context, true)
    local content_w = self.content.size.w
    local content_h = self.content.size.h
    details_ctx.content_size = { w = content_w, h = content_h}

    local window = assert(context.window)
    local x = math.modf(window.w/2 - content_w/2)
    local y = math.modf(window.h/2 - content_h/2)
    details_ctx.x = x
    details_ctx.y = y

    local weapon_classes = engine.unit_lib.weapons.classes.list
    local weapon_class_icon = weapon_classes[1]:get_icon()

    local content_x, content_y = x + self.contentless_size.dx, y + self.contentless_size.dy

    local max_x = x + content_w + self.contentless_size.w
    local max_y = y + content_h + self.contentless_size.h
    local is_over_window = function(mx, my)
      local over = ((mx >= x) and (mx <= max_x)
                and (my >= y) and (my <= max_y))
      return over
    end

    local sdl_renderer = assert(context.renderer.sdl_renderer)
    self.drawing.content_fn = function()

      -- background
      assert(sdl_renderer:copy(theme.window.background.texture, nil,
        {x = content_x, y = content_y, w = content_w, h = content_h}
      ))

      -- unit class icons
      local header_h = self.content.header.h
      for idx, class in ipairs(weapon_classes) do
        local icon = class:get_icon()
        assert(sdl_renderer:copy(icon.texture, nil,
          {x = content_x, y = content_y + header_h + (weapon_class_icon.h * (idx - 1)), w = weapon_class_icon.w, h = weapon_class_icon.h}
        ))
      end

      -- table header
      for idx, label_info in ipairs(self.content.header.labels) do
        local label = label_info.label
        assert(sdl_renderer:copy(label.texture, nil,
          {x = content_x + label_info.dx, y = content_y + label_info.dy, w = label.w, h = label.h}
        ))
      end

      -- initiator/passive separator
      local prev_color = sdl_renderer:getDrawColor()
      assert(sdl_renderer:setDrawColor(self.content.header.separator.color))
      assert(sdl_renderer:drawLine({
        x1 = content_x + self.content.header.separator.dx,
        y1 = content_y + self.content.header.separator.dy,
        x2 = content_x + self.content.header.separator.dx,
        y2 = content_y + self.content.header.separator.dy + self.content.header.separator.h,
      }))
      assert(sdl_renderer:setDrawColor(prev_color))

    end

    _.each(self.drawing.objects, function(k, v) v:bind_ctx(details_ctx) end)

    local mouse_click = function(event)
      if (is_over_window(event.x, event.y)) then
        -- print("ignore")
        -- click hasn't been processed by button, just ignore it
      else
        engine.state.popups.battle_details_window = false
        engine.mediator:publish({ "view.update" })
      end
      return true -- stop further event propagation
    end

    context.state.action = 'default'
    local mouse_move = function(event)
      return true -- stop further event propagation
    end

    context.events_source.add_handler('mouse_click', mouse_click)
    self.content.mouse_click = mouse_click
    context.events_source.add_handler('mouse_move', mouse_move)
    self.content.mouse_move = mouse_move


    HorizontalPanel.bind_ctx(self, details_ctx)
  end
end

function BattleDetailsWindow:unbind_ctx(context)
  if (self.ctx_bound and self.engine.state.popups.battle_details_window) then
    self.ctx_bound = false
    self.drawing.content_fn = nil
    _.each(self.drawing.objects, function(k, v) v:unbind_ctx(context) end)
    context.events_source.remove_handler('mouse_click', self.content.mouse_click)
    context.events_source.remove_handler('mouse_move', self.content.mouse_move)
    self.content.mouse_click = nil
    self.content.mouse_move = nil
    HorizontalPanel.unbind_ctx(self, context)
  end
end

function BattleDetailsWindow:draw()
  if (self.engine.state.popups.battle_details_window) then
    -- drawing order: background, window decorations, controls
    self.drawing.content_fn()
    HorizontalPanel.draw(self)
    _.each(self.drawing.objects, function(k, v) v:draw() end)
  end
end

return BattleDetailsWindow
