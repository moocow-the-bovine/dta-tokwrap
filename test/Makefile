XML_TXT   = ex2.txt.xml
XML_TXTLB = test-raw.txt+lb.xml $(XML_TXT:.txt.xml=.txt+lb.xml)
XML_CHR   = test1.chr.xml test-3k.chr.xml ex1.chr.xml $(XML_TXTLB:.txt+lb.xml=.chr.xml)

##-- test robustness via `make -k`
#XML_CHR += NOT_HERE.chr.xml

XML = $(XML_CHR)
#XML = test1.chr.xml test-3k.chr.xml

PERL ?=perl

TARGETS = $(XML) t-xml standoff

##======================================================================
## Variables: scripts

## XSL_DIR
##  + directory containing miscellaneous XSL scripts
XSL_DIR ?= ../scripts

## SCRIPTS_DIR
##  + directory containing miscellaneous perl scripts
SCRIPTS_DIR ?= ../scripts

##======================================================================
## Variables: tokwrap

## TOKWRAP_OPTS
##  + options for dta-tokwrap.perl
#TOKWRAP_OPTS ?= -keep -log-level=INFO
#TOKWRAP_OPTS ?= -keep -log-level=TRACE -traceOpen
#TOKWRAP_OPTS ?= -keep -trace -notraceProc
#TOKWRAP_OPTS ?= -keep -trace
#TOKWRAP_OPTS ?= -keep -q
#TOKWRAP_OPTS ?= -keep -v 1 -noprofile
TOKWRAP_OPTS ?= -keep -v 1

TOKENIZER ?= $(PROGDIR)dtatw-tokenize-dummy

##======================================================================
## Variables: in-place execution (use local development code, or don't)

## INPLACE
##  + set to something other than "yes" to avoid using local code ../src and ../DTA-TokWrap
INPLACE ?= yes

CSRC_DIR=../src
CSRC_PROGRAMS = $(patsubst %,../src/%,\
	dtatw-mkindex dtatw-rm-namespaces dtatw-tokenize-dummy \
	dtatw-txml2wxml dtatw-txml2sxml dtatw-txml2axml \
	)
TOKWRAP_DIR=../DTA-TokWrap

ifeq "$(INPLACE)" "yes"

CSRC_DEPS=programs
PROGDIR=$(CSRC_DIR)/

TOKWRAP=$(PERL) -Mlib=$(TOKWRAP_DIR)/blib/lib $(TOKWRAP_DIR)/blib/script/dta-tokwrap.perl -i $(TOKWRAP_OPTS)
TOKWRAP_DEPS=pm


PREPEND_TARGETS = programs pm

else

CSRC_DEPS=
PROGDIR=

TOKWRAP=$(shell which dta-tokwrap.perl) $(TOKWRAP_OPTS)
TOKWRAP_DEPS=

endif

##======================================================================
## Variables: archiving & distribution

ARC_DIR  ?=.
ARC_NAME ?=dta-tokwrap-data.$(shell date +"%Y-%m-%d").$(shell hostname -s)
ARC_TARGETS ?= \
	Makefile \
	$(XML) \
	$(XML:.xml=.t.xml) \
	$(XML:.xml=.s.xml) \
	$(XML:.xml=.w.xml) \
	$(XML:.xml=.a.xml)
ARC_FILE = $(ARC_DIR)/$(ARC_NAME).tar.gz


##======================================================================
## Rules: top-level

all: $(PREPEND_TARGETS) $(TARGETS)

.SECONDARY: 

##======================================================================
## Rules: programs

programs: $(CSRC_PROGRAMS)

$(CSRC_DIR)/dtatw-mkindex: $(CSRC_DIR)/dtatw-mkindex.c
$(CSRC_DIR)/dtatw-rm-namespaces: $(CSRC_DIR)/dtatw-rm-namespaces.c
$(CSRC_DIR)/dtatw-tokenize-dummy: $(CSRC_DIR)/dtatw-tokenize-dummy.l

$(CSRC_DIR)/%:
	$(MAKE) -C $(CSRC_DIR) "$*"

