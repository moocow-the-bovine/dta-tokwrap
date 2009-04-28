## File: doc/Makefile.am
## Description:
##   + automake file for doc/ subdir
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
## Primaries: headers
##-----------------------------------------------------------------------

## --- recursion subdirectories
SUBDIRS = dot programs

#-----------------------------------------------------------------------
# Variables: cleanup
#-----------------------------------------------------------------------

## --- mostlyclean: built by 'make' & commonly rebuilt
#MOSTLYCLEANFILES =

## --- clean:  built by 'make'
#CLEANFILES =

## --- distclean: built by 'configure'
#DISTCLEANFILES =

## -- maintainerclean: built by maintainer / by hand
MAINTAINERCLEANFILES = *~ .*~ Makefile Makefile.in

#-----------------------------------------------------------------------
# Variables: (un)install
#-----------------------------------------------------------------------
pkgdoc_UNINSTALL_FILES = $(SUBDIRS) README.txt README.html
uninstall-local:
	for f in $(pkgdoc_UNINSTALL_FILES) ; do \
	   rm -rf $(DESTDIR)$(pkgdocdir)/$$f ;\
	done

#-----------------------------------------------------------------------
# Variables: distribution
#-----------------------------------------------------------------------

## --- extra distribution files
#EXTRA_DIST = $(man_MANS) $(pkgdata_DATA)

## --- recursion subdirectories for 'make dist'
#DIST_SUBDIRS =

#-----------------------------------------------------------------------
# Rules: cleanup
#-----------------------------------------------------------------------
.PHONY: cvsclean

cvsclean: maintainer-clean ;
