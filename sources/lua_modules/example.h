#ifndef LUA_MODULE_EXAMPLE_H
#define LUA_MODULE_EXAMPLE_H

#include <lua.h>
#include <lauxlib.h>

/* prefix Lua functions with l_ and module name */
int l_example_sum(lua_State *L);

#endif
