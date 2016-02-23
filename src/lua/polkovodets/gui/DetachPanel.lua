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
  o.callbacks = {}
  o.ctx_bound = false

  local add_button = function()
    local button = Button.create(engine, {})
    table.insert(o.button_list, button)
    local idx = #o.button_list
    table.insert(o.callbacks, function()
      engine.state.popups.detach_panel = false
      local u = assert(engine.state.selected_unit)
      local subordinated = u.data.attached[idx]
      subordinated:update_actions_map()
      engine.state.selected_unit = subordinated
      engine.reactor:publish("view.update")
      return true
    end)
  end
  -- max 2 attached units
  add_button()
  add_button()

  return o
end

function DetachPanel:bind_ctx(context)
  local engine = self.engine
  if (engine.state.popups.detach_panel) then
    self.ctx_bound = true
    local theme = assert(context.theme)
    local u = engine.state.selected_unit
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

    for idx = 1, units_count do
      local button = self.button_list[idx]
      button.hint = engine:translate('ui.button.detach_unit', {name = u.data.attached[idx].name })
      detach_ctx.button[button.id] = {
        x        = x + self.contentless_size.dx +  self.button_geometry.w * (idx - 1),
        y        = y + self.contentless_size.dy,
        image    = assert(theme.buttons.detach.multiple[idx]),
        callback = self.callbacks[idx],
      }
      table.insert(self.drawing.objects, button)
    end

    -- bind mouse click first, as it has lower priority, i.e. when no
    -- mouse click has been handled by button, that means, user clicked
    -- outsied of buttos, and the "popup" (detach panel) should be closed
    local mouse_click = function(event)
      engine.state.popups.detach_panel = false
      return false -- allow further event propagation
    end
    context.events_source.add_handler('mouse_click', mouse_click)
    self.drawing.mouse_click = mouse_click

    _.each(self.drawing.objects, function(k, v) v:bind_ctx(detach_ctx) end)

    HorizontalPanel.bind_ctx(self, detach_ctx)
  end
end

function DetachPanel:unbind_ctx(context)
  if (self.ctx_bound and self.engine.state.popups.detach_panel) then
    self.ctx_bound = false
    _.each(self.drawing.objects, function(k, v) v:unbind_ctx(context) end)
    HorizontalPanel.unbind_ctx(self, context)
    self.drawing.objects = {}
    context.events_source.remove_handler('mouse_click', self.drawing.mouse_click)
    self.drawing.mouse_click = nil
  end
end

function DetachPanel:draw()
  if (self.engine.state.popups.detach_panel) then
    -- drawing order generally does not matter
    HorizontalPanel.draw(self)
    _.each(self.drawing.objects, function(k, v) v:draw() end)
  end
end

return DetachPanel
