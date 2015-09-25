/*

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

*/

#ifdef HAVE_CONFIG_H
#include "../../config.h"
#endif


#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <stdlib.h>
#include <stdio.h>
#include <sys/stat.h>
#include <string.h>

#define MAIN_LUA "main.lua"

int main(int argc, char** argv) {
    struct stat script_stat;
    char path[1024];
    char* script = NULL;
    FILE *script_file;
    int result;
    lua_State *L;
    char lua_path[2048];
    char* lua_path_env;
    char* lua_path_env_new;

    if (argc < 2) {
	fprintf(stderr, "usage: %s lua_dir", argv[0]);
	return -1;
    }

    snprintf(path, sizeof(path), "%s/%s", argv[1], MAIN_LUA);

    result = stat(path, &script_stat);
    if (result) {
	perror("error get main script stats");
	return -1;
    }

    script = calloc(script_stat.st_size+1, 1);
    if (!script) {
	fprintf(stderr, "cannot allocate %ld bytes for script\n", script_stat.st_size);
	return -1;
    }

    script_file = fopen(path, "r");
    if (!script_file) {
	perror("cannot open script file");
	return -1;
    }

    result = fread(script, script_stat.st_size, 1, script_file);
    if (result != 1) {
	fprintf(stderr, "error reading script %s\n", path);
	return -1;
    }

    /* add to searching the path to polkovodets lua dir */
    snprintf(lua_path, sizeof(lua_path), "%s/?.lua;%s/?/init.lua", argv[1], argv[1]);
    lua_path_env = getenv("LUA_PATH");

    /* +2: path_separator + zero at the end + LUA_PATH=*/
    lua_path_env_new = (char*) malloc(strlen(lua_path_env) + (lua_path ? strlen(lua_path) + 1 : 0) + 10);
    if (!lua_path_env_new) {
	fprintf(stderr, "allocating new LUA_PATH value failed\n");
	return -1;
    }
    if (lua_path_env) {
	sprintf(lua_path_env_new, "LUA_PATH=%s;%s", lua_path_env, lua_path);
    } else {
	sprintf(lua_path_env_new, "LUA_PATH=%s", lua_path);
    }
    putenv(lua_path_env_new);

    L = luaL_newstate();
    if (!L) {
	fprintf(stderr, "allocating LUA interpreter failed\n");
	return -1;
    }

    /* load standard libraries */
    luaL_openlibs(L);

    if (luaL_loadstring(L, script)) {
	fprintf(stderr, "compiling script %s error: %s\n", path, lua_tostring(L, -1));
	return -1;
    }


    if (lua_pcall(L, 0, 0, 0)) {
	fprintf(stderr, "main script execution error: %s\n", lua_tostring(L, -1));
	return -1;
    }


}
