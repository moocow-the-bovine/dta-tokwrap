## File: Makefile.am
## Description: automake file, top-level
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
## Includes
include $(top_srcdir)/Common.am

##-----------------------------------------------------------------------
## Options & Subdirectories

##-- aclocal options (top level only)
ACLOCAL_AMFLAGS = -I m4

## --- automake options (top level only)
#AUTOMAKE_OPTIONS = foreign dist-bzip2 dist-zip
AUTOMAKE_OPTIONS = foreign

SUBDIRS = src scripts doc
#SUBDIRS += DTA-TokWrap  ##-- works (kinda), but breaks 'make clean'

## --- distcheck stuff
DISTCHECK_CONFIGURE_FLAGS =
DISTCHECK_CONFIGURE_FLAGS += PERL="$(PERL)" DISTCHECK=1

## --- ignore 'uninstall' for 'make distcheck', since perl doesn't like it
distuninstallcheck:
	@:

##-----------------------------------------------------------------------
## PODs

PODS = README.pod

#pkgdoc_DATA = $(PODS:.pod=.txt)

all-local: $(PODS:.pod=.txt)

##-----------------------------------------------------------------------
## Subdirs: example 'make'

EXMAKE_DIR   = make
EXMAKE_FILES = Makefile User.mak
EXMAKE_DEPS = $(addprefix $(EXMAKE_DIR)/,$(EXMAKE_FILES))

pkgmak_DATA = $(EXMAKE_DEPS)

##-----------------------------------------------------------------------
## Subdirs: perl

PMDEPS = DTA-TokWrap/Makefile
ALL_LOCAL_DEPS += $(PMDEPS) $(EXMAKE_DEPS)

PERL_MFLAGS = DESTDIR="$(DESTDIR)" DISTDIR_AM="../$(distdir)/DTA-TokWrap"
if IS_DISTCHECK
PERL_MFLAGS += PREFIX="$(prefix)"
endif

all-local: $(ALL_LOCAL_DEPS)
	$(MAKE) -C DTA-TokWrap $(PERL_MFLAGS)

DTA-TokWrap/Makefile:
	(cd DTA-TokWrap; $(PERL) Makefile.PL $(MAKEPLFLAGS))

install-exec-local: $(PMDEPS)
	$(MAKE) -C DTA-TokWrap $(PERL_MFLAGS) install


##-- uninstall via MakeMaker is broken (Fri, 01 May 2009 22:30:24 +0200)
#uninstall-local: $(PMDEPS)
#	$(MAKE) -C DTA-TokWrap $(PERL_MFLAGS) uninstall

##-- dist-hook requires "distdir_am" target in perl sub-module
dist-hook: $(PMDEPS)
	$(MAKE) -C DTA-TokWrap $(PERL_MFLAGS) distdir_am

##-- 'SUBDIRS = DTA-TokWrap' causes multiple 'make cleans' to puke
clean-local:
	if test -f DTA-TokWrap/Makefile ; then $(MAKE) -C DTA-TokWrap $(PERL_MFLAGS) clean; fi

##-- distcheck hacks
distclean-local:
	if test -f DTA-TokWrap/Makefile ; then $(MAKE) -C DTA-TokWrap $(PERL_MFLAGS) distclean; fi
	if test "$(srcdir)" != "."; then chmod -R u+w DTA-TokWrap; rm -rf DTA-TokWrap; fi

##-----------------------------------------------------------------------
## clean

if HAVE_POD2HTML
CLEANFILES += $(PODS:.pod=.html)
endif

