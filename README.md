# C application with embeddable Lua scripts
This template is designed for high-performance applications.<br>
The build system will embed **Lua** scripts and register **C** modules.<br>
Manage application from **`main.lua`** and offload heavy computations.<br>

## Building the project
Run the command inside a terminal.<br>
```Bash
make && ./application
```
Add **`-Ithirdparty`** flag to **`CFLAGS`** inside **`Makefile`**.<br>
Create **`thirdparty`** directory to include external libraries.<br>
```Go
./application	Hello World!
Array:	1,2,3,4,5,6,7,8
Sum example:	36
New object:	594855944
```
