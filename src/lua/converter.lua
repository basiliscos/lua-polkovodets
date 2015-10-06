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

local json = require ("dkjson")
local Converter = require 'polkovodets.Converter'

local in_filename = assert(arg[1], "1st argumnet - intput csv file")
local out_filename = assert(arg[2], "2nd argumnet - output json file")

local in_file = io.open(in_filename , "r")

local iterator = function() return in_file:read('*l') end
local converter = Converter.create(iterator)
local items = converter:convert()

local out_file = io.open(out_filename , "wb")
local serialized_data = json.encode(items, {indent = true})
out_file:write(serialized_data)
out_file:write("\n")
