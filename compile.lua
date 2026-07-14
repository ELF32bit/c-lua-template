C_COMPILER = "gcc"
C_COMPILER_FLAGS = "-Wall -Wextra"
C_LINKER_FLAGS = "-llua -lm"
EMBED_LUA_SCRIPTS_AS_BYTECODE = true

function os_find_files(directory, extension)
	local find_command = 'find "%s" -type f -name "*%s"'
	find_command = string.format(find_command, directory, extension)
	local found_files = assert(io.popen(find_command, "r"))

	local sorted_files = {}
	for path in found_files:lines() do
		table.insert(sorted_files, path)
	end

	found_files:close()
	table.sort(sorted_files)
	return sorted_files
end

function write_lua_modules_header(path)
	local file = assert(io.open(path, "w"))
	file:write("#ifndef LUA_MODULES_H\n")
	file:write("#define LUA_MODULES_H\n\n")
	file:write("#include <stddef.h>\n\n")
	file:write("typedef struct LuaModule {\n")
	file:write("\tconst char* name;\n")
	file:write("\tvoid* open_function;\n")
	file:write("} LuaModule;\n\n")
	file:write("extern const LuaModule g_lua_modules[];\n\n")
	file:write("#endif\n")
	file:close()
end

function write_lua_modules(directory, path)
	local file = assert(io.open(path, "w"))
	file:write('#include "lua_modules.h"\n\n')
	file:write('#include <lua.h>\n')
	file:write('#include <lauxlib.h>\n\n')

	local functions = {}
	local modules = os_find_files(directory, ".c")
	local _L_ = "^%s*[_%w%*%s]+%s+([_%a][_%w]*)%s*%"
	_L_ = _L_ .. "(%s*lua_State%s*%*%s*[_%a][_%w]*%s*%)"
	C_COMPILER_FLAGS = C_COMPILER_FLAGS .. " -I."

	-- finding Lua functions in C modules
	for _, module_path in ipairs(modules) do
		local module_functions = {}
		table.insert(functions, module_functions)
		local module_file = assert(io.open(module_path, "r"))
		for line in module_file:lines() do
			local function_name = line:match(_L_)
			if function_name then
				table.insert(module_functions, function_name)
			end
		end
		module_file:close()
	end

	-- including C modules from the project directory
	for _, module_path in ipairs(modules) do
		file:write(string.format('#include "%s"\n', module_path))
	end
	file:write("\n")

	-- generating module names with _C suffix added
	local module_prefix = string.format("^%s/", directory)
	for index, module_path in ipairs(modules) do
		local module = module_path:gsub(".c$", "")
		module = module:gsub(module_prefix, "")
		modules[index] = module .. "_C"
	end

	-- generating function tables from C modules
	for index, module in ipairs(modules) do
		local m = module:gsub("/", "_")
		file:write(string.format("static const luaL_Reg %s[] = {\n", m))
		for _, function_name in ipairs(functions[index]) do
			local fn = function_name:gsub("^l_", "")
			fn = fn:gsub(string.format("^%s_", m:gsub("_C$", "")), "")
			file:write(string.format('\t{ "%s", %s }, \n', fn, function_name))
		end
		file:write('\t{ NULL, NULL }\n};\n\n')
	end

	-- generating registartion functions for C modules
	for _, module in ipairs(modules) do
		local m = module:gsub("/", "_")
		file:write(string.format("static int luaopen_%s(lua_State* L) {\n", m))
		file:write(string.format("\tluaL_newlib(L, %s);\n", m))
		file:write("\treturn 1;\n};\n\n")
	end

	-- generating C modules registartion table
	file:write("const LuaModule g_lua_modules[] = {\n")
	for _, module in ipairs(modules) do
		local m = string.format("luaopen_%s", module:gsub("/", "_"))
		file:write(string.format('\t{ "%s", %s }, \n', module, m))
	end
	file:write('\t{ NULL, NULL }\n};\n')

	file:close()
end

function lua_script_to_bytes_string(path)
	local file = assert(io.open(path, "rb"))
	local data = file:read("*a")
	if EMBED_LUA_SCRIPTS_AS_BYTECODE then
		local _load51 = loadstring or load
		data = string.dump(assert(_load51(data)))
	end
	local data_size = data:len()
	file:close()

	local bytes = {}
	for index = 1, data_size do
		if index == 1 then
			table.insert(bytes, "\t")
		elseif index % 12 == 1 then
			table.insert(bytes, "\n\t")
		end
		table.insert(bytes, string.format("0x%02x", data:byte(index)))
		if index ~= data_size then
			table.insert(bytes, ", ")
		else
			table.insert(bytes, "\n")
		end
	end

	return table.concat(bytes)
end

function write_lua_scripts_header(path)
	local file = assert(io.open(path, "w"))
	file:write("#ifndef LUA_SCRIPTS_H\n")
	file:write("#define LUA_SCRIPTS_H\n\n")
	file:write("#include <stddef.h>\n\n")
	file:write("typedef struct LuaScript {\n")
	file:write("\tconst char* name;\n")
	file:write("\tconst char* data;\n")
	file:write("\tsize_t data_size;\n")
	file:write("} LuaScript;\n\n")
	file:write("extern const LuaScript g_lua_scripts[];\n\n")
	file:write("#endif\n")
	file:close()
end

function write_lua_scripts(directory, path)
	local file = assert(io.open(path, "w"))
	file:write('#include "lua_scripts.h"\n\n')

	local scripts = os_find_files(directory, ".lua")
	local scripts_prefix = string.format("^%s/", directory)
	for index, script_path in ipairs(scripts) do
		local module = script_path:gsub(".lua$", "")
		module = module:gsub(scripts_prefix, "")
		scripts[index] = { script_path, module }
	end

	-- generating Lua scripts data
	for _, value in ipairs(scripts) do
		local script_path, module = value[1], value[2]
		local s = string.format("script_%s", module:gsub("/", "_"))
		file:write(string.format("static const char %s[] = {\n", s))
		file:write(lua_script_to_bytes_string(script_path))
		file:write("};\n\n")
	end

	-- generating registartion table for Lua scripts
	file:write("const LuaScript g_lua_scripts[] = {\n")
	for _, value in ipairs(scripts) do
		local module, m = value[2], value[2]:gsub("/", ".")
		local s = string.format("script_%s", module:gsub("/", "_"))
		file:write(string.format('\t{ "%s", %s, sizeof(%s) }, \n', m, s, s))
	end
	file:write('\t{ NULL, NULL, 0 }\n};\n')

	file:close()
end

function compile_c(directory, path)
	local arguments = { C_COMPILER }
	for argument in C_COMPILER_FLAGS:gmatch("%S+") do
		table.insert(arguments, argument)
	end

	local sources = os_find_files(directory, ".c")
	for _, source_path in ipairs(sources) do
		table.insert(arguments, string.format('"%s"', source_path))
	end

	for argument in C_LINKER_FLAGS:gmatch("%S+") do
		table.insert(arguments, argument)
	end

	table.insert(arguments, "-o")
	table.insert(arguments, string.format('"%s"', path))

	local command = table.concat(arguments, " ")
	local result = assert(io.popen(command, "r"))
	io.write(result:read("*a"))
end

-- generating Lua modules from C sources
write_lua_modules_header("sources/lua_modules.h")
write_lua_modules("sources/lua_modules", "sources/lua_modules.c")

-- embedding Lua scripts into C sources
write_lua_scripts_header("sources/lua_scripts.h")
write_lua_scripts("sources/lua_scripts", "sources/lua_scripts.c")

-- compiling C sources
compile_c("sources", "application")
