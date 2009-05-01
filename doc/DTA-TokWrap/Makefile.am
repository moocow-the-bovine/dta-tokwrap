## File: doc/PERLMODULE/Makefile.am
## Description:
##   + automake file for doc/PERLMODULE subdir
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
## Literals
##-----------------------------------------------------------------------

LIBPREFIX=DTA
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

POD_DIR ?= pod/$(LIBPREFIX)
PROG_POD_DIR ?= ../programs

pod: pod.stamp

CLEAN_LOCAL_DEPS += no-pod
no-pod:
	rm -rf pod programs pod.stamp pod.prog.stamp pod.pm.stamp

pod.stamp: pod.pm.stamp pod.prog.stamp
	touch $@

pod.prog.stamp:
	if test -n "$(PROG_POD_DIR)" ; then \
	  mkdir pod/programs; \
	  for f in $(PROG_POD_DIR)/*.pod ; do \
	    cp $$f pod/programs; \
	  done; \
	fi;
	touch $@

pod.pm.stamp: pm_list
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

TXT_DIR ?= txt/$(LIBPREFIX)
txt: txt.stamp

no-txt:
	rm -rf txt txt.stamp

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

HTML_DIR ?= html/$(LIBPREFIX)

html: html.stamp

no-html:
	rm -rf html html.stamp

POD2HTMLFLAGS = \
	--podroot=$(POD_DIR) \
	--htmlroot=$$topd/html \
	--css=$$topd/$(LIBCSS) \
	--podpath=../programs

if HAVE_POD2HTML
CLEAN_LOCAL_DEPS += no-html
html.stamp: pm_list pod.stamp
	for f in `cat pm_list`; do \
	  d=`dirname $$f`; \
	  b=`basename $$f .pod`; \
	  b=`basename $$b .pm`; \
	  topd=`dirname $(HTML_DIR)/$$f`; \
	  if test "$$topd" != "."; then topd=`echo "$$topd" | sed -e 's/[^\/][^\/]*/\.\./g'`; fi; \
	  mkdir -p $(HTML_DIR)/$$d; \
	  rm -f $(HTML_DIR)/$$d/"$$b.html"; \
	  echo " $(POD2HTML) $(POD2HTMLFLAGS) --infile=$(PMSRC)/$$f --outfile=$(HTML_DIR)/$$d/$$b.html"; \
	  $(POD2HTML) $(POD2HTMLFLAGS) --infile=$(PMSRC)/$$f --outfile=$(HTML_DIR)/$$d/$$b.html \
	    || break; \
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
