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
	dtatw-txml2wxml \
	dtatw-rm-namespaces

dtatw_mkindex_SOURCES = dtatw-mkindex.c

if HAVE_FLEX
dtatw_tokenize_dummy_SOURCES = dtatw-tokenize-dummy.l
else
dtatw_tokenize_dummy_SOURCES = dtatw-tokenize-dummy.c
endif

dtatw_rm_namespaces_SOURCES = dtatw-rm-namespaces.c

##-----------------------------------------------------------------------
## Dist

EXTRA_DIST += dtatw-tokenize-dummy.c
