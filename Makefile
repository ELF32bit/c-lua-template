# =========================================================================== #
# Configuration                                                               #
# =========================================================================== #

CC = gcc
TARGET = application
EXE = $(if $(COMSPEC),.exe,)

CFLAGS = -std=c99
CFLAGS += -Wall -Wextra -Wno-unused-variable
CFLAGS += -O2 -DNDEBUG

# =========================================================================== #
# Dependencies                                                                #
# =========================================================================== #

SOURCES_DIRECTORY = sources
CFLAGS += -I. -I$(SOURCES_DIRECTORY)

THIRDPARTY_DIRECTORY = thirdparty
CFLAGS += -I$(THIRDPARTY_DIRECTORY)

LDFLAGS =
LDLIBS = -lm

LUA_LINK_STATIC ?= 0
ifeq ($(LUA_LINK_STATIC), 1)
	# download Lua source code here and compile
	LDLIBS += $(THIRDPARTY_DIRECTORY)/lua/liblua.a
else
	LDLIBS += -llua
endif

# =========================================================================== #
# Lua Embedding                                                               #
# =========================================================================== #

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

LUA_REQUIRED = compile.lua \
	$(LUA_MODULES) $(LUA_SCRIPTS)

LUA_GENERATED = \
	$(LUA_MODULES_HEADER) \
	$(LUA_MODULES_CODE) \
	$(LUA_SCRIPTS_HEADER) \
	$(LUA_SCRIPTS_CODE)

# =========================================================================== #
# Sources                                                                     #
# =========================================================================== #

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

C_SOURCES_ALL_WITHOUT_LUA = $(filter-out \
	$(THIRDPARTY_DIRECTORY)/lua/% \
	$(LUA_MODULES_CODE) \
	$(LUA_SCRIPTS_CODE), \
	$(C_SOURCES_ALL))

C_SOURCES = $(C_SOURCES_ALL_WITHOUT_LUA)
C_OBJECTS = $(C_SOURCES:.c=.o)

# =========================================================================== #
# Compiling                                                                   #
# =========================================================================== #

.PHONY: all clean

all: $(TARGET)$(EXE)

$(LUA_GENERATED): $(LUA_REQUIRED)
	@lua compile.lua \
		'$(LUA_MODULES_DIRECTORY)' \
		'$(LUA_MODULES_HEADER)' \
		'$(LUA_MODULES_CODE)' \
		'$(LUA_MODULES)' \
		'$(LUA_SCRIPTS_DIRECTORY)' \
		'$(LUA_SCRIPTS_HEADER)' \
		'$(LUA_SCRIPTS_CODE)' \
		'$(LUA_SCRIPTS)'

$(C_OBJECTS): | \
	$(LUA_MODULES_HEADER) \
	$(LUA_SCRIPTS_HEADER)

$(TARGET)$(EXE): $(C_OBJECTS) $(LUA_MODULES_CODE) $(LUA_SCRIPTS_CODE)
	@$(CC) $(CFLAGS) $(LDFLAGS) $(C_OBJECTS) \
		$(LUA_MODULES_CODE) $(LUA_SCRIPTS_CODE) \
		-o $@ $(LDLIBS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	@rm -f $(C_OBJECTS) $(TARGET)$(EXE) \
		$(LUA_GENERATED)
