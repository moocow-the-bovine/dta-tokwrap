dnl -*- Mode: autoconf -*-
AC_DEFUN([AX_CHECK_PERL],
[
##vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
## perl
AC_ARG_VAR(PERL, [Path to your perl interpreter, "no" to disable])
if test -z "$PERL" ; then
  AC_PATH_PROG(PERL,[perl],[no])
fi
if test -z "$PERL" -o "$PERL" = "no"; then
  AC_MSG_WARN([perl missing or disabled])
  AC_MSG_WARN([- generation of alternate documentation formats disabled.])
  PERL=no
fi
AC_SUBST(PERL)
## /perl
##^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
])
