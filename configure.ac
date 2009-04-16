dnl Process this file with autoconf to produce a configure script.
AC_PREREQ(2.5)

dnl Some handy macros
define([THE_PACKAGE_NAME],    [dta-tokwrap])
define([THE_PACKAGE_VERSION], [0.0.1])
define([THE_PACKAGE_MAINTAINER],  [jurish@bbaw.de])

AC_INIT(THE_PACKAGE_NAME, THE_PACKAGE_VERSION, THE_PACKAGE_MAINTAINER)

dnl source && aux dir
AC_CONFIG_AUX_DIR(.)

dnl canonical target (sets $target, $target_(cpu|vendor|os) : used for bindist)
AC_CANONICAL_TARGET

dnl use automake
AM_INIT_AUTOMAKE(THE_PACKAGE_NAME, THE_PACKAGE_VERSION)

dnl use autoheader
AM_CONFIG_HEADER([src/dtaTwConfigAuto.h])

dnl default prefix
AC_PREFIX_DEFAULT(/usr/local)

##-- save user flags
AX_SAVE_USERFLAGS

##-- check for compilers (may alter CFLAGS, CXXFLAGS)
AC_PROG_CC
dnl AC_PROG_CXX
dnl AC_LANG(C++)

##-- DISTCHECK: simulate missing development-only packages
AX_ARG_DISTCHECK

##-- flex, bison (also automake LEX, YACC)
AX_CHECK_FLEX
AX_CHECK_BISON
AX_GNU_LEXYACC

dnl v--- needed if Makefile.am uses _LTLIBRARIES targets
dnl AC_PROG_LIBTOOL

dnl v--- for static-only libraries (non-libtool)
dnl AC_PROG_RANLIB

###-- restore user FLAGS
AX_RESTORE_USERFLAGS

#---------------------------------------------------------------
# short package includes
spkgincludedir="\${includedir}/AC_PACKAGE_NAME"
AC_SUBST(spkgincludedir)
# short package includes
#---------------------------------------------------------------

#---------------------------------------------------------------
# get real prefix
AC_CACHE_CHECK([for installation prefix], [ac_cv_install_prefix],
	[if test "$prefix" = "NONE" ; then
	   ac_cv_install_prefix="/usr/local"
	 else
           ac_cv_install_prefix="$prefix"
	 fi
	])

dnl check for strdup
AC_CHECK_FUNC(strdup,[AC_DEFINE(HAVE_STRDUP,1,[Define this if you have the strdup() function])])


##-- pkg-config
AX_CHECK_PKGCONFIG
dnl AX_PKGCONFIG_DIR

##-- perl, gog
AX_CHECK_PERL
AX_CHECK_GOG

##vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
## Documentation
##
AX_DOC_COMMON
AX_DOC_POD
AX_DOC_GOG
AX_DOC_GOG_LINKS
##
## /Documentation
##^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

##-- no-autoheader stuff
AC_CONFIG_LINKS(src/dtaTwNoAuto.h:src/dtaTwConfigAuto.h.in)

##----------------------------------------------------------------------
## output
##
dnl AC_CONFIG_FILES(src/Makefile)
AC_CONFIG_FILES(Makefile)
AC_OUTPUT
