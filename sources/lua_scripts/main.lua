print("Hello World!")

local array = { 1, 2, 3, 4, 5, 6, 7, 8 }
print("Array:", table.concat(array, ","))

local example_module = require("example_C")
print("Example sum:", example_module.sum(array))
