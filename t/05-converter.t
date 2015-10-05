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
                        icon_id = "weapon\\rus\\armory\\RusTank01.png;",
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
                        icon_id = "weapon\\rus\\infantry\\RusInf01.png;",
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
                        icon_path = "units\\rus\\RusInf01",
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
                        icon_path = "units\\rus\\RusInf01",
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

done_testing()
