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

local OrderedSet = require "OrderedSet"

local Reactor = {}
Reactor.__index = Reactor

function Reactor.create(channels)
  assert(#channels > 0)
  local subscribers = {}
  for idx, channel in pairs(channels) do
    subscribers[channel] = OrderedSet.new()
  end

  local o = {
    channels    = channels,
    subscribers = subscribers,
  }
  return setmetatable(o, Reactor)
end

function Reactor:subscribe(channel, cb)
  local existing_subscribers = assert(self.subscribers[channel])
  existing_subscribers:insert(cb)
end

function Reactor:unsubscribe(channel, cb)
  local existing_subscribers = assert(self.subscribers[channel])
  existing_subscribers:remove(cb)
end

function Reactor:publish(channel, ...)
  local existing_subscribers = assert(self.subscribers[channel], 'no ' .. channel .. " exists")
  for idx, cb in existing_subscribers:pairs() do
    cb(channel, ...)
  end
end

return Reactor
