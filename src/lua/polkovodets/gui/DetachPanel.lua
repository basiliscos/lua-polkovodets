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

local DetachPanel = {}
DetachPanel.__index = DetachPanel
setmetatable(DetachPanel, HorizontalPanel)

function DetachPanel.create(engine, button_anchor_id)
  local o = HorizontalPanel.create(engine)
  setmetatable(o, DetachPanel)
  o.button_geometry = {
    w = engine.renderer.theme.buttons.end_turn.normal.w,
    h = engine.renderer.theme.buttons.end_turn.normal.h
  }
  o.button_anchor_id = button_anchor_id
  o.button_list = {}

  local theme = engine.renderer.theme
  local state = engine.state

  local add_button = function()
    local idx = #o.button_list + 1

    local callback = function()
      local u = assert(engine.state:get_selected_unit())
      local subordinated = u.data.attached[idx]
      subordinated:update_actions_map()
      engine.state:activate_panel('detach_panel', false)
      engine.state:set_selected_unit(subordinated)
      return true
    end

    local button = Button.create(engine, {
      image    = theme.buttons.detach.multiple[idx],
      hint     = '',
      callback = callback,
    })
    table.insert(o.button_list, button)
  end
  -- max 2 attached units
  add_button()
  add_button()

  o.already_active = false

  return o
end

function DetachPanel:_on_ui_update(show)
  local engine = self.engine
  local context = self.drawing.context

  if (self.already_active) then
    context.events_source.remove_handler('mouse_click', self.drawing.mouse_click)
    self.drawing.mouse_click = nil
    _.each(self.drawing.objects, function(k, v) v:unbind_ctx(context) end)
    self.already_active = false
    HorizontalPanel.unbind_ctx(self, detach_ctx)
    self.drawing.objects = {}
  end

  local active_panels = engine.state:get_active_panels()
  if (active_panels.detach_panel and show) then
    self.already_active = true
    local theme = engine.renderer.theme
    local state = engine.state
    local u = engine.state:get_selected_unit()
    local units_count = #u.data.attached

    local content_size = {
      w = self.button_geometry.w * units_count,
      h = self.button_geometry.h,
    }

    local detach_ctx = _.clone(context, true)
    detach_ctx.content_size = content_size

    local button_ref = assert(context.button[self.button_anchor_id])
    local x = button_ref.x + math.modf(self.button_geometry.w/2)
    local y = button_ref.y - (self.contentless_size.h + content_size.h)
    detach_ctx.x = x
    detach_ctx.y = y

    -- bind mouse click first, as it has lower priority, i.e. when no
    -- mouse click has been handled by button, that means, user clicked
    -- outsied of buttos, and the "popup" (detach panel) should be closed
    local mouse_click = function(event)
      engine.state:activate_panel('detach_panel', false)
      return false -- allow further event propagation
    end
    context.events_source.add_handler('mouse_click', mouse_click)
    self.drawing.mouse_click = mouse_click

    for idx = 1, units_count do
      local button = self.button_list[idx]
      detach_ctx.button[button.id] = {
        x        = x + self.contentless_size.dx +  self.button_geometry.w * (idx - 1),
        y        = y + self.contentless_size.dy,
      }
      button:bind_ctx(detach_ctx)

      local hint = engine:translate('ui.button.detach_unit', {name = u.data.attached[idx].name })
      button:update_data({hint = hint})
      table.insert(self.drawing.objects, button)
    end

    HorizontalPanel.bind_ctx(self, detach_ctx)
  end

end

function DetachPanel:bind_ctx(context)
  local engine = self.engine

  local ui_update_listener = function() return self:_on_ui_update(true) end

  self.drawing.context = context
  self.drawing.ui_update_listener = ui_update_listener

  -- possibly show the panel
  ui_update_listener(true)

  engine.reactor:subscribe('ui.update', ui_update_listener)
end

function DetachPanel:unbind_ctx(context)
  local engine = self.engine
  engine.reactor:unsubscribe('ui.update', self.drawing.ui_update_listener)
  -- unbind dependencies, if the panel has been shown
  self.drawing.ui_update_listener(false)
  self.drawing.context = nil
  self.drawing.ui_update_listener = nil
end

function DetachPanel:draw()
  local active_panels = self.engine.state:get_active_panels()
  if (active_panels.detach_panel) then
    -- drawing order generally does not matter
    HorizontalPanel.draw(self)
    _.each(self.drawing.objects, function(k, v) v:draw() end)
  end
end

return DetachPanel
