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

SUBDIRS = src

##-----------------------------------------------------------------------
## PODs

PODS = README.pod

##-----------------------------------------------------------------------
## Subdirs: perl

ALL_LOCAL_DEPS += DTA-TokWrap/Makefile

DTA-TokWrap/Makefile:
	(cd DTA-TokWrap; $(PERL) Makefile.PL)

all-local: $(ALL_LOCAL_DEPS)
	$(MAKE) -C DTA-TokWrap

install-data-local: DTA-TokWrap/Makefile
	$(MAKE) -C DTA-TokWrap install

clean-local: DTA-TokWrap/Makefile
	$(MAKE) -C DTA-TokWrap clean
