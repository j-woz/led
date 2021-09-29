
CC = gcc

# CPPFLAGS = -I . -I /usr/include/tcl8.6
CFLAGS = -fPIC

# Dunedin
# APT:
# TCL_INCLUDE = -I /usr/include/tcl8.6
# TCL_LIB = # -L /usr/lib/x86_64-linux-gnu
# PIC = -fPIC

# # Felix:
# TCL = ${HOME}/sfw/tcl-8.6.6
# TCL_INCLUDE = -I $(TCL)/include
# TCL_LIB = -L $(TCL)/lib
# PIC = -fPIC


# Felix:
#TCL = ${HOME}/sfw/tcl-8.6.6
#TCL_INCLUDE = -I $(TCL)/include
#TCL_LIB = -L $(TCL)/lib
#PIC = -fPIC

# # MCS:
# TCL = ${HOME}/sfw/tcl-8.6.1
# TCL_INCLUDE = -I $(TCL)/include
# TCL_LIB = -L $(TCL)/lib
# PIC = -fPIC

# Helix (Cygwin):
TCL = /usr
TCL_INCLUDE = -I $(TCL)/include
TCL_LIB = -L $(TCL)/lib
RPATH = -Wl,-rpath -Wl,$(TCL)/lib
PIC = 

# # Theta
# TCL = ${HOME}/Public/sfw/theta/tcl-8.6.1
# $(warning THETA $(TCL))
# TCL_INCLUDE = -I $(TCL)/include
# TCL_LIB = -L $(TCL)/lib
# PIC = -fPIC

# # Summit
# TCL = ${HOME}/Public/sfw/summit/tcl-8.6.6
# TCL_INCLUDE = -I $(TCL)/include
# TCL_LIB = -L $(TCL)/lib
# RPATH = -Wl,-rpath -Wl,$(TCL)/lib
# PIC = -fPIC

# PIC = -fPIC
# PIC =

CC = gcc
CPPFLAGS = -I . $(TCL_INCLUDE)
CFLAGS = $(PIC)
LDFLAGS = -l readline $(TCL_LIB) -l tcl8.6

all: lib/libtcleditor.so

src/editor_wrap.c: src/editor.i src/editor.h Makefile
	swig $(<)
	sed -i s/Editor_Init/Tcleditor_Init/ $(@)

lib/libtcleditor.so: src/editor_wrap.o src/editor.o
	gcc -shared -o $(@) $(^) \
		$(LDFLAGS) \
		$(RPATH)

# gcc -shared -o $(@) $(^) -L $(TCL_LIB) -l tcl -l readline

tags: src/editor.h src/editor.c
	etags $(^) /usr/include/readline/readline.h \
		/usr/include/readline/rlstdc.h \
		/usr/include/readline/rltypedefs.h \
		/usr/include/readline/keymaps.h \
		/usr/include/readline/tilde.h \
		/usr/include/readline/history.h

clean:
	rm -fv lib/*.so src/*.o
