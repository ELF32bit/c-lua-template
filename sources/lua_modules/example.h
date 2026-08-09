#ifndef LUA_MODULE_EXAMPLE_H
#define LUA_MODULE_EXAMPLE_H

#include <lua.h>
#include <lauxlib.h>

/* access module metatable with .instance */
#define METATABLE "example_C.instance"

/* prefix Lua functions with l_ and module name */
int l_example_sum(lua_State* L);

/* create object instances with module metatable */
static inline int l_example_new_object(lua_State* L) {
	void* object = lua_newuserdata(L, sizeof(int));
	//object_init(&object);
	luaL_getmetatable(L, METATABLE);
	lua_setmetatable(L, -2);
	return 1;
}

/* add _meta suffix to metamethods of the module */
static inline int l_example___gcc_meta(lua_State* L) {
	void* object = luaL_checkudata(L, 1, METATABLE);
	//object_destroy(&object);
	return 0;
}

/* enable object instances to use module metatable */
static inline int l_example___index_meta(lua_State* L) {
	luaL_checkudata(L, 1, METATABLE);
	luaL_getmetatable(L, METATABLE);
	lua_pushvalue(L, 2);
	lua_gettable(L, -2);
	return 1;
}

/* implement custom methods for objects */
int l_example_to_string_meta(lua_State* L);

#endif
