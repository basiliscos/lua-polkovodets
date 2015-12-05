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

local GamePanel = {}
GamePanel.__index = GamePanel
setmetatable(GamePanel, HorizontalPanel)

function GamePanel.create(engine)
  local o = HorizontalPanel.create(engine)
  setmetatable(o, GamePanel)
  o.button_geometry = {
    w = engine.renderer.theme.buttons.end_turn.normal.w,
    h = engine.renderer.theme.buttons.end_turn.normal.h
  }

  local end_turn = Button.create(engine, {
    hint = engine:translate('ui.button.end_turn'),
  })
  table.insert(o.drawing.objects, end_turn)
  o.buttons = {
    end_turn = end_turn,
  }

  o.callbacks = {
    end_turn = function()
      engine:end_turn()
      return true
    end,
  }

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

  gamepanel_ctx.button = {}
  for idx, button in pairs(self.drawing.objects) do
    gamepanel_ctx.button[button.id] = {
      x = x + self.contentless_size.dx +  self.button_geometry.w * (idx - 1),
      y = y + self.contentless_size.dy,
    }
  end
  gamepanel_ctx.button[self.buttons.end_turn.id].image = theme.buttons.end_turn.normal
  gamepanel_ctx.button[self.buttons.end_turn.id].callback = self.callbacks.end_turn

  _.each(self.drawing.objects, function(k, v) v:bind_ctx(gamepanel_ctx) end)

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
