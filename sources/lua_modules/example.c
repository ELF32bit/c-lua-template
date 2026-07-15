#include "example.h"

/* prefix Lua functions with l_ and module name */
int l_example_sum(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);

	lua_Integer sum = 0;
	size_t len = lua_rawlen(L, 1);
	for (size_t i = 1; i <= len; i++) {
		lua_rawgeti(L, 1, (lua_Integer)i);
		sum += luaL_checkinteger(L, -1);
		lua_pop(L, 1);
	}

	lua_pushinteger(L, sum);
	return 1;
}
