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
	dtatw-t2xml \
	dtatw-txml2wxml \
	dtatw-txml2sxml \
	dtatw-txml2axml

EXTRA_PROGRAMS = dtatw-cxlexer

common_deps = dtatwCommon.c dtatwCommon.h

dtatw_mkindex_SOURCES = dtatw-mkindex.c $(common_deps)

if HAVE_FLEX
dtatw_tokenize_dummy_SOURCES = dtatw-tokenize-dummy.l
else
dtatw_tokenize_dummy_SOURCES = dtatw-tokenize-dummy.c
endif

dtatw_rm_namespaces_SOURCES = dtatw-rm-namespaces.c $(common_deps)


if HAVE_FLEX
dtatw_cxlexer_SOURCES = dtatw-cxlexer.l $(common_deps)
dtatw_t2xml_SOURCES = dtatw-t2xml.c dtatw-cxlexer.l dtatw-cxlexer.h $(common_deps)
else
dtatw_cxlexer_SOURCES = dtatw-cxlexer.c $(common_deps)
dtatw_t2xml_SOURCES = dtatw-t2xml.c dtatw-cxlexer.c dtatw-cxlexer.h $(common_deps)
endif

dtatw_cxlexer_CPPFLAGS = -DCXLEXER_MAIN

if HAVE_FLEX
dtatw-cxlexer.h: dtatw-cxlexer.c
endif

dtatw_txml2wxml_SOURCES = dtatw-txml2wxml.c $(common_deps)
dtatw_txml2sxml_SOURCES = dtatw-txml2sxml.c $(common_deps)
dtatw_txml2axml_SOURCES = dtatw-txml2axml.c $(common_deps)

##-----------------------------------------------------------------------
## Dist

EXTRA_DIST += \
	dtatw-tokenize-dummy.l dtatw-cxlexer.l \
	dtatw-tokenize-dummy.c dtatw-cxlexer.c
