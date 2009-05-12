##-*- Mode: Makefile -*-
##
## File: Makefile
## Author: Bryan Jurish <jurish@bbaw.de>
## Description:
##  + top-level makefile for corpus preparation via dta-tokwrap
## Usage:
##  + DO NOT edit this file (unless you *really* know what you're doing)
##  + Copy the file "User.mak" which came with the distribution to
##    a new file, e.g. "MyConfig.mak", and edit the new file to suit your
##    needs
##  + Call make with "config=MyConfig.mak" on the command line, e.g.:
##    $ make config=MyConfig.mak all
##  + ... you atta be in buttah ...
##======================================================================

##======================================================================
## Configuration: User

config ?= User.mak
include $(config)

##======================================================================
## Configuration: Defaults

##--------------------------------------------------------------
## Configuration: Defaults: sources & targets

xmldir ?= .
xml    ?= $(wildcard $(xmldir),*.chr.xml) $(wildcard $(xmldir),*.char.xml)
outdir = .
tmpdir = $(outdir)

XML = $(notdir $(xml))

##--------------------------------------------------------------
## Configuration: Defaults: tokwrap

## TOKWRAP_OPTS
##  + all options for dta-tokwrap.perl
TOKWRAP_OPTS = -keep

ifeq "$(inplace)" ""
ifeq "$(shell /bin/ls -1 ../src/dtatw-mkindex.c)" ""
inplace=no
else
inplace=yes
endif
endif

ifeq "$(inplace)" "yes"
TOKWRAP_OPTS += -inplace
else
TOKWRAP_OPTS += -noinplace
endif

##--------------------------------------------------------------
## Configuration: Defaults: dta-tokwrap.perl: behavior

ifeq "$(dummytok)" ""
ifeq "$(shell which dwds_tomasotath)" ""
override dummytok := yes
else
override dummytok := no
endif
endif

ifeq "$(dummytok)" "no"
TOKWRAP_OPTS += -nodummytok -weak-hints
else
TOKWRAP_OPTS += -dummytok -strong-hints
endif

ifneq "$(abbrevlex)" ""
TOKWRAP_OPTS += -abbrev-lex="$(abbrevlex)"
endif

ifneq "$(mwelex)" ""
TOKWRAP_OPTS += -mwe-lex="$(mwelex)"
endif

##--------------------------------------------------------------
## Configuration: Defaults: dta-tokwrap.perl: verbosity & logging

ifneq "$(verbose)" ""
TOKWRAP_OPTS += -verbose=$(verbose)
endif

ifneq "$(loglevel)" ""
TOKWRAP_OPTS += -log-level="$(loglevel)"
endif

ifneq "$(logfile)" ""
TOKWRAP_OPTS += -log-file="$(logfile)"
endif

ifneq "$(stderr)" ""
ifeq "$(stderr)" "no"
TOKWRAP_OPTS += -nostderr
else
TOKWRAP_OPTS += -stderr  ##-- default
endif
endif

ifneq "$(trace)" ""
ifeq "$(trace)" "no"
TOKWRAP_OPTS += -notrace
else
TOKWRAP_OPTS += -trace
endif
endif

ifneq "$(profile)" ""
ifneq "$(profile)" "no"
TOKWRAP_OPTS += -profile
else
TOKWRAP_OPTS += -noprofile
endif
endif

##-- user options
TOKWRAP_OPTS += $(twopts)

##--------------------------------------------------------------
## Configuration: Defaults: programs & in-place execution

PERL = perl

ifeq "$(inplace)" "yes"

XSL_DIR = ../scripts

PROG_DIR  = ../src/
PROG_DEPS = $(wildcard $(PROG_DIR)*.c) $(wildcard $(PROG_DIR)*.h) $(wildcard $(PROG_DIR)*.l)

TOKWRAP_DIR  = ../DTA-TokWrap
TOKWRAP_SRC  = $(TOKWRAP_DIR)/dta-tokwrap.perl
#TOKWRAP      = $(PERL) -Mlib=$(TOKWRAP_DIR)/blib/lib $(TOKWRAP_DIR)/blib/script/dta-tokwrap.perl $(TOKWRAP_OPTS)
TOKWRAP      = ./dta-tokwrap.perl $(TOKWRAP_OPTS)
TOKWRAP_DEPS = $(TOKWRAP_SRC)

else

XSL_DIR = /usr/local/share/dta-tokwrap/stylesheets

PROG_DEPS =
PROG_DIR  =

TOKWRAP      =dta-tokwrap.perl $(TOKWRAP_OPTS)
TOKWRAP_DEPS =

endif

##--------------------------------------------------------------
## Configuration: Defaults: archiving & distribution

