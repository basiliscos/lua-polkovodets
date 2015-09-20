AC_INIT([polkovodets], [1.0], [bug-report@polkovodets.su])
AM_INIT_AUTOMAKE([foreign -Wall -Werror])
AC_PROG_CC
PKG_CHECK_MODULES(LUA, lua >= 5.1, [ ],[
		       PKG_CHECK_MODULES(LUA51, lua-5.1 >= 5.1, [ ],[
		       				PKG_CHECK_MODULES(LUA51, lua5.1 >= 5.1)
		       ])
		 ])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_FILES([Makefile src/Makefile src/c/Makefile])
AC_OUTPUT
