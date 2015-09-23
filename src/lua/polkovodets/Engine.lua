local Engine = {}
Engine.__index = Engine


function Engine.create()
   local e = {
	  turn = 0,
	  gui = {
		 map_x = 0,
		 map_y = 0,
		 -- number of tiles drawn to screen
		 map_sw = 0,
		 map_sh = 0,
		 -- position where to draw first tile
		 map_sx = 0,
		 map_sy = 0,

	  },
	  options = {
		 show_grid = true,
	  }
   }
   setmetatable(e,Engine)
   return e
end


function Engine:set_map(map)
   assert(self.renderer)
   assert(map)
   self.map = map

   self:update_shown_map()
   map:prepare()
end

function Engine:update_shown_map()
   local map = self.map
   self.gui.map_sx = -map.terrain.hex_x_offset
   self.gui.map_sy = -map.terrain.hex_height

   -- calculate drawn number of tiles
   local w, h = self.renderer:get_size()
   local step = 0
   local ptr = self.gui.map_sx
   while(ptr < w) do
	  step = step + 1
	  ptr = ptr + map.terrain.hex_x_offset
   end
   self.gui.map_sw = step

   step = 0
   ptr = self.gui.map_sy
   while(ptr < h) do
	  step = step + 1
	  ptr = ptr + map.terrain.hex_height
   end
   self.gui.map_sh = step
   print("visible tiles area: " .. self.gui.map_sw .. "x" .. self.gui.map_sh)
end


function Engine:get_map() return self.map end


function Engine:get_scenarios_dir() return 'data/scenarios' end
function Engine:get_maps_dir() return 'data/maps' end
function Engine:get_terrains_dir() return 'data/maps' end
function Engine:get_terrain_icons_dir() return 'data/gfx/terrain' end
function Engine:get_nations_icons_dir() return 'data/gfx/flags' end
function Engine:get_nations_dir() return 'data/nations' end
function Engine:get_theme_dir() return 'data/themes/default' end

function Engine:set_renderer(renderer)
   self.renderer = renderer
end

function Engine:set_scenario(scenario)
   self.turn = 1
   self.scenario = scenario
end
function Engine:get_scenario(scenario) return self.scenario end

function Engine:set_nations(nations)
   self.nations = nations
   -- nations hash
   local nation_for = {}
   for _,nation in pairs(nations) do
	  local key = nation.data.key
	  nation_for[key] = nation
   end
   self.nation_for = nation_for
end

function Engine:set_flags(flags) self.flags = flags end


function Engine:current_turn() return self.turn end

return Engine
