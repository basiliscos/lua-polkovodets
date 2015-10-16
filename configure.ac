AC_INIT([polkovodets], [1.0], [bug-report@polkovodets.su])
AM_INIT_AUTOMAKE([foreign -Wall -Werror])
AC_PROG_CC

dnl LUA
AX_PROG_LUA(5.3)
AX_LUA_LIBS
AX_LUA_HEADERS

AC_CHECK_FUNC(putenv)

AC_ARG_VAR([LUA_SRCDIR], [directory with polkovodets lua sources])
AS_IF([test "x$LUA_SRCDIR" != "x"], [],
        AC_SUBST(LUA_SRCDIR, "src/lua")
)

AC_CHECK_FILE(["$LUA_SRCDIR/main.lua"],
	[],
	[AC_MSG_ERROR([main.lua not found in LUA_SRCDIR ($LUA_SRCDIR)])],
)
AC_DEFINE_UNQUOTED([LUA_SRCDIR], ["$LUA_SRCDIR"], [directory with polkovodets lua sources])

AC_CONFIG_HEADERS([config.h])
AC_CONFIG_FILES([Makefile src/Makefile src/c/Makefile src/lua/Makefile])
AC_OUTPUT
