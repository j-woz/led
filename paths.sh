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

# gcc -shared -o $(@) $(^) -L $(TCL_LIB) -l tcl -l readline
