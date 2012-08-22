dnl Process this file with autoconf to produce a configure script.
AC_PREREQ(2.5)

dnl Some handy macros
define([THE_PACKAGE_NAME],    [dta-tokwrap])
define([THE_PACKAGE_VERSION], [0.33])
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
spkgincludedir="\${includedir}/AC_PACKAGE_NAME"
AC_SUBST(spkgincludedir)
# short package include-dir
#---------------------------------------------------------------

#---------------------------------------------------------------
# share/package dir
sharepkgdir="\${prefix}/share/AC_PACKAGE_NAME"
pkgxsldir="\${sharepkgdir}/stylesheets"
pkgmakdir="\${sharepkgdir}/make"
AC_SUBST(sharepkgdir)
AC_SUBST(pkgxsldir)
AC_SUBST(pkgmakdir)
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
AC_CONFIG_LINKS([doc/programs/dtatw-add-w.perl.pod:scripts/dtatw-add-w.perl])
AC_CONFIG_LINKS([doc/programs/dtatw-add-s.perl.pod:scripts/dtatw-add-s.perl])
##
dnl AC_CONFIG_LINKS([doc/programs/dtatw-rm-c.perl.pod:scripts/dtatw-rm-c.perl])   ##-- no pod docs (yet)
dnl AC_CONFIG_LINKS([doc/programs/dtatw-rm-lb.perl.pod:scripts/dtatw-rm-lb.perl])   ##-- no pod docs (yet)
dnl AC_CONFIG_LINKS([doc/programs/file-substr.perl.pod:scripts/file-substr.perl]) ##-- no pod docs (yet)
AC_CONFIG_LINKS([doc/programs/dtatw-cids2local.perl.pod:scripts/dtatw-cids2local.perl])
AC_CONFIG_LINKS([doc/programs/dtatw-mkpx.perl.pod:scripts/dtatw-mkpx.perl])
AC_CONFIG_LINKS([doc/programs/dtatw-txml2uxml.perl.pod:scripts/dtatw-txml2uxml.perl])
##
AC_CONFIG_LINKS([doc/programs/dtatw-splice.perl.pod:scripts/dtatw-splice.perl])
AC_CONFIG_LINKS([doc/programs/dtatw-get-ddc-attrs.perl.pod:scripts/dtatw-get-ddc-attrs.perl])
AC_CONFIG_LINKS([doc/programs/dtatw-get-header.perl.pod:scripts/dtatw-get-header.perl])
AC_CONFIG_LINKS([doc/programs/dtatw-xml2ddc.perl.pod:scripts/dtatw-xml2ddc.perl])
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
