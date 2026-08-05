#ifndef LUA_MODULE_EXAMPLE_H
#define LUA_MODULE_EXAMPLE_H

#include <lua.h>
#include <lauxlib.h>

/* prefix Lua functions with l_ and module name */
int l_example_sum(lua_State *L);

/* add _meta suffix to metamethods of the module */
int l_example___tostring_meta(lua_State *L);

/* access module metatable with .instance */
static inline int l_example_new_object(lua_State *L) {
	void* object = lua_newuserdata(L, sizeof(int));
	luaL_getmetatable(L, "example_C.instance");
	lua_setmetatable(L, -2);
	return 1;
}

#endif