##======================================================================
## Rules: perl module

pm: $(TOKWRAP_DIR)/Makefile
	$(MAKE) -C $(TOKWRAP_DIR)

$(TOKWRAP_DIR)/Makefile: $(TOKWRAP_DIR)/Makefile.PL
	(cd $(TOKWRAP_DIR); $(PERL) Makefile.PL)

ifeq "$(INPLACE)" "yes"
$(TOKWRAP): $(CSRC_DEPS) $(TOKWRAP_DEPS)
endif

tokwrap: $(TOKWRAP)

##======================================================================
## Rules: show configuration

config:
	@echo "INPLACE=$(INPLACE)"
	@echo "TOKWRAP=$(TOKWRAP)"
	@echo "TOKWRAP_DEPS=$(TOKWRAP_DEPS)"

##======================================================================
## Rules: XML preprocessing: add linebreaks

%.txt+lb.xml: ../scripts/dtatw-add-lb.xsl %.txt.xml
	xsltproc -o "$@" $^
txt+lb: lb
lb: $(XML_TXT:.txt.xml=.txt+lb.xml)
no-lb: ; rm -f $(XML_TXT:.txt.xml=.txt+lb.xml)
REALCLEAN_FILES += $(XML_TXT:.txt.xml=.txt+lb.xml)

##======================================================================
## Rules: XML preprocessing: add <c> elements

%.chr.xml: %.txt+lb.xml ../scripts/dtatw-add-c.perl
	../scripts/dtatw-add-c.perl $< -o $@
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
## Rules: mkindex: xml -> xx=(cx,sx,tx)

xx: cx sx tx

cx: $(XML:.xml=.cx)
sx: $(XML:.xml=.sx)
tx: $(XML:.xml=.tx)
no-cx: ; rm -f $(XML:.xml=.cx)
no-sx: ; rm -f $(XML:.xml=.sx)
no-tx: ; rm -f $(XML:.xml=.tx)
no-xx: no-cx no-sx no-tx ; rm -f *.xx xx.stamp

##-- xml -> (cx,sx,tx): batch rule
xx.stamp: $(XML) $(TOKWRAP_DEPS)
	$(TOKWRAP) -t mkindex $(XML)
	touch $@

##-- xml -> (cx,sx,tx): individual rule
#%.xx: ; $(MAKE) $*.cx $*.sx $*.tx
%.xx: %.cx %.sx %.tx
%.cx: %.cx %.sx %.tx
%.sx: %.cx %.sx %.tx
%.tx: %.cx %.sx %.tx
%.cx %.sx %.tx: %.xml $(TOKWRAP_DEPS) $(CSRC_DEPS)
#	$(TOKWRAP) -t mkindex $<
	$(PROGDIR)dtatw-mkindex $< $*.cx $*.sx $*.tx
CLEAN_FILES += *.cx *.sx *.tx *.xx *.stamp

sx-fmt: $(XML:.xml=.sx.fmt)
no-sx-fmt: ; rm -f *.sx.fmt

sx-nons: $(XML:.xml=.sx.nons)
no-sx-nons: ; rm -f *.sx.nons *.sx.nons.fmt

sx-nons-fmt: $(XML:.xml=.sx.nons.fmt)
no-sx-nons-fmt: ; rm -f *.sx.nons.fmt
CLEAN_FILES += *.sx.nons *.sx.fmt *.sx.nons.fmt *.sx.fmt.nons

##======================================================================
## Rules: serialization (serialized block index: bx0)

bx0: bx0-iter
#bx0: bx0.stamp

bx0.stamp: xx.stamp $(TOKWRAP_DEPS)
	$(TOKWRAP) -t bx0 $(XML)
	touch $@

bx0-iter: $(XML:.xml=.bx0)
%.bx0: %.sx $(TOKWRAP_DEPS)
	$(TOKWRAP) -t mkbx0 $*.xml

no-bx0: ; rm -f *.bx0 bx0.stamp
CLEAN_FILES += *.bx0 bx0.stamp

##======================================================================
## Rules: serialized text + index (bx, txt)

serialize: txt

