## File: Makefile.am
## Description: automake file, src-level
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
## Includes
include $(top_srcdir)/Common.am

##-----------------------------------------------------------------------
## PROGRAMS

bin_PROGRAMS = \
	dtatw-mkindex \
	dtatw-tokenize-dummy \
	xml-rm-namespaces

dtatw_mkindex_SOURCES = dtatw-mkindex.c

if HAVE_FLEX
dtatw_tokenize_dummy_SOURCES = dtatw-tokenize-dummy.l
else
dtatw_tokenize_dummy_SOURCES = dtatw-tokenize-dummy.c
endif

xml_rm_namespaces_SOURCES = xml-rm-namespaces.c

##-----------------------------------------------------------------------
## Dist

EXTRA_DIST += dtatw-tokenize-dummy.c