ARC_TARGETS ?= \
	Makefile \
	User.mak \
	$(config) \
	$(logfile) \
	$(XML:.xml=.t.xml) \
	$(XML:.xml=.s.xml) \
	$(XML:.xml=.w.xml) \
	$(XML:.xml=.a.xml)

##--------------------------------------------------------------
## Configuration: Defaults: cleanup

CLEAN_DEPS ?=
CLEAN_FILES ?=

REALCLEAN_DEPS += clean
REALCLEAN_FILES += \
	$(filter-out $(xml),$(XML)) \



##======================================================================
## Rules: top-level

all: t-xml s-xml w-xml a-xml

.SECONDARY: 

##======================================================================
## Rules: show configuration

config:
	@echo "inplace=$(inplace)"
	@echo "dummytok=$(dummytok)"
	@echo "TOKWRAP=$(TOKWRAP)"
	@echo "xmldir=$(xmldir)"
	@echo "xml=$(xml)"
	@echo "XML=$(XML)"

##======================================================================
## Rules: link in sources (don't rely on this!)

#$(XML): xml
xml: $(xml)
	rm -f $(filter-out $(xml),$(XML))
	ln -s $^ .

no-xml:
	test -z "$(filter-out $(xml),$(XML))" || rm -f $(filter-out $(xml),$(XML))
	rm -f xml.stamp

REALCLEAN_DEPS += no-xml

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
## Rules: mkindex: xml -> xx=(cx,sx,tx)

xx: cx sx tx

cx: $(XML:.xml=.cx)
sx: $(XML:.xml=.sx)
tx: $(XML:.xml=.tx)

no-cx: ; rm -f $(XML:.xml=.cx)
no-sx: ; rm -f $(XML:.xml=.sx)
no-tx: ; rm -f $(XML:.xml=.tx)

no-xx: no-cx no-sx no-tx

##-- xml -> (cx,sx,tx): individual rule
%.xx: %.cx %.sx %.tx
%.cx: %.cx %.sx %.tx
%.sx: %.cx %.sx %.tx
%.tx: %.cx %.sx %.tx

%.cx %.sx %.tx: $(xmldir)/%.xml tokwrap
ifeq "$(TOKWRAP_ALL)" "yes"
	$(TOKWRAP) -t mkindex $<
else
	$(PROG_DIR)dtatw-mkindex $< $*.cx $*.sx $*.tx
endif


CLEAN_FILES += *.cx *.sx *.tx *.xx

##-- aliases for debugging
sx-fmt: $(XML:.xml=.sx.fmt)
no-sx-fmt: ; rm -f *.sx.fmt

sx-nons: $(XML:.xml=.sx.nons)
no-sx-nons: ; rm -f *.sx.nons *.sx.nons.fmt

sx-nons-fmt: $(XML:.xml=.sx.nons.fmt)
no-sx-nons-fmt: ; rm -f *.sx.nons.fmt
CLEAN_FILES += *.sx.nons *.sx.fmt *.sx.nons.fmt *.sx.fmt.nons

##======================================================================
## Rules: serialization (serialized block index: bx0)

bx0: $(XML:.xml=.bx0)
%.bx0: %.sx tokwrap
	$(TOKWRAP) -t mkbx0 $(xmldir)/$*.xml

no-bx0: ; rm -f *.bx0 bx0.stamp
CLEAN_FILES += *.bx0 bx0.stamp

##======================================================================
## Rules: serialized text + index (bx, txt)

serialize: txt

bx: bx-txt
txt: bx-txt
bx-txt: $(XML:.xml=.bx)

%.bx:  %.bx %.txt
%.txt: %.bx %.txt

%.bx: %.bx0 %.tx tokwrap
	$(TOKWRAP) -t mktxt $(xmldir)/$*.xml

%.txt: %.bx0 %.tx tokwrap
	$(TOKWRAP) -t mktxt $(xmldir)/$*.xml

no-bx-txt: ; rm -f *.bx *.txt
no-bx: no-bx-txt
no-txt: no-bx-txt
CLEAN_FILES += *.bx *.txt

##======================================================================
## Rules: tokenization

t: $(XML:.xml=.t)
%.t: %.txt tokwrap
ifeq "$(TOKENIZER)" ""
	$(TOKWRAP) -t tokenize $(xmldir)/$*.xml
else
	$(TOKENIZER) $< > $@ || (rm -f $@; false)
endif

no-t: ; rm -f *.t
CLEAN_FILES += *.t

##======================================================================
## Rules: tokenized: master xml output

##-- CONTINUE HERE (problem: implicit pattern rule .xml -> link-to-srcdir) !

t-xml: $(XML:.xml=.t.xml)

%.t.xml: %.t %.cx %.bx tokwrap
ifeq "$(TOKWRAP_ALL)" "yes"
	$(TOKWRAP) -t tok2xml $(xmldir)/$*.xml
