AC_INIT([polkovodets], [1.0], [bug-report@polkovodets.su])
AM_INIT_AUTOMAKE([foreign -Wall -Werror])
AC_PROG_CC

dnl LUA
AX_PROG_LUA(5.3)
AX_LUA_LIBS
AX_LUA_HEADERS

AC_CHECK_FUNC(putenv)

dnl POLKOVODETS_LUA_PATH
AC_ARG_VAR([POLKOVODETS_LUA_PATH], [directory with polkovodets lua path])
AS_IF([test "x$POLKOVODETS_LUA_PATH" != "x"], [],
        AC_SUBST(POLKOVODETS_LUA_PATH, "src/lua")
)

AC_CHECK_FILE(["$POLKOVODETS_LUA_PATH/main.lua"],
	[],
	[AC_MSG_ERROR([main.lua not found in POLKOVODETS_LUA_PATH ($POLKOVODETS_LUA_PATH)])],
)
AC_DEFINE_UNQUOTED([POLKOVODETS_LUA_PATH], ["$POLKOVODETS_LUA_PATH"], [directory with polkovodets lua path])

dnl POLKOVODETS_LUA_CPATH
AC_ARG_VAR([POLKOVODETS_LUA_CPATH], [directory with polkovodets lua cpath])
AS_IF([test "x$POLKOVODETS_LUA_CPATH" != "x"],
	AC_DEFINE_UNQUOTED([POLKOVODETS_LUA_CPATH], ["$POLKOVODETS_LUA_CPATH"], [directory with polkovodets lua cpath])
)


AC_CONFIG_HEADERS([config.h])
AC_CONFIG_FILES([Makefile src/Makefile src/c/Makefile src/lua/Makefile])
AC_OUTPUT
