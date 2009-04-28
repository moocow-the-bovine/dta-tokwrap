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

SUBDIRS = src doc
#SUBDIRS += DTA-TokWrap  ##-- works (kinda), but breaks 'make clean'

##-----------------------------------------------------------------------
## PODs

PODS = README.pod

##-----------------------------------------------------------------------
## Targets: docs

pkgdoc_DATA = $(PODS:.pod=.txt)
#$(PODS:.pod=.html)

##-----------------------------------------------------------------------
## Subdirs: perl

ALL_LOCAL_DEPS += DTA-TokWrap/Makefile
all-local: $(ALL_LOCAL_DEPS)
	$(MAKE) -C DTA-TokWrap

DTA-TokWrap/Makefile:
	(cd DTA-TokWrap; $(PERL) Makefile.PL)

install-exec-local: DTA-TokWrap/Makefile
	$(MAKE) -C DTA-TokWrap install

##-- dist-hook requires "distdir_am" target in perl sub-module
dist-hook:
	$(MAKE) -C perlpd DISTDIR_AM="$(distdir)/DTA-TokWrap" distdir_am

##-- 'SUBDIRS = DTA-TokWrap' causes multiple 'make cleans' to puke
clean-local:
	if test -f DTA-TokWrap/Makefile ; then $(MAKE) -C DTA-TokWrap clean; fi
