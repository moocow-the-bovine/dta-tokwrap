##-*- Mode: Makefile -*-

## File: Makefile
## Author: Bryan Jurish <jurish@bbaw.de>
## Description: Makefile for preparation for dta-release preprocessing

##======================================================================
## Variables

##--------------------------------------------------------------
## Variables: Server Sources

## up_fromurl, up_frompats
##  + for update
up_fromurl = kirk.bbaw.de:/home/dta/DTA_Produktion/volltext/konvertierung/05_run/
up_include = --include=*.txt.xml

#rsync=rsync -e ssh -vuzaC
#rsync=rsync -e ssh --verbose --update --compress --archive --cvs-exclude
##--
#rsync  =rsync -e ssh -vuzaC --no-perms --chmod=Fa-x,go-wx
##rsync =rsync -e ssh --verbose --update --compress --archive --cvs-exclude --no-perms --chmod=Fa-x,go-wx
##--
rsync  =rsync -e ssh -vzaC --no-perms --chmod=Fa-x,go-wx
#rsync =rsync -e ssh --verbose --compress --archive --cvs-exclude --no-perms --chmod=Fa-x,go-wx


## up_files
##  + source files on server
up_files = `$(rsync) --list-only $(up_include) $(up_fromurl) ./ | awk '{print $$5}' | grep '\.xml$$'`

##--------------------------------------------------------------
## Variables: Sources

## XML_TXT (*.txt.xml)
## + source xml files WITHOUT <c> elements and WITHOUT <lb/> linebreaks
#XML_TXT   = kant_pvernunft_1788_pb.txt.xml
XML_TXT ?= $(wildcard *.txt.xml)

## XML_TXT_HAS_LB : empty for false
#XML_TXT_HAS_LB = yes

## XML_TXTLB (*.txt+lb.xml)
##  + source xml files WITHOUT <c> elements and WITHOUT <lb/> linebreaks
XML_TXTLB = $(XML_TXT:.txt.xml=.txt+lb.xml)
#XML_TXTLB += $(wildcard *.txt+lb.xml)
#XML_TXTLB += test-raw.txt+lb.xml

## XML_CHR (*.chr.xml)
##  + source xml files WITH <c> elements and WITH <lb/> linebreaks, (no-op for literals)
#XML_CHR   = test1.chr.xml test-3k.chr.xml ex1.chr.xml $(XML_TXTLB:.txt+lb.xml=.chr.xml)
XML_CHR = $(XML_TXTLB:.txt+lb.xml=.chr.xml)
#XML_CHR += $(wildcard *.chr.xml)
#XML_CHR += test1.chr.xml test-3k.chr.xml
#XML_CHR += kraepelin_arzneimittel_1892.chr.xml

## TARGETS
##  + top-level targets
TARGETS = $(XML_CHR)

##--------------------------------------------------------------
## Variables: stylesheets, scripts & programs

## INPLACE
##  + whether we're running in moocow's own directory hierarchy
ifeq "$(INPLACE)" ""
ifeq "$(notdir $(shell readlink -f ../..))" "dta-tokwrap"
INPLACE=yes
else
INPLACE=no
endif
endif

## TW_ROOT
##  + dta-tokwrap source root directory, only set if INPLACE=yes
ifeq "$(INPLACE)" "yes"
TW_ROOT = ../..
endif

## XSL_DIR
##  + directory containing miscellaneous dta-tokwrap XSL scripts
ifeq "$(INPLACE)" "yes"
XSL_DIR = $(TW_ROOT)/scripts
else
XSL_DIR = /usr/local/share/dta-tokwrap/stylesheets
endif

## SCRIPT_DIR
##  + directory containing miscellaneous dta-tokwrap perl scripts
##  + may be empty to use scripts in $PATH
##  + otherwise, should have a trailing dir-separator (slash)
ifeq "$(INPLACE)" "yes"
SCRIPT_DIR = $(TW_ROOT)/scripts/
else
#SCRIPT_DIR = /usr/local/bin/  ##-- assumed in path
endif

## RMNS
##  + namespace removal hack script
ifeq "$(INPLACE)" "yes"
RMNS = $(TW_ROOT)/src/dtatw-rm-namespaces
else
RMNS = dtatw-rm-namespaces
endif

##--------------------------------------------------------------
## Variables: cleanup

CLEAN_DEPS=
CLEAN_FILES=

REALCLEAN_DEPS=clean
REALCLEAN_FILES=

##======================================================================
## Rules: top-level

default: update $(TARGETS)

all: $(TARGETS)

.SECONDARY:

config:
	@echo "XML_TXT=$(XML_TXT)"
	@echo "XML_TXTLB=$(XML_TXTLB)"
	@echo "XML_CHR=$(XML_CHR)"
	@echo "XSL_DIR=$(XSL_DIR)"
	@echo "SCRIPT_DIR=$(SCRIPT_DIR)"
	@echo "RMNS=$(RMNS)"

##======================================================================
## Rules: Import / update data

up: update
update:
	$(rsync) $(up_include) --update $(up_fromurl) ./

force-update: import
im: import
imp: import
import:
	for f in $(up_files); do rm -f "$$f"; done
	$(rsync) $(up_include) $(up_fromurl) ./

uclean:
	up_files="$(up_files)"; \
	test -z "$$up_files" || rm -f $$up_files

##======================================================================
## Rules: scripts

ifeq "$(INPLACE)" "yes"
scripts: $(SCRIPT_DIR)dtatw-add-c.perl
else
scripts:
	true
endif

##======================================================================
## Rules: XML preprocessing

##--------------------------------------------------------------
## Rules: XML preprocessing: add linebreaks

lb: txt+lb
txt+lb: $(XML_TXT:.txt.xml=.txt+lb.xml)

ifeq "$(XML_TXT_HAS_LB)" ""
%.txt+lb.xml: $(XSL_DIR)/dtatw-add-lb.xsl %.txt.xml
	xsltproc -o "$@" $^
else
%.txt+lb.xml: %.txt.xml
	rm -f "$@"
	ln $< $@
endif

no-lb: ; rm -f $(XML_TXT:.txt.xml=.txt+lb.xml)

REALCLEAN_FILES += $(XML_TXT:.txt.xml=.txt+lb.xml)

##--------------------------------------------------------------
## Rules: XML preprocessing: add <c> elements

%.chr.xml: %.txt+lb.xml scripts
	$(SCRIPT_DIR)dtatw-add-c.perl $< -o $@
chr: $(XML_CHR)
no-chr: ; rm -f $(XML_TXTLB:.txt+lb.xml=.chr.xml)
REALCLEAN_FILES += $(XML_TXTLB:.txt+lb.xml=.chr.xml)


##======================================================================
## Rules: generic XML stuff

##-- pretty-printing (.fmt)
%.fmt: %
	xmllint --format -o $@ $<

CLEAN_FILES += *.fmt

##-- namespace removal (.nons)
%.nons: % $(RMNS)
	$(RMNS) $< $@

CLEAN_FILES += *.nons


##======================================================================
## Rules: cleanup

clean: $(CLEAN_DEPS)
	test -z "$(CLEAN_FILES)" || rm -f $(CLEAN_FILES)

realclean: $(REALCLEAN_DEPS)
	test -z "$(REALCLEAN_FILES)" || rm -f $(REALCLEAN_FILES)
