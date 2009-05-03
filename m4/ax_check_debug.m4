dnl -*- Mode: autoconf -*-

dnl AX_CHECK_DEBUG
dnl + sets/modifies vars:
dnl   ENABLE_DEBUG
dnl   OFLAGS
dnl   CFLAGS, USER_CFLAGS
dnl + autoheader defines
dnl   ENABLE_DEBUG
dnl + AC_SUBST vars
dnl   OFLAGS
AC_DEFUN([AX_CHECK_DEBUG],
[
##vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
## debug ?
##
AC_MSG_CHECKING([whether to build debug version])
AC_ARG_ENABLE(debug,
	AC_HELP_STRING([--enable-debug], [build debug version (default=no)]))

if test "$enable_debug" == "yes" ; then
   AC_MSG_RESULT(yes)

   dnl-- this breaks default shared-library building
   dnl-- on debian/sid:
   dnl    + automake 1.9.6
   dnl    + autoconf 2.59
   dnl    + libtool  1.5.20
   dnl
   dnl AC_DISABLE_SHARED
   if test "$GCC" == "yes" ; then
     AC_MSG_NOTICE([GNU C compiler detected: setting appropriate debug flags])
     OFLAGS="-g"
   else
     AC_MSG_WARN([GNU C compiler not detected: you must use CFLAGS to set compiler debugging flags])
     OFLAGS=""
   fi

   AC_DEFINE(DEBUG_ENABLED,1, [Define this to enable debugging code])
   DOXY_DEFINES="$DOXY_DEFINES DEBUG_ENABLED=1"
   CONFIG_OPTIONS="DEBUG=1"
else
  AC_MSG_RESULT(no)
  if test "$GCC" == "yes"; then
   case "$USER_CFLAGS" in
    *-O*)
      AC_MSG_NOTICE([USER_CFLAGS appears already to contain optimization flags - skipping])
      OFLAGS=""
      ;;
    *)
     AC_MSG_NOTICE([GNU C compiler detected: setting default optimization flags])
     #OFLAGS="-pipe -O2"
     OFLAGS="-pipe -O" ##-- this is actually faster for our c progs!
     ;;
   esac
  else
    AC_MSG_WARN([GNU C compiler not detected: you must use CFLAGS to set compiler optimization flags])
    OFLAGS=""
  fi
  #CONFIG_OPTIONS="$CONFIG_OPTIONS DEBUG=0"
  CONFIG_OPTIONS="DEBUG=0"
fi

test -n "$OFLAGS" && USER_CFLAGS="$USER_CFLAGS $OFLAGS" && CFLAGS="$CLFAGS $OFLAGS"
AC_SUBST(OFLAGS)
##
## /debug ?
##^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
])
