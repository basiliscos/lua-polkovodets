local Terrain = require 'polkovodets.Terrain'
local Tile = require 'polkovodets.Tile'

local SampleData = {}
SampleData.__index = SampleData

function SampleData.generate_terrain(terrain)
  local hex_geometry = {
    width    = 60,
    height   = 50,
    x_offset = 45,
    y_offset = 25,
  }

  local icon_for = {
    fog         = "path/to/some1.png",
    frame       = "path/to/some2.png",
    participant = "path/to/some3.png",
    grid        = "path/to/some4.png",
    managed     = "path/to/some5.png",
  }

  local weather_types = {
    {id = "fair"    },
    {id = "snowing" },
  }

  local terrain_types = {
    {
      id         = "c",
      min_entr   = 0,
      max_entr   = 99,
      name       = "field",
      spot_cost  = {
        fair    = 1,
        snowing = 2,
      },
      move_cost  = {
        wheeled = {
          fair    = 2,
          snowing = 2,
        },
        leg     = {
          fair    = 1,
          snowing = 1,
        },
        air     = {
          fair    = 1,
          snowing = 1,
        },
      },
      image = {
        fair = "path/to/some6.bmp",
      }
    }
  }
  terrain:generate(hex_geometry, weather_types, terrain_types, icon_for)
end

function SampleData.generate_map(map)
  local terrain = Terrain.create(map.engine)
  SampleData.generate_terrain(terrain)
  local tiles_generator = function(terrain, x, y)
    local tile_data = {
      x            = x,
      y            = y,
      name         = 'dummy',                -- does not matter
      image_idx    = 1,                      -- does not matter
      terrain_name = 'dummy-name',           -- does not matter
      terrain_type = terrain:get_type('c'),  -- clear
    }
    return Tile.create(engine, terrain, tile_data)
  end
  map:generate(10, 10, terrain, tiles_generator)
  map.engine:set_map(map)
end

return SampleData
