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
	dtatw-tok2xml \
	dtatw-txml2wxml \
	dtatw-txml2sxml \
	dtatw-txml2axml \
	dtatw-txml2master

EXTRA_PROGRAMS = dtatw-cxlexer dtatw-txml2master

common_deps = dtatwCommon.c dtatwCommon.h config.h dtatwConfig.h dtatwConfigAuto.h dtatwConfigNoAuto.h
expat_deps = dtatwExpat.c dtatwExpat.h

dtatw_mkindex_SOURCES = dtatw-mkindex.c $(common_deps) $(expat_deps)
dtatw_mkindex_LDADD = $(EXPAT_LIBS)

if HAVE_FLEX
dtatw_tokenize_dummy_SOURCES = dtatw-tokenize-dummy.l
else
dtatw_tokenize_dummy_SOURCES = dtatw-tokenize-dummy.c
endif

dtatw_rm_namespaces_SOURCES = dtatw-rm-namespaces.c $(common_deps) $(expat_deps)
dtatw_rm_namespaces_LDADD = $(EXPAT_LIBS)

if HAVE_FLEX
dtatw_cxlexer_SOURCES = dtatw-cxlexer.l $(common_deps)
else
dtatw_cxlexer_SOURCES = dtatw-cxlexer.c $(common_deps)
endif

dtatw_cxlexer_CPPFLAGS = -DCXLEXER_MAIN

if HAVE_FLEX
dtatw-cxlexer.h: dtatw-cxlexer.c
endif

dtatw_tok2xml_SOURCES = dtatw-tok2xml.c $(common_deps)

dtatw_txml2wxml_SOURCES = dtatw-txml2wxml.c $(common_deps) $(expat_deps)
dtatw_txml2wxml_LDADD   = $(EXPAT_LIBS)

dtatw_txml2sxml_SOURCES = dtatw-txml2sxml.c $(common_deps) $(expat_deps)
dtatw_txml2sxml_LDADD   = $(EXPAT_LIBS)

dtatw_txml2axml_SOURCES = dtatw-txml2axml.c $(common_deps) $(expat_deps)
dtatw_txml2axml_LDADD   = $(EXPAT_LIBS)

dtatw_txml2master_SOURCES = dtatw-txml2master.c $(common_deps) $(expat_deps)
dtatw_txml2master_LDADD   = $(EXPAT_LIBS)

extra: dtatw-txml2master

##-----------------------------------------------------------------------
## Dist

EXTRA_DIST += \
	dtatw-tokenize-dummy.l dtatw-cxlexer.l \
	dtatw-tokenize-dummy.c dtatw-cxlexer.c
