dnl -*- Mode: autoconf -*-

AC_DEFUN([AX_ARG_DISTCHECK],
[
 AC_PREREQ(2.5)

 ##----------------------------------------------------------------------
 ## DISTCHECK: simulate missing development-only packages
 AC_ARG_VAR(DISTCHECK,
	[(Maintainer): set to nonempty value to simulate missing development packages])
 if test -n "$DISTCHECK" ; then
   test -z "$PERL"  && PERL=no
   test -z "$OPTGEN_PERL" && OPTGEN_PERL=no
   test -z "$DOXYGEN" && DOXYGEN=no
   test -z "$POD2X" && POD2TEXT=no
   test -z "$POD2X" && POD2MAN=no
   test -z "$POD2X" && POD2HTML=no
   test -z "$POD2X" && POD2LATEX=no
   test -z "$FLEX"  && FLEX=no
   test -z "$BISON" && BISON=no
 fi
## /DISTCHECK
##^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
]
)
