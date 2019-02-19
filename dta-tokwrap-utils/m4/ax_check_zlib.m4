dnl -*- Mode: autoconf -*-

AC_DEFUN([AX_CHECK_ZLIB],
[
##vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
## zlib
##
AC_ARG_ENABLE(zlib,
	AC_HELP_STRING([--disable-zlib],
	               [Disable zlib compression support]),
	[ac_cv_enable_zlib="$enableval"],
	[ac_cv_enable_zlib="yes"])

if test "$ac_cv_enable_zlib" != "no" ; then
 for h in zlib.h ; do
  AC_CHECK_HEADER($h,
		  [_have_header="yes"], [_have_header="no"], [ ])
  if test "$_have_header" = "no" ; then
    AC_MSG_WARN([zlib header '$h' not found!])
    AC_MSG_WARN([- Is the directory containing the zlib headers in your])
    AC_MSG_WARN([  'CPPFLAGS' environment variable?])
    AC_MSG_NOTICE([zlib support disabled])
    ac_cv_enable_zlib="no"
  fi
 done
fi

if test "$ac_cv_enable_zlib" != "no" ; then
 ##-- zlib: library: compile
 AC_CHECK_LIB(z,deflate,[ac_cv_have_libz="yes"])
 if test "$ac_cv_have_libz" != "yes" ; then
    AC_MSG_WARN([could not link to zlib library!])
    AC_MSG_WARN([- Is the directory containing the zlib binary in your])
    AC_MSG_WARN([  'LDFLAGS' environment variable?])
    AC_MSG_NOTICE([zlib support disabled])
    ac_cv_enable_zlib="no"
 else
   gfsm_LIBS="$gfsm_LIBS -lz"
 fi
fi

##-- zlib: config.h flag
if test "$ac_cv_enable_zlib" != "no" ; then
 AC_DEFINE(ZLIB_ENABLED,1,
	   [Define this to enable zlib compression support])
 DOXY_DEFINES="$DOXY_DEFINES ZLIB_ENABLED=1"
fi
##
## /zlib
##^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
])
