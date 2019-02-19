dnl Process this file with autoconf to produce a configure script.
AC_PREREQ(2.5)

dnl Some handy macros
define([THE_PACKAGE_NAME],    [dta-tokwrap-utils])
define([THE_PACKAGE_VERSION], [0.86-pre1])
define([THE_PACKAGE_MAINTAINER],  [jurish@bbaw.de])

AC_INIT(THE_PACKAGE_NAME, THE_PACKAGE_VERSION, THE_PACKAGE_MAINTAINER)

dnl source && aux dir
AC_CONFIG_AUX_DIR(.)

dnl canonical target (sets $target, $target_(cpu|vendor|os) : used for bindist)
AC_CANONICAL_TARGET

dnl use automake
AM_INIT_AUTOMAKE(THE_PACKAGE_NAME, THE_PACKAGE_VERSION)

dnl use autoheader
AM_CONFIG_HEADER([src/dtatwConfigAuto.h])

dnl default prefix
AC_PREFIX_DEFAULT(/usr/local)

##-- save user flags
AX_SAVE_USERFLAGS()

##-- check for compilers (may alter CFLAGS, CXXFLAGS)
AC_PROG_CC
dnl AC_PROG_CXX
dnl AC_LANG(C++)

##-- DISTCHECK: simulate missing development-only packages
AX_ARG_DISTCHECK()

##-- flex, bison (also automake LEX, YACC)
AX_HAVE_GNU_MAKE()
AX_CHECK_FLEX()
AX_CHECK_BISON()
AX_GNU_LEXYACC()


dnl v--- needed if Makefile.am uses _LTLIBRARIES targets
dnl AC_PROG_LIBTOOL

dnl v--- for static-only libraries (non-libtool)
dnl AC_PROG_RANLIB

##---------------------------------------------------------------
## svn info
##  + keyword substitution requires property svn:keywords set on
##    this file:
##    $ svn propset svn:keywords "HeadURL Id" configure.ac
##  + or even:
##    $ svn propset svn:keywords "HeadURL Id Date Rev Author" configure.ac
AC_PATH_PROG([SVNVERSION],[svnversion],[no])

AC_MSG_CHECKING([for SVN HeadURL])
SVNURL=`echo '$HeadURL$' \
  | sed -e's/^\$HeadURL:[ ]*//1' -e's/\/configure.ac[ ]*\$$//1'`
AC_MSG_RESULT([$SVNURL])

AC_MSG_CHECKING([for SVN revision of working copy])
if test -n "$SVNVERSION" -a "$SVNVERSION" != "no"; then
  SVNREV=`$SVNVERSION -n`
else
  SVNREV='exported'
fi
AC_MSG_RESULT([$SVNREV])

SVNID="${SVNURL} @ ${SVNREV}"
AC_SUBST(SVNURL)
AC_SUBST(SVNREV)
AC_SUBST(SVNID)
AC_DEFINE_UNQUOTED(PACKAGE_SVNURL, "$SVNURL", [Subversion HeadURL of package sources])
AC_DEFINE_UNQUOTED(PACKAGE_SVNREV, "$SVNREV", [Current SVN revision of package sources])
AC_DEFINE_UNQUOTED(PACKAGE_SVNID,  "$SVNID",  [Subversion identifier for package sources])
##
## svn info
##---------------------------------------------------------------

#---------------------------------------------------------------
# short package include-dir
dnl spkgincludedir="\${includedir}/dta-tokwrap"
dnl AC_SUBST(spkgincludedir)
# short package include-dir
#---------------------------------------------------------------

#---------------------------------------------------------------
# share/package dir
#sharepkgdir="\${prefix}/share/AC_PACKAGE_NAME"
dnl sharepkgdir"\${prefix}/share/dta-tokwrap-utils"
dnl pkgxsldir="\${sharepkgdir}/stylesheets"
dnl pkgmakdir="\${sharepkgdir}/make"
pkgdocdir="\${sharepkgdir}/doc"
dnl AC_SUBST(sharepkgdir)
dnl AC_SUBST(pkgxsldir)
dnl AC_SUBST(pkgmakdir)
AC_SUBST(pkgdocdir)
# share/package dir
#---------------------------------------------------------------

#---------------------------------------------------------------
# resource dir (for e.g. dta_abbrevs.lex, dta_mwe.lex)
AC_ARG_WITH([rcdir],
	AC_HELP_STRING([--with-rcdir=DIR],
		[default directory in which to look for shared resources (default=DATADIR/dta-resources]),
	[rcdir="$withval"],
	[rcdir="\${datadir}/dta-resources"])
AC_SUBST(prefix)
AC_SUBST(datadir)
AC_SUBST(rcdir)
# /resource dir
#---------------------------------------------------------------


##-- pkg-config
dnl AX_CHECK_PKGCONFIG
dnl AX_PKGCONFIG_DIR  dnl-- only for packages which install their own .pc file(s)

##-- perl
AX_CHECK_PERL()

##-- Getopt::Gen, optgen.perl
AX_CHECK_GOG()

##-- expat
AX_CHECK_EXPAT()
if test "$ENABLE_EXPAT" != "yes"; then
  AC_MSG_ERROR([could not find expat XML parser library: refusing to continue!])
fi

##-- debug
AX_CHECK_DEBUG()

###-- restore user FLAGS
AX_RESTORE_USERFLAGS()

##-- no-autoheader stuff
AC_CONFIG_LINKS(src/dtatwConfigNoAuto.h:src/dtatwConfigAuto.h.in)

##vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
## Documentation
##
AX_DOC_COMMON()
AX_DOC_POD()
dnl AX_DOC_DOT()
dnl AX_DOC_GOG()
dnl AX_DOC_GOG_LINKS()
##
## /Documentation

##----------------------------------------------------------------------
## output
##
dnl AC_CONFIG_FILES(scripts/Makefile)
AC_CONFIG_FILES(src/Makefile)
AC_CONFIG_FILES(Makefile)
AC_OUTPUT
