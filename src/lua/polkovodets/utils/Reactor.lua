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
  local postponed   = {}
  for idx, channel in pairs(channels) do
    subscribers[channel] = OrderedSet.new()
    postponed[channel] = {}
  end

  local o = {
    masked      = false,
    channels    = channels,
    subscribers = subscribers,
    postponed   = postponed,
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
  if (not self.masked) then
    for idx, cb in existing_subscribers:pairs() do
      cb(channel, ...)
    end
  else
    local args = { ... }
    local queue = self.postponed[channel]
    table.insert(queue, args)
  end
end

function Reactor:mask_events(value)
  self.masked = value
end

function Reactor:replay_masked_events()
  -- find non-empty queue with events
::FIND_EVENS::
  local queue, channel = nil, nil
  for idx, c in pairs(self.channels) do
    local q = self.postponed[c]
    if (#q > 0) then
      queue, channel = q, c
      break
    end
  end

  if (queue) then
    print("channel " .. channel .. "  has " .. #queue .. " events")
    local unique_queue = {}
    local zero_args = false
    while (#queue > 0) do
      local args = table.remove(queue, 1)
      if (#args == 0) then
        if (not zero_args) then
          table.insert(unique_queue, args)
          zero_args = true
        end
      else
        table.insert(unique_queue, args)
      end
    end

    -- actual replay
    local existing_subscribers = assert(self.subscribers[channel])
    for i, args in pairs(unique_queue) do
      for idx, cb in existing_subscribers:pairs() do
        cb(channel, table.unpack(args))
      end
    end
    goto FIND_EVENS
  end
end

return Reactor
