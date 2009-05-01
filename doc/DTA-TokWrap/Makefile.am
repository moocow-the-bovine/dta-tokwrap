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
#else
#pod.stamp:
#	mkdir $(POD_DIR)
#	touch $@
#endif

no-pod:
	rm -rf $(POD_DIR) pod.stamp

#if DOC_WANT_POD
#ALL_LOCAL_DEPS += pod.stamp
#PKGDOC_DIRS += $(POD_DIR)
#endif

#if HAVE_PODSELECT
CLEAN_LOCAL_DEPS += no-pod
#endif

##-----------------------------------------------------------------------
## text

TXT_DIR ?= txt

txt: txt.stamp

if HAVE_POD2TEXT
txt.stamp: $(PMDEPS)
	$(MAKE) -C $(PMSRC) INST_TEXTDIR=$(PWD)/$(TXT_DIR) textifypods
	touch $@
CLEAN_LOCAL_DEPS += no-txt
else
txt.stamp:
	mkdir $(TXT_DIR)
	touch $@
endif

no-txt:
	rm -rf $(TXT_DIR) txt.stamp

if DOC_WANT_TXT
ALL_LOCAL_DEPS += txt.stamp
PKGDOC_DIRS += $(TXT_DIR)
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
	rm -f $(HTML_DIR)/$(CSS)
CLEAN_LOCAL_DEPS += no-html-css

html: html.stamp css

if HAVE_POD2HTML
html.stamp: $(PMDEPS)
	$(MAKE) -C $(PMSRC) INST_HTMLDIR=$(PWD)/$(HTML_DIR) INST_CSS=$(CSS) htmlifypods
	touch $@
CLEAN_LOCAL_DEPS += no-html

else
html.stamp:
	mkdir $(HTML_DIR)
	touch $@
endif

no-html:
	rm -rf $(HTML_DIR) html.stamp

if DOC_WANT_HTML
ALL_LOCAL_DEPS += html
PKGDOC_DIRS += $(HTML_DIR)
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

#-----------------------------------------------------------------------
# Variables: cleanup
#-----------------------------------------------------------------------

## --- mostlyclean: built by 'make' & commonly rebuilt
MOSTLYCLEANFILES = pod2htm*.tmp

## --- clean:  built by 'make'
CLEANFILES = \
	pod.stamp txt.stamp html.stamp \
	$(CSS_LOCAL)

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
