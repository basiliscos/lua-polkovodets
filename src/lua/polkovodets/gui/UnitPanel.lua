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
local Widget = require ('polkovodets.gui.Widget')
local DetachPanel = require ('polkovodets.gui.DetachPanel')

local UnitPanel = {}
UnitPanel.__index = UnitPanel
setmetatable(UnitPanel , Widget)

function UnitPanel.create(engine)
  local o = Widget.create(engine)
  setmetatable(o, UnitPanel)

  local theme = engine.renderer.theme
  local state = engine.state

  o.button_geometry = {
    w = engine.renderer.theme.buttons.end_turn.normal.w,
    h = engine.renderer.theme.buttons.end_turn.normal.h
  }

  o.buttons = {}
  o.button_list = {}

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
          state:set_selected_unit(subordinated)
        else
          engine.state:activate_panel('detach_panel', true)
        end
      end
      return true
    end,
  }

  local add_button = function(key, image)
    local button = Button.create(engine, {
      image    = image,
      hint     = engine:translate('ui.button.' .. key),
      callback = o.callbacks[key],
    })
    table.insert(o.drawing.objects, button)
    table.insert(o.button_list, button)
    o.buttons[key] = button
  end

  add_button('change_orientation', theme.buttons.change_orientation.disabled)
  add_button('information', theme.buttons.information.disabled)
  add_button('detach', theme.buttons.detach.disabled)

  local detach_panel = DetachPanel.create(engine, o.buttons.detach.id)
  o.detach_panel = detach_panel
  table.insert(o.drawing.objects, detach_panel)

  return o
end

function UnitPanel:bind_ctx(context)
  local engine = self.engine
  local state = engine.state
  local theme = assert(context.renderer.theme)
  local gamepanel_ctx = _.clone(context, true)
  local content_w = self.button_geometry.w * #self.button_list
  local content_h = self.button_geometry.h

  local window = assert(context.window)
  local x = 0
  local y = window.h - (self.contentless_size.h + content_h)

  -- generic buttons context
  gamepanel_ctx.button = {}
  for idx, button in pairs(self.button_list) do
    gamepanel_ctx.button[button.id] = {
      x = x + self.contentless_size.dx +  self.button_geometry.w * (idx - 1),
      y = y + self.contentless_size.dy,
    }
  end

  local unit_change_listener = function(value)
    local u = self.engine.state:get_selected_unit()
    local can_change_orientation = u and 'available' or 'disabled'
    self.buttons.change_orientation:update_data({ image = theme.buttons.change_orientation[can_change_orientation] })

    local can_view_information = u and 'available' or 'disabled'
    self.buttons.information:update_data({ image = theme.buttons.information[can_view_information]} )

    local detach_state = 'disabled'
    local detach_hint
    if (u and #u.data.attached > 0) then
      detach_state = 'available'
      detach_hint = (#u.data.attached == 1)
        and engine:translate('ui.button.detach_unit', {name = u.data.attached[1].name })
         or engine:translate('ui.button.detach')
    else
      detach_hint = engine:translate('ui.button.detach')
    end
    self.buttons.detach:update_data({
      image = theme.buttons.detach[detach_state],
      hint  = detach_hint,
    })

  end

  _.each(self.drawing.objects, function(k, v) v:bind_ctx(gamepanel_ctx) end)

  -- refresh to actual values
  unit_change_listener(state:get_selected_unit())

  engine.reactor:subscribe("unit.selected", unit_change_listener)
  self.drawing.unit_change_listener = unit_change_listener
  self.drawing.context = gamepanel_ctx
  Widget.update_drawer(self, x, y, content_w, content_h)
end

function UnitPanel:unbind_ctx(context)
  _.each(self.drawing.objects, function(k, v) v:unbind_ctx(context) end)

  self.engine.reactor:unsubscribe("unit.selected", self.drawing.unit_change_listener)
  self.drawing.unit_change_listener = nil
  self.drawing.context = nil
end

function UnitPanel:draw()
  -- drawing order generally does not matter
  Widget.draw(self)
  _.each(self.drawing.objects, function(k, v) v:draw() end)

end

return UnitPanel