bx: bx-iter
txt: txt-iter
#bx: bx.stamp
#txt: txt.stamp

bx.stamp: bx0.stamp $(TOKWRAP_DEPS)
	$(TOKWRAP) -t bx $(XML)
	touch $@

txt.stamp: bx.stamp
	touch $@

bx-iter: $(XML:.xml=.bx)
txt-iter: $(XML:.xml=.txt)

%.bx:  %.bx %.txt
%.txt: %.bx %.txt

%.bx: %.bx0 %.tx $(TOKWRAP_DEPS)
	$(TOKWRAP) -t bx $*.xml
%.txt: %.bx0 %.tx $(TOKWRAP_DEPS)
	$(TOKWRAP) -t bx $*.xml

no-bx: ; rm -f *.bx bx.stamp *.txt txt.stamp
no-txt: no-bx
CLEAN_FILES += *.bx *.txt bx.stamp txt.stamp

##======================================================================
## Rules: tokenization: dummy, via flex for speed: .t

#tt: t

t: t-iter
#t: t.stamp

t.stamp: txt.stamp $(TOKWRAP_DEPS)
	$(TOKWRAP) -t tokenize $(XML)
	touch $@

t-iter: $(XML:.xml=.t)
%.t: %.txt $(TOKWRAP_DEPS) $(CSRC_DEPS)
#	$(TOKWRAP) -t tokenize $*.xml
	$(TOKENIZER) $< $@

no-t: ; rm -f *.t t.stamp
CLEAN_FILES += *.t t.stamp

##======================================================================
## Rules: tokenized: master xml output

tokd-xml: t-xml
tt-xml: t-xml

t-xml: t-xml-iter
#t-xml: t-xml.stamp

t-xml.stamp: t.stamp $(TOKWRAP_DEPS)
	$(TOKWRAP) -t tok2xml $(XML)
	touch $@

t-xml-iter: $(XML:.xml=.t.xml)
%.t.xml: %.t %.bx %.cx $(TOKWRAP_DEPS) $(CSRC_DEPS)
	$(TOKWRAP) -t tok2xml $*.xml

no-t-xml: ; rm -f *.t.xml t-xml.stamp
no-tokd-xml: no-t-xml
no-tt-xml: no-t-xml
CLEAN_FILES += *.t.xml t-xml.stamp

##======================================================================
## Rules: tokenized: xml-t: master xml output -> .tt

%.t.xml.t: $(XSL_DIR)/dtatw-txml2tt.xsl %.t.xml
	xsltproc --param locations 0 -o "$@" $^
xml-t: $(XML:.xml=.t.xml.t)
no-xml-t: ; rm -f *.t.xml.t
CLEAN_FILES += *.t.xml.t

##======================================================================
## Rules: standoff (via xsl)

##-- standoff: top-level
standoff: standoff-iter
#standoff: standoff.stamp

standoff-iter: s-xml-iter w-xml-iter a-xml-iter

standoff.stamp: t-xml.stamp $(TOKWRAP_DEPS)
	$(TOKWRAP) -t standoff $(XML)
	touch $@

no-standoff: no-s-xml no-w-xml no-a-xml ; rm -f standoff.stamp
%-standoff:
	$(MAKE) $*.s.xml $*.w.xml $*.a.xml

##-- standoff: xsl (workaround for broken `dta-tokwrap.perl -t so*xml` with `make -j2`)
standoff-xsl:
	$(MAKE) standoff_t2s.xsl standoff_t2w.xsl standoff_t2a.xsl

standoff_t2s.xsl standoff_t2w.xsl standoff_t2a.xsl: $(TOKWRAP_DEPS)
	$(TOKWRAP) -dump-xsl= -

no-standoff-xsl: ; rm -f standoff_t2[swa].xsl
no-xsl: ; rm -f *.xsl
CLEAN_FILES += standoff_t2[swa].xsl mkbx0_*.xsl

##-- standoff: .s.xml
s-xml: s-xml-iter
#s-xml: s-xml.stamp

s-xml.stamp: t-xml.stamp $(TOKWRAP_DEPS)
	$(TOKWRAP) -t sosxml $(XML)
	touch $@

