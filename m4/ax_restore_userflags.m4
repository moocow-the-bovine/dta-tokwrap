dnl -*- Mode: autoconf -*-

AC_DEFUN([AX_SAVE_USERFLAGS],
[
##-- resture
AC_MSG_NOTICE([restoring user *FLAGS variables])
#test -n "$USER_LIBS" && LIBS="$USER_LIBS"
#test -n "$USER_LDFLAGS" && LDFLAGS="$USER_LDFLAGS"
#test -n "$USER_CPPFLAGS" && CPPFLAGS="$USER_CPPFLAGS"
test -n "$USER_CFLAGS" && CFLAGS="$USER_CFLAGS";
test -n "$USER_CXXFLAGS" && CXXFLAGS="$USER_CXXFLAGS";
])
