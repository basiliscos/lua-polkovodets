#!/usr/bin/env lua

package.path = "?.lua;" .. "src/lua/?.lua;" .. package.path

local t = require 'Test.More'
local Converter = require 'polkovodets.Converter'
local inspect = require('inspect')

local create_iterator = function(csv_data)
   local lines = {}
   local start_line = 1
   local end_line = string.find(csv_data, "\n", start_line)
   while (end_line) do
      local line = string.sub(csv_data, start_line, end_line - 1)
      start_line = end_line + 1
      end_line = string.find(csv_data, "\n", start_line)
      table.insert(lines, line)
   end
   local line_no = 1
   return function()
      local idx = line_no
      line_no = line_no + 1
      return lines[idx]
   end

end


subtest("armed-forces-parse",
        function()
           local csv_data = [[
<weapons;target_types;classes;movement_types;categories;types;list;/>;<units;classes;definitions;/>
;weapon-target-types.json;weapon-classes.json;weapon-movement-types.json;weapon-categories.json;weapon-types.json;weapons.json;;;unit-classes.json;unit-definitions.json;
                  ]]
           local c = Converter.create(create_iterator(csv_data))
           local data = c:convert()
           ok(data, "got converted data")
           is(#data, 1, "1 rows in data")
           is_deeply(data[1],
                     {
                        units = {
                           classes = "unit-classes.json",
                           definitions = "unit-definitions.json"
                        },
                        weapons = {
                           categories = "weapon-categories.json",
                           classes = "weapon-classes.json",
                           list = "weapons.json",
                           movement_types = "weapon-movement-types.json",
                           target_types = "weapon-target-types.json",
                           types = "weapon-types.json"
                        },
                     },
                     "1-st item is correct"
           )
        end
)

subtest("weapons-parse",
        function()
           local csv_data = [[
name;nation;weap_type;weap_class;weap_category;target_type;movement;move_type;range;<attack;soft;hard;air;naval;/>;def_ground;def_air;icon_id;;;;;
Маневренный бронеход "Витязь" обр.1930;rus;wt_tankInfMid;wk_armor;wc_tank;hard;5;tracked;1;*;11;15;0;0;*;11;9;weapon\rus\armory\RusTank01.png;weapon\rus\armory;\;RusTank01;.png;weapon\rus\armory\RusTank01.png
Стрелковое отделение обр.1935;rus;wt_infant;wk_infant;wc_infant ;soft;3;leg;1;*;2;1;0;0;*;6;7;weapon\rus\infantry\RusInf01.png;weapon\rus\infantry;\;RusInf01;.png;weapon\rus\infantry\RusInf01.png
                  ]]
           local c = Converter.create(create_iterator(csv_data))
           local data = c:convert()
           ok(data, "got converted data")
           is(#data, 2, "2 rows in data")
           is_deeply(data[1],
                     {
                        attack = {
                           air = "0",
                           hard = "15",
                           naval = "0",
                           soft = "11"
                        },
                        def_air = "9",
                        def_ground = "11",
                        icon_id = "weapon/rus/armory/RusTank01.png",
                        move_type = "tracked",
                        movement = "5",
                        name = 'Маневренный бронеход "Витязь" обр.1930',
                        nation = "rus",
                        range = "1",
                        target_type = "hard",
                        weap_category = "wc_tank",
                        weap_class = "wk_armor",
                        weap_type = "wt_tankInfMid",
                     },
                     "1-st item is correct"
           )
           is_deeply(data[2],
                     {
                        attack = {
                           air = "0",
                           hard = "1",
                           naval = "0",
                           soft = "2"
                        },
                        def_air = "7",
                        def_ground = "6",
                        icon_id = "weapon/rus/infantry/RusInf01.png",
                        move_type = "leg",
                        movement = "3",
                        name = "Стрелковое отделение обр.1935",
                        nation = "rus",
                        range = "1",
                        target_type = "soft",
                        weap_category = "wc_infant ",
                        weap_class = "wk_infant",
                        weap_type = "wt_infant"
                     },
                     "2-nd item is correct"
           )
        end
)


subtest("units-parse",
        function()
           local csv_data = [[
id;name;nation;units_class;size;initiative;spotting;ammo;_;_;_;_;icon_path;!staff;k;v;/!
1;Пехотная дивизия штата 1401/30;rus;inf;L;1;1;5;units\rus;\;RusInf01;units\rus\RusInf01;units\rus\RusInf01;;wt_tankInfMid;50;
;;;;;;;;;;;;;;wt_infant;324;
;;;;;;;;;;;;;;wt_MG;108;
2;ПД;rus;inf;L;1;1;5;units\rus;\;RusInf01;units\rus\RusInf01;units\rus\RusInf01;;wt_tankInfMid;50;
;;;;;;;;;;;;;;wt_infant;324;
                  ]]
           local c = Converter.create(create_iterator(csv_data))
           local data = c:convert()
           ok(data, "got converted data")
           is(#data, 2, "2 rows in data")
           is_deeply(data[1],
                     {
                        ammo = "5",
                        icon_path = "units/rus/RusInf01",
                        id = "1",
                        initiative = "1",
                        name = "Пехотная дивизия штата 1401/30",
                        nation = "rus",
                        size = "L",
                        spotting = "1",
                        staff = {
                           wt_MG = "108",
                           wt_infant = "324",
                           wt_tankInfMid = "50"
                        },
                        units_class = "inf"
                     },
                     "1-st item is correct"
           )
           is_deeply(data[2],
                     {
                        ammo = "5",
                        icon_path = "units/rus/RusInf01",
                        id = "2",
                        initiative = "1",
                        name = "ПД",
                        nation = "rus",
                        size = "L",
                        spotting = "1",
                        staff = {
                           wt_infant = "324",
                           wt_tankInfMid = "50"
                        },
                        units_class = "inf"
                     },
                     "2-nd item is correct"
           )
        end
)


subtest("terrain-parse",
        function()
           local csv_data = [[
id;name;min_entr;max_entr;max_init;!image;k;v;/!;!spot_cost;k;v;/!;<move_cost;!leg;k;v;/!;!tracked;k;v;/!;!halftracked;k;v;/!;!allterrain;k;v;/!;!wheeled;k;v;/!;!towed;k;v;/!;!air;k;v;/!;!naval;k;v;/!;/>
c;Поле;0;5;99;;fair;terrain/clear.bmp;;;fair;1;;;;fair;1;;;fair;1;;;fair;1;;;fair;1;;;fair;2;;;fair;A;;;fair;1;;;fair;X;;
;;;;;;clouds;terrain/clear.bmp;;;clouds;1;;;;clouds;1;;;clouds;1;;;clouds;1;;;clouds;1;;;clouds;2;;;clouds;A;;;clouds;1;;;clouds;X;;
;;;;;;raining;terrain/clear.bmp;;;raining;2;;;;raining;1;;;raining;1;;;raining;1;;;raining;1;;;raining;2;;;raining;A;;;raining;1;;;raining;X;;
;;;;;;snowing;terrain/clear.bmp;;;snowing;2;;;;snowing;1;;;snowing;1;;;snowing;1;;;snowing;1;;;snowing;2;;;snowing;A;;;snowing;1;;;snowing;X;;
f;Лес;2;7;3;;fair;terrain/forest.bmp;;;fair;2;;;;fair;2;;;fair;2;;;fair;2;;;fair;3;;;fair;3;;;fair;A;;;fair;1;;;fair;X;;
;;;;;;clouds;terrain/forest.bmp;;;clouds;2;;;;clouds;2;;;clouds;2;;;clouds;2;;;clouds;3;;;clouds;3;;;clouds;A;;;clouds;1;;;clouds;X;;
;;;;;;raining;terrain/forest.bmp;;;raining;2;;;;raining;2;;;raining;2;;;raining;2;;;raining;3;;;raining;3;;;raining;A;;;raining;1;;;raining;X;;
                  ]]
           local c = Converter.create(create_iterator(csv_data))
           local data = c:convert()
           -- print(inspect(data))
           ok(data, "got converted data")
           is(#data, 2, "2 rows in data")
           is_deeply(data[1],
                     {
                        id = "c",
                        image = {
                           clouds = "terrain/clear.bmp",
                           fair = "terrain/clear.bmp",
                           raining = "terrain/clear.bmp",
                           snowing = "terrain/clear.bmp"
                        },
                        max_entr = "5",
                        max_init = "99",
                        min_entr = "0",
                        move_cost = {
                           air = {
                              clouds = "1",
                              fair = "1",
                              raining = "1",
                              snowing = "1"
                           },
                           allterrain = {
                              clouds = "1",
                              fair = "1",
                              raining = "1",
                              snowing = "1"
                           },
                           halftracked = {
                              clouds = "1",
                              fair = "1",
                              raining = "1",
                              snowing = "1"
                           },
                           leg = {
                              clouds = "1",
                              fair = "1",
                              raining = "1",
                              snowing = "1"
                           },
                           naval = {
                              clouds = "X",
                              fair = "X",
                              raining = "X",
                              snowing = "X"
                           },
                           towed = {
                              clouds = "A",
                              fair = "A",
                              raining = "A",
                              snowing = "A"
                           },
                           tracked = {
                              clouds = "1",
                              fair = "1",
                              raining = "1",
                              snowing = "1"
                           },
                           wheeled = {
                              clouds = "2",
                              fair = "2",
                              raining = "2",
                              snowing = "2"
                           }
                        },
                        name = "Поле",
                        spot_cost = {
                           clouds = "1",
                           fair = "1",
                           raining = "2",
                           snowing = "2"
                        }
                     },
                     "1-st item is correct"
           )
           is_deeply(data[2],
                     {
                        id = "f",
                        image = {
                           clouds = "terrain/forest.bmp",
                           fair = "terrain/forest.bmp",
                           raining = "terrain/forest.bmp"
                        },
                        max_entr = "7",
                        max_init = "3",
                        min_entr = "2",
                        move_cost = {
                           air = {
                              clouds = "1",
                              fair = "1",
                              raining = "1"
                           },
                           allterrain = {
                              clouds = "3",
                              fair = "3",
                              raining = "3"
                           },
                           halftracked = {
                              clouds = "2",
                              fair = "2",
                              raining = "2"
                           },
                           leg = {
                              clouds = "2",
                              fair = "2",
                              raining = "2"
                           },
                           naval = {
                              clouds = "X",
                              fair = "X",
                              raining = "X"
                           },
                           towed = {
                              clouds = "A",
                              fair = "A",
                              raining = "A"
                           },
                           tracked = {
                              clouds = "2",
                              fair = "2",
                              raining = "2"
                           },
                           wheeled = {
                              clouds = "3",
                              fair = "3",
                              raining = "3"
                           }
                        },
                        name = "Лес",
                        spot_cost = {
                           clouds = "2",
                           fair = "2",
                           raining = "2"
                        }
                     },
                     "2-nd item is correct"
           )
        end
)

subtest("armed-forces-parse",
        function()
           local csv_data = [[
id;name;!flags;k;v;/!
wc_antiair;Средства ПВО ;;;;
wc_tractor;Тягачи;;TRANSPORTS_TOWED;TRUE;
                  ]]
           local c = Converter.create(create_iterator(csv_data))
           local data = c:convert()
           -- print(inspect(data))
           ok(data, "got converted data")
           is(#data, 2, "2 rows in data")
           is_deeply(data, {
                     {
                        flags = { },
                        id = "wc_antiair",
                        name = "Средства ПВО "
                     }, {
                        flags = {
                           TRANSPORTS_TOWED = "TRUE"
                        },
                        id = "wc_tractor",
                        name = "Тягачи"
                     }
           })
        end
)

subtest("armys-parse", function()
   local csv_data = [[
id;name;unit_definition_id;x;y;entr;state;exp;managed_by;orientation;attach;^staff;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;/^
rus_11019;19-я пехотная дивизия;rus_1401;7;10;0;marching;5;;left;;;rus_6;1;rus_7;1;rus_8;3;rus_9;10;rus_10;7;rus_11;40;rus_15;42;rus_20;5;rus_19;26;rus_18;26;rus_25;324;rus_30;27;rus_43;108;rus_34;34;rus_36;12;rus_37;15;rus_38;1;rus_40;27;rus_45;6;rus_46;27;rus_622;81;rus_624;54;rus_631;18;rus_510;18;rus_558;6;rus_525;24;rus_553;24;rus_571;12;rus_656;18;;;rus_663;18;rus_679;18;rus_683;18;rus_685;18;rus_289;105;rus_276;96;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
          ]]
  local c = Converter.create(create_iterator(csv_data))
  local data = c:convert()
  -- print(inspect(data[1]))
  ok(data, "got converted data")
  is(#data, 1, "1 row in data")
  is_deeply(data, {
    {
      entr = "0",
      exp = "5",
      id = "rus_11019",
      name = "19-я пехотная дивизия",
      orientation = "left",
      staff = {
        rus_10 = "7",
        rus_11 = "40",
        rus_15 = "42",
        rus_18 = "26",
        rus_19 = "26",
        rus_20 = "5",
        rus_25 = "324",
        rus_276 = "96",
        rus_289 = "105",
        rus_30 = "27",
        rus_34 = "34",
        rus_36 = "12",
        rus_37 = "15",
        rus_38 = "1",
        rus_40 = "27",
        rus_43 = "108",
        rus_45 = "6",
        rus_46 = "27",
        rus_510 = "18",
        rus_525 = "24",
        rus_553 = "24",
        rus_558 = "6",
        rus_571 = "12",
        rus_6 = "1",
        rus_622 = "81",
        rus_624 = "54",
        rus_631 = "18",
        rus_656 = "18",
        rus_663 = "18",
        rus_679 = "18",
        rus_683 = "18",
        rus_685 = "18",
        rus_7 = "1",
        rus_8 = "3",
        rus_9 = "10"
      },
      state = "marching",
      unit_definition_id = "rus_1401",
      x = "7",
      y = "10"
    }
  })
end)

subtest("armys-parse-bug", function()
   local csv_data = [[
id;name;unit_definition_id;x;y;entr;state;exp;managed_by;orientation;attach;^staff;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;/^
rus_61002;1-я смешанная самолётная дивизия;rus_7428;9;9;0;flying;5;;left;;;rus_811;41;rus_802;41;rus_878;41;rus_872;41;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
]]
  local c = Converter.create(create_iterator(csv_data))
  local data = c:convert()
  print(inspect(data))
  ok(data, "got converted data")
  is(#data, 1, "1 row in data")
  is_deeply(data, {
    {
      entr = "0",
      exp = "5",
      id = "rus_61002",
      name = "1-я смешанная самолётная дивизия",
      orientation = "left",
      staff = {
        rus_802 = "41",
        rus_811 = "41",
        rus_872 = "41",
        rus_878 = "41"
      },
      state = "flying",
      unit_definition_id = "rus_7428",
      x = "9",
      y = "9"
    }
  })
end)


done_testing()
