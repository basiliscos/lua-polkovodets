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

local GamePanel = {}
GamePanel.__index = GamePanel
setmetatable(GamePanel, HorizontalPanel)

function GamePanel.create(engine)
  local o = HorizontalPanel.create(engine)
  local theme = engine.renderer.theme


  setmetatable(o, GamePanel)
  o.button_geometry = {
    w = engine.renderer.theme.buttons.end_turn.normal.w,
    h = engine.renderer.theme.buttons.end_turn.normal.h
  }

  o.buttons = {
    --end_turn = end_turn,
  }

  local state = engine.state
  o.callbacks = {
    end_turn = function()
      engine:end_turn()
      return true
    end,
    toggle_layer = function()
      local new_value = (state:get_active_layer() == 'air') and 'surface' or 'air'
      print("active layer " .. new_value)
      local image = theme.buttons.toggle_layer[new_value]
      o.buttons.toggle_layer:update_image(image)

      state:set_active_layer(new_value)
      return true
    end,
    toggle_history = function()
      local new_value = not state:get_recent_history()
      local button_state = new_value and 'active' or 'inactive'
      local image = theme.buttons.toggle_history[button_state]
      o.buttons.toggle_history:update_image(image)

      local actual_records = engine.history:get_actual_records()
      state:set_actual_records(actual_records)
      state:set_recent_history(new_value)
      return true
    end,
    toggle_landscape = function()
      local new_value = not state:get_landscape_only()
      local landscape_state = new_value and 'active' or 'inactive'
      local image = theme.buttons.toggle_landscape[landscape_state]
      o.buttons.toggle_landscape:update_image(image)

      state:set_selected_unit(nil)
      state:set_landscape_only(new_value)
      return true
    end
  }

  local add_button = function(key, image)
    local button = Button.create(engine, {
      image    = image,
      hint     = engine:translate('ui.button.' .. key),
      callback = o.callbacks[key],
    })
    table.insert(o.drawing.objects, button)
    o.buttons[key] = button
  end
  add_button('toggle_landscape', theme.buttons.toggle_landscape.inactive)
  add_button('toggle_history', theme.buttons.toggle_history.inactive)
  add_button('toggle_layer', theme.buttons.toggle_layer[state:get_active_layer()])
  add_button('end_turn', theme.buttons.end_turn.normal)

  return o
end

function GamePanel:bind_ctx(context)
  local theme = assert(context.renderer.theme)
  local gamepanel_ctx = _.clone(context, true)
  local content_w = self.button_geometry.w * #self.drawing.objects
  local content_h = self.button_geometry.h
  gamepanel_ctx.content_size = { w = content_w, h = content_h}

  local window = assert(context.window)
  local x = window.w - (self.contentless_size.w + content_w)
  local y = window.h - (self.contentless_size.h + content_h)
  gamepanel_ctx.x = x
  gamepanel_ctx.y = y

  -- generic buttons context
  gamepanel_ctx.button = {}
  for idx, button in pairs(self.drawing.objects) do
    gamepanel_ctx.button[button.id] = {
      x        = x + self.contentless_size.dx +  self.button_geometry.w * (idx - 1),
      y        = y + self.contentless_size.dy,
    }
  end

  _.each(self.drawing.objects, function(k, v) v:bind_ctx(gamepanel_ctx) end)

  -- actualize current values / images
  local state = self.engine.state

  local landscape_state = state:get_landscape_only() and 'active' or 'inactive'
  local landscape_image = theme.buttons.toggle_landscape[landscape_state]
  self.buttons.toggle_landscape:update_image(landscape_image)

  local history_state = state:get_recent_history() and 'active' or 'inactive'
  local history_image = theme.buttons.toggle_history[history_state]
  self.buttons.toggle_history:update_image(history_image)

  local layer_image = theme.buttons.toggle_layer[state:get_active_layer()]
  self.buttons.toggle_layer:update_image(layer_image)

  HorizontalPanel.bind_ctx(self, gamepanel_ctx)
end

function GamePanel:unbind_ctx(context)
  _.each(self.drawing.objects, function(k, v) v:unbind_ctx(context) end)
  HorizontalPanel.unbind_ctx(self, context)
end

function GamePanel:draw()
  -- drawing order generally does not matter
  HorizontalPanel.draw(self)
  _.each(self.drawing.objects, function(k, v) v:draw() end)
end

return GamePanel
