## File: scripts/Makefile.am
## Description:
##   + automake file for scripts/ subdir
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
## Primaries: headers
##-----------------------------------------------------------------------

## --- recursion subdirectories
#SUBDIRS =

#-----------------------------------------------------------------------
# Variables: cleanup
#-----------------------------------------------------------------------

## --- mostlyclean: built by 'make' & commonly rebuilt
MOSTLYCLEANFILES =

## --- clean:  built by 'make'
CLEANFILES =

## --- distclean: built by 'configure'
DISTCLEANFILES =

## -- maintainerclean: built by maintainer / by hand
MAINTAINERCLEANFILES = *~ .*~ Makefile Makefile.in

#-----------------------------------------------------------------------
# Variables: primaries
#-----------------------------------------------------------------------

pkgxsl_DATA = \
	dtatw-add-lb.xsl \
	dtatw-assign-cids.xsl \
	dtatw-rm-c.xsl \
	dtatw-rm-lb.xsl \
	dtatw-txml2tt.xsl

bin_SCRIPTS = \
	dtatw-add-c.perl \
	dtatw-cids2local.perl \
	dtatw-mkpx.perl \
	dtatw-add-w.perl \
	dtatw-add-s.perl \
	dtatw-rm-lb.perl \
	dtatw-rm-c.perl \
	dtatw-rm-w.perl \
	dtatw-rm-s.perl \
	dtatw-tt-dictapply.perl \
	dtatw-cabtt2xml.perl \
	dtatw-txml2uxml.perl \
	file-substr.perl

#	dtatw-txml2cspan.perl

#-----------------------------------------------------------------------
# Variables: distribution
#-----------------------------------------------------------------------

## --- extra distribution files
EXTRA_DIST = \
	$(pkgxsl_DATA) \
	$(bin_SCRIPTS)

## --- recursion subdirectories for 'make dist'
#DIST_SUBDIRS =

#-----------------------------------------------------------------------
# Rules: cleanup
#-----------------------------------------------------------------------
.PHONY: cvsclean

cvsclean: maintainer-clean ;