s-xml-iter: $(XML:.xml=.s.xml)
#%.s.xml: %.t.xml $(TOKWRAP_DEPS)
#	##-- BROKEN with `make -j2`: race condition?
#	$(TOKWRAP) -t sosxml $*.xml
##--
#%.s.xml: standoff_t2s.xsl %.t.xml
#	xsltproc -o $@ $^
##--
%.s.xml: %.t.xml $(CSRC_DEPS)
	$(PROGDIR)dtatw-txml2sxml $< $@ $*.w.xml


no-s-xml: ; rm -f *.s.xml s-xml.stamp
CLEAN_FILES += *.s.xml s-xml.stamp

##-- standoff: .w.xml
w-xml: w-xml-iter
#w-xml: w-xml.stamp

w-xml.stamp: t-xml.stamp $(TOKWRAP_DEPS)
	$(TOKWRAP) -t sowxml $(XML)
	touch $@

w-xml-iter: $(XML:.xml=.w.xml)
#%.w.xml: %.t.xml $(TOKWRAP_DEPS)
#	##-- BROKEN with `make -j2`: race condition?
#	$(TOKWRAP) -t sowxml $*.xml
##--
#%.w.xml: standoff_t2w.xsl %.t.xml
#	xsltproc -o $@ $^
##--
%.w.xml: %.t.xml $(CSRC_DEPS)
	$(PROGDIR)dtatw-txml2wxml $< $@ $*.xml


no-w-xml: ; rm -f *.w.xml w-xml.stamp
CLEAN_FILES += *.w.xml w-xml.stamp

##-- standoff: .a.xml
a-xml: a-xml-iter
#a-xml: a-xml.stamp

a-xml.stamp: t-xml.stamp $(TOKWRAP_DEPS)
	$(TOKWRAP) -t soaxml $(XML)
	touch $@

a-xml-iter: $(XML:.xml=.a.xml)
#%.a.xml: %.t.xml $(TOKWRAP_DEPS)
#	##-- BROKEN with `make -j2`: race condition?
#	$(TOKWRAP) -t soaxml $*.xml
##--
#%.a.xml: standoff_t2a.xsl %.t.xml
#	xsltproc -o $@ $^
##--
%.a.xml: %.t.xml $(CSRC_DEPS)
	$(PROGDIR)dtatw-txml2axml $< $@ $*.w.xml

no-a-xml: ; rm -f *.a.xml a-xml.stamp
CLEAN_FILES += *.a.xml a-xml.stamp

##-- running time summary / ex1 (kraepelin) / uhura: scripts
## mkindex      : xml -> cx,sx,tx   1.2s  ~  75.9 Ktok/sec ~ 502.3 Kchr/sec
## mkbx0        : sx -> bx0         0.11s ~ 842.8 Ktok/sec ~   5.6 Mchr/sec
## mkbx         : bx0 -> txt        0.30s ~ 303.4 Ktok/sec ~   2.0 Mchr/sec
## tokenize     : txt -> t          0.08s ~   1.1 Mtok/sec ~   7.5 Mchr/sec
## tok2xml/perl : t -> t.xml       13.13s ~   6.9 Ktok/sec ~  45.9 Kchr/sec  *** SLOW (perl) ***
## sosxml/xsl   : t.xml -> s.xml    1.79s ~  59.8 Ktok/sec ~ 336.8 Kchr/sec
## sowxml/xsl   : t.xml -> w.xml    8.62s ~  10.6 Ktok/sec ~  70.0 Kchr/sec  *** SLOW (xsl) ***
## soaxml/xsl   : t.xml -> a.xml    2.08s ~  43.8 Ktok/sec ~ 289.8 Kchr/sec
## TOTAL                            27.3s ~   3.3 Ktok/sec ~  22.1 Kchr/sec

