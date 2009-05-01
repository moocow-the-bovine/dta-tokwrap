## File: doc/PERLMODULE/Makefile.am
## Description:
##   + automake file for doc/PERLMODULE subdir
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
## Overrides
##-----------------------------------------------------------------------

## CSS file, relative to $(PWD)
CSS_SRC ?= $(srcdir)/../dtatw.css
PKGDOC_SUBDIR = $(DESTDIR)$(pkgdocdir)/$(notdir $(PWD))

##-----------------------------------------------------------------------
## Globals
##-----------------------------------------------------------------------

PMSRC = $(top_builddir)/DTA-TokWrap

$(PMSRC)/Makefile: $(PMSRC)/Makefile.PL
	cd $(PMSRC); $(PERL) Makefile.PL $(MAKEPLFLAGS)

PMDEPS = $(PMSRC)/Makefile

ALL_LOCAL_DEPS =
CLEAN_LOCAL_DEPS =
PKGDOC_DIRS =
DIST_HOOK_DEPS =

all-local: $(ALL_LOCAL_DEPS)
clean-local: $(CLEAN_LOCAL_DEPS)

##-----------------------------------------------------------------------
## POD (debug)

POD_DIR ?= pod

pod: pod.stamp

#if HAVE_PODSELECT
pod.stamp: $(PMDEPS)
	$(MAKE) -C $(PMSRC) INST_PODDIR=$(PWD)/$(POD_DIR) podifypods
	touch $@

pod-dist: pod.stamp
	$(mkdir_p) $(distdir)/$(POD_DIR)
	for f in $(POD_DIR)/*.pod ; do \
	  cp -p $$f $(distdir)/$(POD_DIR) ;\
	done

CLEAN_LOCAL_DEPS += no-pod

#else
#pod.stamp:
#	$(mkdir_p) $(POD_DIR)
#	touch $@
#endif

no-pod:
	rm -f pod.stamp
	rm -f $(POD_DIR)/*.pod || true
	test -d $(POD_DIR) && rmdir $(POD_DIR) || true

#if DOC_WANT_POD
#ALL_LOCAL_DEPS += pod.stamp
#PKGDOC_DIRS += $(POD_DIR)
#DIST_HOOK_DEPS += pod-dist
#endif

##-----------------------------------------------------------------------
## text

TXT_DIR ?= txt

txt: txt.stamp

if HAVE_POD2TEXT
txt.stamp: $(PMDEPS)
	$(MAKE) -C $(PMSRC) INST_TEXTDIR=$(PWD)/$(TXT_DIR) textifypods
	touch $@

txt-dist: txt.stamp
	$(mkdir_p) $(distdir)/$(TXT_DIR)
	for f in $(TXT_DIR)/*.txt ; do \
	  cp -p $$f $(distdir)/$(TXT_DIR) ;\
	done

CLEAN_LOCAL_DEPS += no-txt
else
txt.stamp:
	$(mkdir_p) $(TXT_DIR)
	touch $@
txt-dist: txt.stamp
	@:
endif

no-txt:
	rm -f txt.stamp
	rm -f $(TXT_DIR)/*.txt || true
	test -d $(TXT_DIR) && rmdir $(TXT_DIR) || true

if DOC_WANT_TXT
ALL_LOCAL_DEPS += txt.stamp
PKGDOC_DIRS += $(TXT_DIR)
DIST_HOOK_DEPS += txt-dist
endif

##-----------------------------------------------------------------------
## html

HTML_DIR ?= html
CSS = $(notdir $(CSS_SRC))

css: $(HTML_DIR)/$(CSS)
$(HTML_DIR)/$(CSS): $(CSS_SRC)
	rm -f $@
	cp $< $@
no-html-css:
	rm -f $(HTML_DIR)/$(CSS) || true
	rmdir $(HTML_DIR) || true
CLEAN_LOCAL_DEPS += no-html-css

html: html.stamp css

if HAVE_POD2HTML
html.stamp: $(PMDEPS)
	$(MAKE) -C $(PMSRC) INST_HTMLDIR=$(PWD)/$(HTML_DIR) INST_CSS=$(CSS) htmlifypods
	touch $@

html-dist: html.stamp
	$(mkdir_p) $(distdir)/$(HTML_DIR)
	for f in $(HTML_DIR)/*.html ; do \
	  cp -p $$f $(distdir)/$(HTML_DIR) ;\
	done

CLEAN_LOCAL_DEPS += no-html
else
html.stamp:
	$(mkdir_p) $(HTML_DIR)
	touch $@
html-dist: html.stamp
	@:
endif

no-html:
	rm -f html.stamp
	rm -f $(HTML_DIR)/*.html || true
	test -d $(HTML_DIR) && rmdir $(HTML_DIR) || true

if DOC_WANT_HTML
ALL_LOCAL_DEPS += html
PKGDOC_DIRS += $(HTML_DIR)
DIST_HOOK_DEPS += html-dist
endif

##-----------------------------------------------------------------------
## Install: local
##-----------------------------------------------------------------------

install-data-local:
	$(mkdir_p) $(PKGDOC_SUBDIR) ;\
	for d in $(PKGDOC_DIRS); do \
	  test -d "$$d" || continue; \
	  $(mkdir_p) $(PKGDOC_SUBDIR)/$$d ;\
	  for f in "$$d"/* ; do \
	    $(INSTALL_DATA) $$f $(PKGDOC_SUBDIR)/$$d ;\
	  done ;\
	done

uninstall-local:
	rm -rf $(PKGDOC_SUBDIR)

dist-hook: $(DIST_HOOK_DEPS)

#-----------------------------------------------------------------------
# Variables: cleanup
#-----------------------------------------------------------------------

## --- mostlyclean: built by 'make' & commonly rebuilt
MOSTLYCLEANFILES = pod2htm*.tmp

## --- clean:  built by 'make'
CLEANFILES = \
	pod.stamp txt.stamp html.stamp

## --- distclean: built by 'configure'
#DISTCLEANFILES =

## -- maintainerclean: built by maintainer / by hand
MAINTAINERCLEANFILES = \
	*~ .*~ Makefile Makefile.in

#-----------------------------------------------------------------------
# Rules: cleanup
#-----------------------------------------------------------------------
.PHONY: cvsclean

cvsclean: maintainer-clean ;
