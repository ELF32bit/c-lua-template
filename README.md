# C application with embeddable Lua scripts
This template is designed for high-performance applications.<br>
The build system will embed **Lua** scripts and register **C** modules.<br>
Manage application from **`main.lua`** and offload heavy computations.<br>

## Building the project
Run the command inside any **non-Windows** terminal.<br>
```Bash
lua compile.lua && ./application
```
Add **`-Ithirdparty`** flag to **`C_COMPILER_FLAGS`** in **`compile.lua`**<br>
Create **`thirdparty`** directory to include external libraries.<br>
