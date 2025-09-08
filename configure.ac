#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.71])
AC_INIT([led], [0.1], [justin@wozniaks.org])
AC_CONFIG_SRCDIR([src/editor.h])
AC_CONFIG_HEADERS([config.h])

# Checks for programs.
AC_PROG_CC
AC_PATH_PROG([SWIG], [swig], 0)
if [[ $SWIG == 0 ]]
then
  AC_MSG_ERROR([You must have SWIG!])
fi
AC_ARG_VAR([SWIG], [The SWIG program to use])

if test "x$LIBS" = x
then
  LIBS="-lreadline"
fi
AC_SUBST(LIBS)

DPKG_ARCH=
# Debian distros may put in architecture-specific subdirectory
if which dpkg-architecture > /dev/null 2>&1
then
  DPKG_ARCH=$(dpkg-architecture -qDEB_HOST_MULTIARCH)
  AC_MSG_RESULT([dpkg-architecture: ${DPKG_ARCH}])
fi

# Tcl version is initially unknown (needed by find-tcl.sh)
export TCL_VERSION=0

# In order from most to least preferred
# We currently require 8.6 - could try "8.7 8.6"
TCL_VERSION_PREFS="8.6"

# Default sed in-place:
SED_I="sed -i"
PLATFORM="Linux"

UNAME=$(uname)
# This syntax requires Bash:
if [[ ${UNAME:0:6} == "CYGWIN" ]]
then
  # Cygwin/Windows
  AC_MSG_RESULT([Detected Cygwin.])
  SO_SUFFIX="dll.a"
elif [[ ${UNAME:0:6} == "Darwin" ]]
then
  AC_MSG_RESULT([Detected Mac/Darwin.])
  SO_SUFFIX="dylib"
  SED_I="sed -i ''"
  PLATFORM="Mac"
else
  AC_MSG_RESULT([Default to Linux.])
  SO_SUFFIX="so"
fi

AC_SUBST(SED_I)
AC_SUBST(PLATFORM)
AC_SUBST(SO_SUFFIX)

AC_ARG_WITH(tcl-version,
    AS_HELP_STRING([--with-tcl-version],
                   [Tcl version. Minimum is 8.6. If not specified,
                    use highest version we can find]),
    [
        TCL_VERSION=${withval}
        AC_MSG_NOTICE([user specified Tcl version ${TCL_VERSION}])
        LIBTCL=libtcl${TCL_VERSION}.${SO_SUFFIX}
    ],
    [
        AC_MSG_NOTICE([Tcl version is not specified.])
    ]
)

USE_TCL=0
# Set USE_TCL
AC_ARG_WITH(tcl,
    AS_HELP_STRING([--with-tcl], [location of Tcl]),
    [
        AC_MSG_RESULT([using Tcl: ${withval}])
        USE_TCL=${withval}
        AC_CHECK_FILE(${withval},[],
          AC_MSG_ERROR([Given Tcl directory does not exist: $withval]))
    ],
    [
      AC_MSG_NOTICE([Tcl location not specified, trying to find tclsh on path])
      for TCLVER in ${TCL_VERSION_PREFS}
      do
        AC_MSG_CHECKING([for tclsh${TCLVER} on path])
        program=$( which tclsh${TCLVER} 2>&1 )
        if [[ ${?} == 0 ]]
        then
          AC_MSG_RESULT([yes: ${program}])
          USE_TCL=$( cd $(dirname ${program})/.. ; /bin/pwd )
          AC_MSG_RESULT([Found Tcl at ${USE_TCL}]);
          break
        else
          AC_MSG_RESULT([no])
        fi
      done

      if [[ ${USE_TCL} == 0 ]]
      then
        AC_MSG_CHECKING([for tclsh on path])
        program=$( which tclsh 2>&1 )
        if [[ ${?} == 0 ]]
        then
          AC_MSG_RESULT([yes: ${program}])
          USE_TCL=$( cd $(dirname ${program})/.. ; /bin/pwd )
          AC_MSG_RESULT([Found Tcl at ${USE_TCL}]);
          break
        else
          AC_MSG_RESULT([no])
        fi
      fi

      if [[ ${USE_TCL} == 0 ]]
      then
        AC_MSG_ERROR([Could not find tclsh for any version: ${TCL_VERSION_PREFS}])
      fi
    ]
)

