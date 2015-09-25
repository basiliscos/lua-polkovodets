AC_INIT([polkovodets], [1.0], [bug-report@polkovodets.su])
AM_INIT_AUTOMAKE([foreign -Wall -Werror])
AC_PROG_CC

dnl LUA
AX_PROG_LUA(5.3)
AX_LUA_LIBS
AX_LUA_HEADERS

AC_CHECK_FUNC(putenv)

AC_CONFIG_HEADERS([config.h])
AC_CONFIG_FILES([Makefile src/Makefile src/c/Makefile src/lua/Makefile])
AC_OUTPUT
