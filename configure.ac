dnl Process this file with autoconf to produce a configure script.
AC_PREREQ(2.5)

dnl Some handy macros
define([THE_PACKAGE_NAME],    [dta-tokwrap])
define([THE_PACKAGE_VERSION], [0.02])
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
AX_CHECK_FLEX()
AX_CHECK_BISON()
AX_GNU_LEXYACC()


dnl v--- needed if Makefile.am uses _LTLIBRARIES targets
dnl AC_PROG_LIBTOOL

dnl v--- for static-only libraries (non-libtool)
dnl AC_PROG_RANLIB

#---------------------------------------------------------------
# short package include-dir
spkgincludedir="\${includedir}/AC_PACKAGE_NAME"
AC_SUBST(spkgincludedir)
# short package include-dir
#---------------------------------------------------------------

#---------------------------------------------------------------
# share/package dir
sharepkgdir="\${prefix}/share/AC_PACKAGE_NAME"
pkgxsldir="\${sharepkgdir}/stylesheets"
AC_SUBST(sharepkgdir)
AC_SUBST(pkgxsldir)
# share/package dir
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

##vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
## Documentation
##
AX_DOC_COMMON()
AX_DOC_POD()
AX_DOC_DOT()
AX_DOC_GOG()
dnl AX_DOC_GOG_LINKS()

pkgdocdotdir="\${docdir}/\${PACKAGE}/dot"
AC_SUBST(pkgdocdotdir)
AC_CONFIG_LINKS([doc/programs/dta-tokwrap.perl.pod:DTA-TokWrap/dta-tokwrap.perl])
AC_CONFIG_LINKS([doc/programs/dtatw-add-c.perl.pod:scripts/dtatw-add-c.perl])
dnl AC_CONFIG_LINKS([doc/programs/dtatw-rm-c.perl.pod:scripts/dtatw-rm-c.perl])   ##-- no pod docs (yet)
dnl AC_CONFIG_LINKS([doc/programs/file-substr.perl.pod:scripts/file-substr.perl]) ##-- no pod docs (yet)
AC_CONFIG_LINKS([doc/README.pod:README.pod])
##
## /Documentation
##^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

##-- no-autoheader stuff
AC_CONFIG_LINKS(src/dtatwConfigNoAuto.h:src/dtatwConfigAuto.h.in)

##vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
## Subdirs:perl
##
AC_MSG_NOTICE([(re-)configuring perl module DTA::TokWrap])
AC_MSG_NOTICE([+ ignore any warnings from Makefile.PL about missing Version.pm])

##-- TODO: pass options down to 'perl Makefile.PL'
AC_ARG_VAR(MAKEPLFLAGS,[Additional flags to pass to `perl Makefile.PL`])

##-- hack for 'make distcheck' / non-inplace builds
if test "$srcdir" != "."; then
   AC_MSG_NOTICE([+ non-inplace build detected: copying $srcdir/DTA-TokWrap/* to DTA-TokWrap/])
   mkdir DTA-TokWrap
   cp -r $srcdir/DTA-TokWrap/* DTA-TokWrap
fi

AC_MSG_NOTICE([cd DTA-TokWrap; $PERL Makefile.PL $MAKEPLFLAGS])
(cd DTA-TokWrap; $PERL Makefile.PL $MAKEPLFLAGS)
##
## /subdirs:perl
##^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


##----------------------------------------------------------------------
## output
##
AC_CONFIG_FILES(DTA-TokWrap/TokWrap/Version.pm)
AC_CONFIG_FILES(doc/DTA-TokWrap/Makefile)
AC_CONFIG_FILES(doc/programs/Makefile)
AC_CONFIG_FILES(doc/dot/Makefile)
AC_CONFIG_FILES(doc/Makefile)
AC_CONFIG_FILES(scripts/Makefile)
AC_CONFIG_FILES(src/Makefile)
AC_CONFIG_FILES(Makefile)
AC_OUTPUT