else
	$(PROG_DIR)dtatw-tok2xml $< $*.cx $*.bx $@ $*.xml
endif

no-t-xml: ; rm -f *.t.xml
CLEAN_FILES += *.t.xml

##======================================================================
## Rules: tokenized: xml-t: master xml output -> .tt

%.t.xml.t: $(XSL_DIR)/dtatw-txml2tt.xsl %.t.xml
#	xsltproc --param sids 1 --param wids 1 --param wlocs 1 -o "$@" $^
	xsltproc --param sids 1 --param wids 0 --param wlocs 0 -o "$@" $^

xml-t: $(XML:.xml=.t.xml.t)

no-xml-t: ; rm -f *.t.xml.t

CLEAN_FILES += *.t.xml.t

##======================================================================
## Rules: standoff (via C utilities)

##--------------------------------------------------------------
## standoff: top-level
standoff: s-xml w-xml a-xml
no-standoff: no-s-xml no-w-xml no-a-xml

%-standoff: %.s.xml %.w.xml %.a.xml

##--------------------------------------------------------------
## standoff: .s.xml
s-xml: $(XML:.xml=.s.xml)

%.s.xml: %.t.xml tokwrap
ifeq "$(TOKWRAP_ALL)" "yes"
	$(TOKWRAP) -t sosxml $(xmldir)/$*.xml
else
	$(PROG_DIR)dtatw-txml2sxml $< $@ $*.w.xml
endif

no-s-xml: ; rm -f *.s.xml
CLEAN_FILES += *.s.xml

##--------------------------------------------------------------
## standoff: .w.xml
w-xml: $(XML:.xml=.w.xml)

%.w.xml: %.t.xml tokwrap
ifeq "$(TOKWRAP_ALL)" "yes"
	$(TOKWRAP) -t sowxml $(xmldir)/$*.xml
else
	$(PROG_DIR)dtatw-txml2wxml $< $@ $*.xml
endif

no-w-xml: ; rm -f *.w.xml
CLEAN_FILES += *.w.xml

##--------------------------------------------------------------
## standoff: .a.xml
a-xml: $(XML:.xml=.a.xml)
%.a.xml: %.t.xml tokwrap
ifeq "$(TOKWRAP_ALL)" "yes"
	$(TOKWRAP) -t soaxml $(xmldir)/$*.xml
else
	$(PROG_DIR)dtatw-txml2axml $< $@ $*.w.xml
endif

no-a-xml: ; rm -f *.a.xml
CLEAN_FILES += *.a.xml


##======================================================================
## Rules: archiving

arc: $(arcfile)

arcdir: $(ARC_TARGETS) $(xml)
	rm -rf $(arcname)
	mkdir $(arcname)
	mkdir $(arcname)/data
	for f in $(ARC_TARGETS); do \
	  test -e $(arcname)/data/$$f || ln `readlink -f $$f` $(arcname)/data/`basename $$f`; \
	done
	if test "$(arc_want_sources)" = "yes"; then \
	  mkdir $(arcname)/sources; \
	  for f in $(xml); do \
	    ln `readlink -f $$f` $(arcname)/sources/`basename $$f` ; \
	  done; \
	fi

no-arcdir:
	rm -rd $(arcname)

$(arcfile): arcdir
	rm -rf $(arcfile)
	GZIP="$(arc_gzip)" tar cvzf $@ $(arcname)
	@echo "Created archive $@"

no-arc: no-arcdir
	rm -f $(arcfile)

##======================================================================
## Rules: utility programs (inplace="yes" only!)

programs: $(PROG_DEPS)
ifeq "$(inplace)" "yes"
	$(MAKE) -C "$(PROG_DIR)" all
else
	true
endif

##======================================================================
## Rules: perl module (inplace="yes" only!)

##--
ifeq "$(inplace)" "yes"

#tokwrap: programs pm
tokwrap: programs

pm: $(TOKWRAP_DIR)/Makefile
	$(MAKE) -C $(TOKWRAP_DIR)

$(TOKWRAP_DIR)/Makefile: $(TOKWRAP_DIR)/Makefile.PL
	(cd $(TOKWRAP_DIR); $(PERL) Makefile.PL)

else
##-- ifeq "$(inplace)" "yes": else

tokwrap:
	true

pm:
	true

endif
##-- ifeq "$(inplace)" "yes": endif


##======================================================================
## Rules: cleanup

no-log: nolog
nolog: ; rm -f *.log
REALCLEAN_FILES += *.log

clean: $(CLEAN_DEPS)
	rm -f $(CLEAN_FILES)

realclean: $(REALCLEAN_DEPS)
	rm -f $(REALCLEAN_FILES)
