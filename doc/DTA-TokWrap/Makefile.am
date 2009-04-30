## File: doc/PERLMODULE/Makefile.am
## Description:
##   + automake file for doc/PERLMODULE subdir
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
## Literals
##-----------------------------------------------------------------------

LIBBASE=DTA-TokWrap
LIBCSS=../dtatw.css

##-----------------------------------------------------------------------
## Get list of modules to document
##-----------------------------------------------------------------------

PMSRC = $(top_srcdir)/DTA-TokWrap

$(PMSRC)/Makefile: $(PMSRC)/Makefile.PL
	cd $(PMSRC); $(PERL) Makefile.PL

pm_list: $(PMSRC)/Makefile
	$(MAKE) -C $(PMSRC) PMLIST_AM="$(PWD)/$@" pm_list

no_pm_list:
	rm -f pm_list


##-----------------------------------------------------------------------
## modules to document... 
##-----------------------------------------------------------------------

SUFFIXES = .pm .pod .html .txt

CLEAN_LOCAL_DEPS =
clean-local: $(CLEAN_LOCAL_DEPS)

##-----------------------------------------------------------------------
## POD

POD_DIR ?= pod

pod: pod.stamp

CLEAN_LOCAL_DEPS += no-pod
no-pod:
	for f in `cat pm_list`; do \
	  b=`basename $$f .pod`; \
	  b=`basename $$b .pm`; \
	  rm -f $(POD_DIR)/`dirname $$f`/"$$b.pod"; \
	done
	if test -n "$(POD_DIR)" -a "$(POD_DIR)" != "."; then rm -rf $(POD_DIR); fi
	rm -f pod.stamp

pod.stamp: pm_list
	for f in `cat pm_list`; do \
	  d=`dirname $$f`; \
	  b=`basename $$f .pod`; \
	  b=`basename $$b .pm`; \
	  mkdir -p $(POD_DIR)/$$d; \
	  rm -f $(POD_DIR)/$$d/"$$b.pod"; \
	  cp $(PMSRC)/$$f $(POD_DIR)/$$d/$$b.pod; \
	done
	touch $@

##-----------------------------------------------------------------------
## text

TXT_DIR ?= txt
txt: txt.stamp

no-txt:
	for f in `cat pm_list`; do \
	  b=`basename $$f .pod`; \
	  b=`basename $$b .pm`; \
	  rm -f $(TXT_DIR)/`dirname $$f`/"$$b.txt"; \
	done
	if test -n "$(TXT_DIR)" -a "$(TXT_DIR)" != "."; then rm -rf $(TXT_DIR); fi
	rm -f txt.stamp

if HAVE_POD2TEXT
CLEAN_LOCAL_DEPS += no-txt
txt.stamp: pm_list
	for f in `cat pm_list`; do \
	  d=`dirname $$f`; \
	  b=`basename $$f .pod`; \
	  b=`basename $$b .pm`; \
	  mkdir -p $(TXT_DIR)/$$d; \
	  rm -f $(TXT_DIR)/$$d/"$$b.txt"; \
	  echo " $(POD2TEXT) $(PMSRC)/$$f $(TXT_DIR)/$$d/$$b.txt"; \
	  $(POD2TEXT) $(PMSRC)/$$f $(TXT_DIR)/$$d/$$b.txt; \
	done
	touch $@
else
txt.stamp:
	touch $@
endif

##-----------------------------------------------------------------------
## html

HTML_DIR ?= html

html: html.stamp

no-html:
	for f in `cat pm_list`; do \
	  b=`basename $$f .pod`; \
	  b=`basename $$b .pm`; \
	  rm -f $(HTML_DIR)/`dirname $$f`/"$$b.html"; \
	done
	if test -n "$(HTML_DIR)" -a "$(HTML_DIR)" != "."; then rm -rf $(HTML_DIR); fi
	rm -f html.stamp

POD2HTMLFLAGS = \
	--css=$$topd/$(LIBCSS) \
	--podroot=$(POD_DIR) \
	--htmlroot=$$topd/$(HTML_DIR)

if HAVE_POD2HTML
CLEAN_LOCAL_DEPS += no-html
html.stamp: pm_list
	for f in `cat pm_list`; do \
	  d=`dirname $$f`; \
	  b=`basename $$f .pod`; \
	  b=`basename $$b .pm`; \
	  topd=`dirname $(HTML_DIR)/$$f`; \
	  if test "$$topd" != "."; then topd=`echo "$$topd" | sed -e 's/[^\/]*/\.\./g'`; fi; \
	  mkdir -p $(HTML_DIR)/$$d; \
	  rm -f $(HTML_DIR)/$$d/"$$b.html"; \
	  echo " $(POD2HTML) $(POD2HTMLFLAGS) --infile=$(PMSRC)/$$f --outfile=$(HTML_DIR)/$$d/$$b.html"; \
	  $(POD2HTML) $(POD2HTMLFLAGS) --infile=$(PMSRC)/$$f --outfile=$(HTML_DIR)/$$d/$$b.html; \
	done
	touch $@
else
html.stamp:
	touch $@
endif

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
	*~ .*~ Makefile Makefile.in \
	pm_list

#-----------------------------------------------------------------------
# Rules: cleanup
#-----------------------------------------------------------------------
.PHONY: cvsclean

cvsclean: maintainer-clean ;