USE_TCL_LIB_DIR=0

AC_ARG_WITH(tcl-lib-dir,
    AS_HELP_STRING([--with-tcl-lib-dir],
                   [directory containing Tcl shared library]),
    [
        USE_TCL_LIB_DIR=${withval}
        AC_MSG_RESULT([using Tcl lib dir: ${USE_TCL_LIB_DIR}])
    ])

if [[ ${TCL_VERSION} != 0 ]]
then
  # We have locked in a version choice
  TCL_VERSION_PREFS=${TCL_VERSION}
fi

# Check in order from most to least preferred
for TCLVER in ${TCL_VERSION_PREFS}
do
  if [[ ${USE_TCL_LIB_DIR} == 0 ]]
  then
    LIB_DIR_OPTS="${USE_TCL}/lib ${USE_TCL}/lib64"

    # Debian distros may put in architecture-specific subdirectory
    if [[ "${DPKG_ARCH}" != "" ]]
    then
      LIB_DIR_ARCH_OPTS=""
      for opt in $LIB_DIR_OPTS
      do
        LIB_DIR_ARCH_OPTS+=" $opt/${DPKG_ARCH}"
      done
      LIB_DIR_OPTS="$LIB_DIR_OPTS $LIB_DIR_ARCH_OPTS"
    fi
  else
    LIB_DIR_OPTS="${USE_TCL_LIB_DIR}"
  fi

  for LIB_DIR in ${LIB_DIR_OPTS}
  do
    if ! [[ -d ${LIB_DIR} ]]
    then
      continue
    fi
    LIB_DIR=$( cd ${LIB_DIR} ; /bin/pwd ) # Canonicalize
    LIBTCL_PREFIX=libtcl${TCLVER}
    LIBTCL=${LIBTCL_PREFIX}.${SO_SUFFIX}
    AC_MSG_CHECKING([for Tcl ${TCLVER} library at ${LIB_DIR}/${LIBTCL}])
    if [[ -r ${LIB_DIR}/${LIBTCL} ]]
    then
      AC_MSG_RESULT([yes])
      TCL_VERSION=${TCLVER}
      USE_TCL_LIB_DIR=${LIB_DIR}
      USE_LIBTCL_SO=${LIB_DIR}/${LIBTCL}
      break 2
    else
      AC_MSG_RESULT([no])
    fi
  done
  echo OK
done

if [[ "${USE_LIBTCL_SO}" == "" ]]
then
    AC_MSG_ERROR([could not find libtcl!])
fi

AC_MSG_RESULT([using Tcl version: ${TCL_VERSION}])
AC_MSG_RESULT([Tcl shared library: ${USE_LIBTCL_SO}])
AC_SUBST(TCL_VERSION)

# Set USE_TCL_CFG_DIR: location of tclConfig.sh
USE_TCL_CFG_DIR=0

# This is a location used e.g. by the APT tcl8.6-dev package.
# Put first to maximize chance of getting Tcl version correct
TCL_CFG_DIR_ALTS="${USE_TCL_LIB_DIR}/tcl${TCL_VERSION}"
# This location is for Tcl installation from source
TCL_CFG_DIR_ALTS+=" ${USE_TCL_LIB_DIR}"

for TCL_CFG_DIR_ALT in $TCL_CFG_DIR_ALTS
do
  AC_MSG_CHECKING([for tclConfig.sh at ${TCL_CFG_DIR_ALT}])
  if [[ -r "$TCL_CFG_DIR_ALT/tclConfig.sh" ]]
  then
    USE_TCL_CFG_DIR="${TCL_CFG_DIR_ALT}"
    AC_MSG_RESULT([found])
    break
  else
    AC_MSG_RESULT([no])
  fi
