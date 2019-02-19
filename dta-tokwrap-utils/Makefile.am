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
#SUBDIRS += DTA-TokWrap  ##-- works (kinda), but breaks 'make clean'

## --- distcheck stuff
DISTCHECK_CONFIGURE_FLAGS =
DISTCHECK_CONFIGURE_FLAGS += PERL="$(PERL)" DISTCHECK=1

## --- ignore 'uninstall' for 'make distcheck', since perl doesn't like it
#distuninstallcheck:
#	@:

##-----------------------------------------------------------------------
## PODs

PODS = README.pod

pkgdoc_DATA = $(PODS:.pod=.txt) COPYING COPYING.LESSER ChangeLog

all-local: $(PODS:.pod=.txt)

##-----------------------------------------------------------------------
## Subdirs: example 'make' -- REFACTORED to ../make

##-----------------------------------------------------------------------
## Subdirs: perl -- REFACTORED to ../DTA-TokWrap

##-----------------------------------------------------------------------
## clean

if HAVE_POD2HTML
CLEANFILES += $(PODS:.pod=.html)
endif