##-- /carrot: via dta-tokwrap
#  mkindex:    1 doc,  90.6 Ktok,  15.6 Mbyte in   1.4  sec:  63.6 Ktok/sec ~  10.9 Mbyte/sec
#    mkbx0:    1 doc,  90.6 Ktok,  15.6 Mbyte in 105.9 msec: 854.9 Ktok/sec ~ 147.0 Mbyte/sec
#     mkbx:    1 doc,  90.6 Ktok,  15.6 Mbyte in 190.5 msec: 475.4 Ktok/sec ~  81.8 Mbyte/sec
# tokenize:    1 doc,  90.6 Ktok,  15.6 Mbyte in  87.9 msec:   1.0 Mtok/sec ~ 177.1 Mbyte/sec
#  tok2xml:    1 doc,  90.6 Ktok,  15.6 Mbyte in   5.4  sec:  16.8 Ktok/sec ~   2.9 Mbyte/sec
#   sosxml:    1 doc,  90.6 Ktok,  15.6 Mbyte in 380.0 msec: 238.3 Ktok/sec ~  41.0 Mbyte/sec
#   sowxml:    1 doc,  90.6 Ktok,  15.6 Mbyte in 694.3 msec: 130.4 Ktok/sec ~  22.4 Mbyte/sec
#   soaxml:    1 doc,  90.6 Ktok,  15.6 Mbyte in 383.0 msec: 236.5 Ktok/sec ~  40.7 Mbyte/sec
#    TOTAL:    1 doc,  90.6 Ktok,  15.6 Mbyte in  12.5  sec:   7.2 Ktok/sec ~   1.2 Mbyte/sec


##-- carrot, Sun, 03 May 2009 23:12:46 +0200
## tok2xml/perl   :  1 doc,  90.6 Ktok,  15.6 Mbyte in   5.4  sec:  16.8 Ktok/sec ~   2.9 Mbyte/sec
## tok2xml/c-pre1 :  1 doc,  90.6 Ktok,  15.6 Mbyte in 688.0 msec: 223.2 Ktok/sec ~  38.5 Mbyte/sec

##-- carrot, Sun, 03 May 2009 23:12:51 +0200
# sosxml/c:    1 doc,  90.6 Ktok,  15.6 Mbyte in 380.0 msec: 238.3 Ktok/sec ~  41.0 Mbyte/sec
# sowxml/c:    1 doc,  90.6 Ktok,  15.6 Mbyte in 694.3 msec: 130.4 Ktok/sec ~  22.4 Mbyte/sec
# soaxml/c:    1 doc,  90.6 Ktok,  15.6 Mbyte in 383.0 msec: 236.5 Ktok/sec ~  40.7 Mbyte/sec


##======================================================================
## Rules: full processing pipeline

tw-all: tw-all-iter
#tw-all: tw-all.stamp

tw-all-iter: t-xml-iter standoff-iter

tw-all.stamp: $(XML) $(TOKWRAP_DEPS)
	$(TOKWRAP) -t all $(XML)
	touch $@
CLEAN_FILES += tw-all.stamp

##-- iter vs. all
## + time make -j2 standoff-iter ~ 971.9 Kbyte/sec
##	real	0m28.879s
##	user	0m45.739s
##	sys	0m1.776s
## + time make TOKWRAP_OPTS="-keep -trace" tw-all ~ 784.5 Kbyte/sec
##	real	0m35.778s
##	user	0m34.778s
##	sys	0m0.984s
## + time make -j1 standoff-iter ~ 609.4 Kbyte/sec
##	real	0m46.060s
##	user	0m44.351s
##	sys	0m1.636s


##======================================================================
## Rules: archiving

arc: $(ARC_FILE)
no-arc: ; rm -f $(ARC_FILE)
$(ARC_FILE): $(ARC_TARGETS)
	rm -rf $(ARC_NAME) $(ARC_FILE)
	mkdir $(ARC_NAME)
	for f in $(ARC_TARGETS); do \
	  ln $$f $(ARC_NAME)/$$f; \
	done
	tar czf $@ $(ARC_NAME)
	rm -rf $(ARC_NAME)


##======================================================================
## Rules: cleanup
clean:
	rm -f $(CLEAN_FILES)

realclean: clean
	rm -f $(REALCLEAN_FILES)