done

if [[ ${USE_TCL_CFG_DIR} == 0 ]]
then
    AC_MSG_ERROR([Could not find tclConfig.sh!])
fi
AC_MSG_RESULT([using tclConfig.sh in: ${USE_TCL_CFG_DIR}])

# Make copy of old version since it can be clobbered by tclConfig.sh
TCL_OLD_VERSION="$TCL_VERSION"

# Source tclConfig.sh to obtain Tcl settings
source ${USE_TCL_CFG_DIR}/tclConfig.sh
if [[ ${?} != 0 ]]
then
    AC_MSG_ERROR([could not source: ${USR_TCL_CFG_DIR}/tclConfig.sh])
fi
if [[ "$TCL_VERSION" != "$TCL_OLD_VERSION" ]]
then
  AC_MSG_ERROR([${USE_TCL_CFG_DIR}/tclConfig.sh is not for appropriate \
      Tcl version.  Expected ${TCL_OLD_VERSION} but got ${TCL_VERSION}])
fi

: ${USE_TCLSH_LOCAL:=0}
# Find tclsh binary name
if [[ ${USE_TCLSH_LOCAL} == 0 ]]
then
    AC_MSG_RESULT([checking for Tcl executable in ${USE_TCL} ...])
    USE_TCLSH=$( maint/find-tcl.sh ${USE_TCL} )
    if [[ ${?} != 0 ]]
    then
        AC_MSG_ERROR([Could not find Tcl ${TCL_VERSION} executable in ${USE_TCL}!])
    fi
    USE_TCLSH_LOCAL=${USE_TCLSH}
else
    export NO_RUN=1
    USE_TCLSH=$( maint/find-tcl.sh ${USE_TCL} )
    if [[ ${?} != 0 ]]
    then
        AC_MSG_ERROR([Could not find Tcl ${TCL_VERSION} executable at ${USE_TCL}!])
    fi
fi
AC_MSG_RESULT([using Turbine Tcl executable: ${USE_TCLSH}])

# Now, allow user to override Tcl include
AC_ARG_WITH(tcl-include,
            AS_HELP_STRING(
               [--with-tcl-include],
               [directory containing tcl.h]),
            [AC_CHECK_FILE(${withval}/tcl.h,[SUCCESS=1],[SUCCESS=0])
              if ((  ${SUCCESS} == 0 ))
              then
               AC_MSG_ERROR(Could not find tcl.h in ${withval})
              fi
             AC_MSG_RESULT([using Tcl include: ${withval}/tcl.h])
             TCL_INCLUDE_SPEC=-I${withval}
            ],
            [])

AC_SUBST(USE_TCL)
AC_SUBST(USE_TCL_LIB_DIR)
AC_SUBST(USE_LIBTCL_SO)
AC_SUBST(USE_TCLSH)
AC_SUBST(TCL_INCLUDE_SPEC)
AC_SUBST(TCL_LIB_SPEC)
# Tcl library dependencies for static build
TCL_LIB_SPEC_EXTRA="${TCL_LIBS}"
AC_SUBST(TCL_LIB_SPEC_EXTRA)

# Checks for libraries.
AX_LIB_READLINE()
if [[ ${ax_cv_lib_readline} == "no" ]] || \
   [[ ${ax_cv_lib_readline_history}  == "no" ]]
then
    AC_MSG_ERROR([You must have the readline and history development packages!])
fi

# Checks for header files.
AC_CHECK_HEADERS([unistd.h])

# Checks for typedefs, structures, and compiler characteristics.

# Checks for library functions.

AC_CONFIG_FILES([Makefile bin/led])
AC_OUTPUT

# Cygwin seems to leave this as non-executable:
chmod u+x bin/led
