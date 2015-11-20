#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

math.randomseed( os.time() )

local _probability = function(x)
  local p = 0.1 * (x^2.2)
  if (p > 0.995) then return 0.995 end
  if (p < 0.005) then return 0.005 end
  return p
end

local _perform_shot = function(p, shots, hits, targets)
  local initial_targets, initial_shots = targets, shots
  -- print("hits = " .. hits)
  local end_value =  ((hits < 1) and 1 or hits)
  while((shots > 0) and (targets > 0)) do
    shots = shots - 1
    for h = 1,end_value do
      local r = math.random()
      if ((r <= p) and (targets > 0)) then
        targets = targets - 1
      end
    end
  end
  return initial_targets - targets, initial_shots - shots
end


local cases = {
  {100, 100, 10, 11},
  {100, 100, 14, 11},
  {100, 100, 14, 7},
  {100, 100, 14, 4},
  {100, 50, 10, 11},
  {100, 50, 14, 11},
  {100, 50, 14, 7},
  {100, 50, 14, 4},
  {100, 100, 10, 16},
  {100, 100, 8, 10},
  {100, 100, 2, 10},
  {50, 100, 10, 11},
  {50, 100, 14, 10},
  {50, 100, 14, 7},
  {50, 100, 14, 4},
  {50, 100, 10, 16},
  {50, 100, 8, 16},
  {50, 100, 2, 10},
  {100, 20, 10, 11},
  {100, 20, 14, 11},
  {100, 20, 14, 7},
  {100, 20, 14, 4},
  {100, 20, 10, 16},
  {100, 20, 8, 16},
  {100, 20, 2, 16},
  {20, 100, 10, 11},
  {20, 100, 14, 11},
  {20, 100, 14, 7},
  {20, 100, 14, 4},
  {20, 100, 10, 16},
  {20, 100, 8, 16},
  {20, 100, 2, 16},
  {10, 300, 10, 3},
  {10, 300, 15, 3},
  {10, 300, 20, 3},
  {10, 300, 30, 3},
}

for idx, case in pairs(cases) do
  local shots, targets, a, d = table.unpack(case)
  local p = _probability(a/d)
  local hits = math.modf(a/d)
  local casualities, shots_performed = _perform_shot(p, shots, hits, targets)
  print(
    string.format("[a=%02d, d=%02d, p=%f] shots %03d max times on %03d targets, hits: %03d casualities with %03d shots",
      a, d, p, shots, targets, casualities, shots_performed
    )
  )
end
