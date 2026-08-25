TARGET = application
SOURCES_DIRECTORY = sources
THIRDPARTY_DIRECTORY = thirdparty
EXE = $(if $(COMSPEC),.exe,)

CC = gcc
CFLAGS = -std=c99 -I. \
	-I$(SOURCES_DIRECTORY) \
	-I$(THIRDPARTY_DIRECTORY) \
	-Wall -Wextra -Wno-unused-variable
CFLAGS += -O2 -DNDEBUG

LDFLAGS =
LDLIBS = -lm

LUA_LINK_STATIC ?= 0
ifeq ($(LUA_LINK_STATIC), 1)
	# download Lua source code here and compile
	LDLIBS += $(THIRDPARTY_DIRECTORY)/lua/liblua.a
else
	LDLIBS += -llua
endif

LUA_MODULES_DIRECTORY = $(SOURCES_DIRECTORY)/lua_modules
LUA_MODULES_HEADER = $(SOURCES_DIRECTORY)/lua_modules.h
LUA_MODULES_CODE = $(SOURCES_DIRECTORY)/lua_modules.c

LUA_SCRIPTS_DIRECTORY = $(SOURCES_DIRECTORY)/lua_scripts
LUA_SCRIPTS_HEADER = $(SOURCES_DIRECTORY)/lua_scripts.h
LUA_SCRIPTS_CODE = $(SOURCES_DIRECTORY)/lua_scripts.c

LUA_MODULES = $(wildcard \
	$(LUA_MODULES_DIRECTORY)/*.h \
	$(LUA_MODULES_DIRECTORY)/*/*.h \
	$(LUA_MODULES_DIRECTORY)/*/*/*.h \
	$(LUA_MODULES_DIRECTORY)/*/*/*/*.h)

LUA_SCRIPTS = $(wildcard \
	$(LUA_SCRIPTS_DIRECTORY)/*.lua \
	$(LUA_SCRIPTS_DIRECTORY)/*/*.lua \
	$(LUA_SCRIPTS_DIRECTORY)/*/*/*.lua \
	$(LUA_SCRIPTS_DIRECTORY)/*/*/*/*.lua)

C_SOURCES_ALL = $(wildcard \
	$(SOURCES_DIRECTORY)/*.c \
	$(SOURCES_DIRECTORY)/*/*.c \
	$(SOURCES_DIRECTORY)/*/*/*.c \
	$(SOURCES_DIRECTORY)/*/*/*/*.c)

C_SOURCES_ALL += $(wildcard \
	$(THIRDPARTY_DIRECTORY)/*.c \
	$(THIRDPARTY_DIRECTORY)/*/*.c \
	$(THIRDPARTY_DIRECTORY)/*/*/*.c \
	$(THIRDPARTY_DIRECTORY)/*/*/*/*.c)

C_SOURCES = $(filter-out \
	$(LUA_MODULES_CODE) \
	$(LUA_SCRIPTS_CODE), \
	$(C_SOURCES_ALL))

C_OBJECTS = $(C_SOURCES:.c=.o)

.PHONY: all lua_compile clean

all: lua_compile $(TARGET)$(EXE)

lua_compile:
	@lua compile.lua \
		'$(LUA_MODULES_DIRECTORY)' \
		'$(LUA_MODULES_HEADER)' \
		'$(LUA_MODULES_CODE)' \
		'$(LUA_MODULES)' \
		'$(LUA_SCRIPTS_DIRECTORY)' \
		'$(LUA_SCRIPTS_HEADER)' \
		'$(LUA_SCRIPTS_CODE)' \
		'$(LUA_SCRIPTS)'

$(TARGET)$(EXE): $(C_OBJECTS) $(LUA_MODULES_CODE) $(LUA_SCRIPTS_CODE)
	@$(CC) $(CFLAGS) $(LDFLAGS) $(C_OBJECTS) \
		$(LUA_MODULES_CODE) $(LUA_SCRIPTS_CODE) \
		-o $@ $(LDLIBS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	@rm -f $(C_OBJECTS) $(TARGET)$(EXE) \
		$(LUA_MODULES_HEADER) \
		$(LUA_MODULES_CODE) \
		$(LUA_SCRIPTS_HEADER) \
		$(LUA_SCRIPTS_CODE)
