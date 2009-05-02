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
	dtatw-rm-namespaces \
	dtatw-tokenize-dummy \
	dtatw-txml2wxml \
	dtatw-txml2sxml \
	dtatw-txml2axml

common_deps = dtatwCommon.c dtatwCommon.h

dtatw_mkindex_SOURCES = dtatw-mkindex.c $(common_deps)

if HAVE_FLEX
dtatw_tokenize_dummy_SOURCES = dtatw-tokenize-dummy.l
else
dtatw_tokenize_dummy_SOURCES = dtatw-tokenize-dummy.c
endif

dtatw_rm_namespaces_SOURCES = dtatw-rm-namespaces.c $(common_deps)

dtatw_txml2wxml_SOURCES = dtatw-txml2wxml.c $(common_deps)
dtatw_txml2sxml_SOURCES = dtatw-txml2sxml.c $(common_deps)
dtatw_txml2axml_SOURCES = dtatw-txml2axml.c $(common_deps)

##-----------------------------------------------------------------------
## Dist

EXTRA_DIST += dtatw-tokenize-dummy.c
