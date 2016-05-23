#!/bin/sh

# dummy sdl module
echo "" > ./SDL.lua

eval `luarocks path`
export LUA_PATH="./src/lua/?.lua;./src/luar/?/init.lua;$LUA_PATH;"
prove -v t
