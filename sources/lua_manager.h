#ifndef LUA_MANAGER_H
#define LUA_MANAGER_H

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

void luaM_register_arguments(lua_State* L, int argc, char* argv[]);
void luaM_register_scripts(lua_State* L);
int luaM_close(lua_State* L, int status);

#endif