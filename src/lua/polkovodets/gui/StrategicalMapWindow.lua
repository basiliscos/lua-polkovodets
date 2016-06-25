--[[

Copyright (C) 2016 Ivan Baidakou

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

local _ = require ("moses")
local inspect = require('inspect')

local Widget = require 'polkovodets.gui.Widget'
local Image = require 'polkovodets.utils.Image'
local Region = require 'polkovodets.utils.Region'

local StrategicalMapWindow = {}
StrategicalMapWindow.__index = StrategicalMapWindow
setmetatable(StrategicalMapWindow, Widget)

local FONT_SIZE = 12
local AVAILABLE_COLOR = 0xAAAAAA
local HILIGHT_COLOR = 0xFFFFFF


function StrategicalMapWindow.create(engine)
  local o = Widget.create(engine)
  setmetatable(o, StrategicalMapWindow)
  o.drawing.content_fn = nil
  o.content = {}
  o.record = data
  local theme = engine.gear:get("theme")

  o.text = {
    font  = theme:get_font('default', FONT_SIZE),
  }
  o.drawing.position = {0, 0}

  return o
end

function StrategicalMapWindow:_construct_gui()

  local w, h = 200, 10
  local gui = {}
  gui.content_size = {w = w, h = h}
  return gui
end

function StrategicalMapWindow:_on_ui_update(show)
  local engine = self.engine

  if (show) then
    local theme = engine.gear:get("theme")
    local sdl_renderer = engine.gear:get("renderer").sdl_renderer
    local gui = self.drawing.gui

    local x, y = table.unpack(self.drawing.position)
    local content_x, content_y = x + self.contentless_size.dx, y + self.contentless_size.dy
    local content_w, content_h = gui.content_size.w, gui.content_size.h


    self.drawing.content_fn = function()
      -- background
      assert(sdl_renderer:copy(theme.window.background.texture, nil,
        {x = content_x, y = content_y, w = content_w, h = content_h}
      ))
      Widget.draw(self)
    end

    Widget.update_drawer(self, x, y, content_w, content_h)
  end
end

function StrategicalMapWindow:bind_ctx(context)
  local engine = self.engine

  local gui = self:_construct_gui()

  local ui_update_listener = function() return self:_on_ui_update(true) end

  self.drawing.context = context
  self.drawing.ui_update_listener = ui_update_listener
  self.drawing.gui = gui

  engine.reactor:subscribe('ui.update', ui_update_listener)

  local w, h = gui.content_size.w + self.contentless_size.w, gui.content_size.h + self.contentless_size.h
  return {w, h}
end

function StrategicalMapWindow:set_position(x, y)
  self.drawing.position = {x, y}
end

function StrategicalMapWindow:unbind_ctx(context)
  self:_on_ui_update(false)
  self.engine.reactor:unsubscribe('ui.update', self.drawing.ui_update_listener)
  self.drawing.ui_update_listener = nil
  self.drawing.context = nil
end

function StrategicalMapWindow:draw()
  self.drawing.content_fn()
end


return StrategicalMapWindow
