C_COMPILER = "gcc"

C_COMPILER_FLAGS = {
	"-std=c99",
	"-Wall -Wextra",
}

C_LINKER_FLAGS = {
	"-llua -lm",
}

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

function parse_lua_module_c_function_name(line)
	local LFN1 = "^%s*static%s+int%s+([%a_][%w_]*)%s*%((.*)%)"
	local LFN2 = "^%s*int%s+([%a_][%w_]*)%s*%((.*)%)"
	local LFP1 = "^%s*const%s+lua_State%s*%*%s*([%a_][%w_]*)%s*$"
	local LFP2 = "^%s*lua_State%s*%*%s*([%a_][%w_]*)%s*$"
	local name, parameters = line:match(LFN1)
	if not name then
		name, parameters = line:match(LFN2)
	end
	if name and parameters then
		if parameters:match(LFP1) or parameters:match(LFP2) then
			return name
		end
	end
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

	local modules = os_find_files(directory, ".h")

	-- finding Lua functions in C modules
	local functions = {}
	for _, module_path in ipairs(modules) do
		local module_functions = {}
		table.insert(functions, module_functions)
		local module_file = assert(io.open(module_path, "r"))
		for line in module_file:lines() do
			local name = parse_lua_module_c_function_name(line)
			if name then
				table.insert(module_functions, name)
			end
		end
		module_file:close()
	end

	-- including C modules from the project directory
	table.insert(C_COMPILER_FLAGS, "-I.")
	for _, module_path in ipairs(modules) do
		file:write(string.format('#include "%s"\n', module_path))
	end
	file:write("\n")

	-- generating module names with _C suffix added
	local module_prefix = string.format("^%s/", directory)
	for index, module_path in ipairs(modules) do
		local module = module_path:gsub(".h$", "")
		module = module:gsub(module_prefix, "")
		modules[index] = module .. "_C"
	end

	-- generating function tables from C modules
	for index, module in ipairs(modules) do
		local m = module:gsub("/", "_")
		file:write(string.format("static const luaL_Reg %s[] = {\n", m))
		for _, name in ipairs(functions[index]) do
			local n = name:gsub("^l_", "")
			n = n:gsub(string.format("^%s_", m:gsub("_C$", "")), "")
			file:write(string.format('\t{ "%s", %s }, \n', n, name))
		end
		file:write('\t{ NULL, NULL }\n};\n\n')
	end

	-- generating registration functions for C modules
	for _, module in ipairs(modules) do
		local m = module:gsub("/", "_")
		file:write(string.format("static int luaopen_%s(lua_State* L) {\n", m))
		file:write(string.format("\tluaL_newlib(L, %s);\n", m))
		file:write("\treturn 1;\n}\n\n")
	end

	-- generating C modules registration table
	file:write("const LuaModule g_lua_modules[] = {\n")
	for _, module in ipairs(modules) do
		local m = string.format("luaopen_%s", module:gsub("/", "_"))
		file:write(string.format('\t{ "%s", %s }, \n', module, m))
	end
	file:write('\t{ NULL, NULL }\n};\n')

	file:close()
end

function string_to_formatted_bytes(data)
	local bytes = {}
	local data_size = data:len()
	for index = 1, data_size do
		if index % 12 == 1 then
			table.insert(bytes, (index == 1) and "\t" or "\n\t")
		end
		table.insert(bytes, string.format("0x%02x", data:byte(index)))
		table.insert(bytes, (index ~= data_size) and ", " or "\n")
	end
	return table.concat(bytes)
end

function lua_script_to_formatted_bytes(path)
	local file = assert(io.open(path, "rb"))
	local data = file:read("*a")
	if EMBED_LUA_SCRIPTS_AS_BYTECODE then
		local _load51 = loadstring or load
		data = string.dump(assert(_load51(data)))
	end
	file:close()
	return string_to_formatted_bytes(data)
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

	-- finding module names for Lua scripts
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
		file:write(lua_script_to_formatted_bytes(script_path))
		file:write("};\n\n")
	end

	-- generating registration table for Lua scripts
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
	local sources = os_find_files(directory, ".c")

	local arguments = { C_COMPILER }
	for _, argument in ipairs(C_COMPILER_FLAGS) do
		table.insert(arguments, argument)
	end
	for _, source_path in ipairs(sources) do
		table.insert(arguments, string.format('"%s"', source_path))
	end
	for _, argument in ipairs(C_LINKER_FLAGS) do
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
