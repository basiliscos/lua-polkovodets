--[[

Copyright (C) 2015,2016 Ivan Baidakou

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
local DetachPanel = require ('polkovodets.gui.DetachPanel')

local UnitPanel = {}
UnitPanel.__index = UnitPanel
setmetatable(UnitPanel , HorizontalPanel)

function UnitPanel.create(engine)
  local o = HorizontalPanel.create(engine)
  setmetatable(o, UnitPanel)

  o.button_geometry = {
    w = engine.renderer.theme.buttons.end_turn.normal.w,
    h = engine.renderer.theme.buttons.end_turn.normal.h
  }

  o.buttons = {}
  o.button_list = {}
  local add_button = function(key)
    local button = Button.create(engine, {
      hint = engine:translate('ui.button.' .. key),
    })
    table.insert(o.drawing.objects, button)
    table.insert(o.button_list, button)
    o.buttons[key] = button
  end
  add_button('change_orientation')
  add_button('detach')
  add_button('information')

  o.callbacks = {
    change_orientation = function()
      local u = engine.state:get_selected_unit()
      if (u) then
        u:change_orientation()
      end
      return true
    end,
    information = function()
      return true
    end,
    detach = function()
      local u = engine.state:get_selected_unit()
      if (u and #u.data.attached > 0) then
        local attached_units = #u.data.attached
        if (attached_units == 1) then
          local subordinated = u.data.attached[1]
          subordinated:update_actions_map()
          engine.state:set_selected_unit(subordinated)
        else
          engine.state:activate_panel('detach_panel', true)
        end
        engine.reactor:publish("ui.update")
      end
      return true
    end,
  }

  local detach_panel = DetachPanel.create(engine, o.buttons.detach.id)
  o.detach_panel = detach_panel
  table.insert(o.drawing.objects, detach_panel)

  return o
end

function UnitPanel:bind_ctx(context)
  local engine = self.engine
  local theme = assert(context.renderer.theme)
  local gamepanel_ctx = _.clone(context, true)
  local content_w = self.button_geometry.w * #self.button_list
  local content_h = self.button_geometry.h
  gamepanel_ctx.content_size = { w = content_w, h = content_h}

  local window = assert(context.window)
  local x = 0
  local y = window.h - (self.contentless_size.h + content_h)
  gamepanel_ctx.x = x
  gamepanel_ctx.y = y

  -- generic buttons context
  gamepanel_ctx.button = {}
  for idx, button in pairs(self.button_list) do
    gamepanel_ctx.button[button.id] = {
      x = x + self.contentless_size.dx +  self.button_geometry.w * (idx - 1),
      y = y + self.contentless_size.dy,
    }
  end

  local u = self.engine.state:get_selected_unit()
  -- specific button context
  local can_change_orientation = u and 'available' or 'disabled'
  print(can_change_orientation)
  gamepanel_ctx.button[self.buttons.change_orientation.id].image = theme.buttons.change_orientation[can_change_orientation]
  gamepanel_ctx.button[self.buttons.change_orientation.id].callback = self.callbacks.change_orientation

  gamepanel_ctx.button[self.buttons.information.id].image = theme.buttons.information.disabled
  gamepanel_ctx.button[self.buttons.information.id].callback = self.callbacks.information

  local detach_state = 'disabled'
  if (u and #u.data.attached > 0) then
    detach_state = 'available'
    if (#u.data.attached == 1) then
      local hint = engine:translate('ui.button.detach_unit', {name = u.data.attached[1].name })
      self.buttons.detach.hint = hint
    else
      self.buttons.detach.hint = engine:translate('ui.button.detach')
    end
  end
  gamepanel_ctx.button[self.buttons.detach.id].image = theme.buttons.detach[detach_state]
  gamepanel_ctx.button[self.buttons.detach.id].callback = self.callbacks.detach

  _.each(self.drawing.objects, function(k, v) v:bind_ctx(gamepanel_ctx) end)

  HorizontalPanel.bind_ctx(self, gamepanel_ctx)
end

function UnitPanel:unbind_ctx(context)
  _.each(self.drawing.objects, function(k, v) v:unbind_ctx(context) end)
  HorizontalPanel.unbind_ctx(self, context)
end

function UnitPanel:draw()
  -- drawing order generally does not matter
  HorizontalPanel.draw(self)
  _.each(self.drawing.objects, function(k, v) v:draw() end)
end

return UnitPanel
