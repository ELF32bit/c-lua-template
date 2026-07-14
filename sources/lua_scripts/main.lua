print("Hello World!")

local array = { 1, 2, 3, 4, 5, 6, 7, 8 }
print("Array:", table.concat(array, ","))

-- load Lua modules with _C suffix
local example_module = require("example_C")
print("Sum example:", example_module.sum(array))
