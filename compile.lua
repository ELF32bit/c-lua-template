C_COMPILER = "gcc"
C_COMPILER_FLAGS = "-Wall -Wextra"
C_LINKER_FLAGS = "-llua -lm"

EMBED_LUA_SCRIPTS_AS_BYTECODE = true
OS_WINDOWS = (package.config:sub(1, 1) == "\\")

function os_normalize_path(path, is_native)
	if OS_WINDOWS and is_native then
		path = path:gsub("\r", "")
		path = path:gsub("\\", "/")
	elseif OS_WINDOWS and not is_native then
		path = path:gsub("/", "\\")
	end
	return path
end

function os_find_files(directory, extension)
	local find_command = 'find "%s" -type f -name "*%s"'
	if OS_WINDOWS then
		find_command = 'dir /b /s "%s\\*%s"'
	end

	find_command = string.format(find_command,
		os_normalize_path(directory, false), extension)
	local found_files = assert(io.popen(find_command, "r"))

	local sorted_files = {}
	for path in found_files:lines() do
		path = os_normalize_path(path, true)
		table.insert(sorted_files, path)
	end

	found_files:close()
	table.sort(sorted_files)
	return sorted_files
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

function write_lua_header(path)
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

function write_lua_sources(directory, path)
	local file = assert(io.open(path, "w"))
	file:write('#include "lua_scripts.h"\n\n')

	local scripts = os_find_files(directory, ".lua")
	local scripts_prefix = string.format("^%s/", directory)
	for index, script_path in ipairs(scripts) do
		local module = script_path:gsub(".lua$", "")
		module = module:gsub(scripts_prefix, "")
		scripts[index] = { script_path, module }
	end

	for _, value in ipairs(scripts) do
		local script_path, module = value[1], value[2]
		local s = string.format("script_%s", module:gsub("/", "_"))
		file:write(string.format("static const char %s[] = {\n", s))
		file:write(lua_script_to_bytes_string(script_path))
		file:write("};\n\n")
	end

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
		table.insert(arguments, os_normalize_path(source_path))
	end

	for argument in C_LINKER_FLAGS:gmatch("%S+") do
		table.insert(arguments, argument)
	end

	table.insert(arguments, "-o")
	table.insert(arguments, os_normalize_path(path))

	local command = table.concat(arguments, " ")
	local result = assert(io.popen(command, "r"))
	io.write(result:read("*a"))
end

-- embedding Lua scripts into C sources
write_lua_header("sources/lua_scripts.h")
write_lua_sources("sources/lua_scripts", "sources/lua_scripts.c")

-- compiling C sources
compile_c("sources", "application")
