CC = gcc
LD = $(CC)

CPPFLAGS ?=
CFLAGS ?= -Wall -O2 -pipe
#CFLAGS ?= -Wall -g
LDFLAGS ?=
LIBS ?= -lexpat

TARGETS = dta-tokwrap-mkindex xml-no-namespaces dta-tokenize-dummy
#dta-tokwrap-mkindex2
#xmlparse-noop
#dta-tokwrap-textindex
#dta-tokwrap-lschars

##======================================================================
## Variables: cleanup

CLEAN_FILES = $(TARGETS) *.o
REALCLEAN_FILES =

##======================================================================
## Rules: Top-Level
all: $(TARGETS)

##======================================================================
## Rules: Linking

dta-tokwrap-mkindex: dta-tokwrap-mkindex.o
	$(LD) $(LDFLAGS) -o $@ $^ $(LIBS)

dta-tokwrap-mkindex2: dta-tokwrap-mkindex2.o
	$(LD) $(LDFLAGS) -o $@ $^ $(LIBS)

xmlparse-noop: xmlparse-noop.o
	$(LD) $(LDFLAGS) -o $@ $^ $(LIBS)

xml-no-namespaces: xml-no-namespaces.o
	$(LD) $(LDFLAGS) -o $@ $^ $(LIBS)

dta-tokenize-dummy: dta-tokenize-dummy.o
	$(LD) $(LDFLAGS) -o $@ $^ $(LIBS) -lfl

##======================================================================
## Rules: Compling
%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c -o $@ $<

##======================================================================
## Rules: Dummy tokenizer

dta-tokenize-dummy.c: dta-tokenize-dummy.l
	flex -8 $<

##======================================================================
## Rules: formatting

%.fmt: %
	xmllint --format -o $@ $<
CLEAN_FILES += *.fmt

##======================================================================
## Rules: test

XML_SOURCES ?= test-raw.chr.xml test1.xml ex1.xml ex2.xml

.SECONDARY:

%.chr.xml: %.xml ../dta-tokwrap-addchr.perl
	../dta-tokwrap-addchr.perl $< > $@ || (rm -f $@; false)

%.cx: %.cx %.sx %.tx
%.sx: %.cx %.sx %.tx
%.tx: %.cx %.sx %.tx
%.cx %.sx %.tx: %.xml dta-tokwrap-mkindex
	./dta-tokwrap-mkindex $< $*.cx $*.sx $*.tx
CLEAN_FILES += *.cx *.sx *.tx

cx: $(XML_SOURCES:.xml=.cx)
sx: $(XML_SOURCES:.xml=.sx)
tx: $(XML_SOURCES:.xml=.tx)
xx: cx sx tx

no-cx: ; rm -f *.cx
no-sx: ; rm -f *.sx
no-tx: ; rm -f *.tx
no-xx: no-cx no-sx no-tx

##-- debugging
sx-fmt: $(XML_SOURCES:.xml=.sx.fmt)
stx: $(XML_SOURCES:.xml=.stx)
no-stx: ; rm -f *.stx
CLEAN_FILES += *.stx

%.stx: %.sx.nons %.tx sx-insert-tx.perl
	./sx-insert-tx.perl "$*.sx.nons" "$*.tx" -f 1 > $@ || (rm -f $@; false)

##-- namespace removal
sx-nons: $(XML_SOURCES:.xml=.sx.nons)
%.nons: % xml-no-namespaces
	./xml-no-namespaces $< $@
no-sx-nons:  ; rm -f *.nons
sx-nons-fmt: $(XML_SOURCES:.xml=.sx.nons.fmt)
CLEAN_FILES += *.nons

##-- serialization (block index), v2
%.bx0: %.sx ./xml-no-namespaces insert-implicit-breaks.xsl mark-sortkeys.xsl
	./xml-no-namespaces $< \
	 | xsltproc insert-implicit-breaks.xsl - \
	 | xsltproc mark-sortkeys.xsl - \
	 | xmllint --format - \
	 > $@ || (rm -f $@; false)
bx0: $(XML_SOURCES:.xml=.bx0)
no-bx0: ; rm -f *.bx0
CLEAN_FILES += *.bx0

##-- serialization + txt
%.bx:  %.bx %.txt
%.txt: %.bx %.txt
%.bx %.txt: %.bx0 %.tx dta-tokwrap-lsblocks.perl
	./dta-tokwrap-lsblocks.perl "$*.bx0" "$*.tx" "$*.bx" "$*.txt"
bx: $(XML_SOURCES:.xml=.bx)
txt: $(XML_SOURCES:.xml=.txt)
no-bx: ; rm -f *.bx0 *.bx
no-txt: ; rm -f *.txt
CLEAN_FILES += *.bx

##-- tokenization (dummy, via flex for speed)
%.tokd: %.txt dta-tokenize-dummy
	./dta-tokenize-dummy < "$<" > "$@" || (rm -f "$@"; false)
tokd: $(XML_SOURCES:.xml=.tokd)
no-tokd: ; rm -f *.tokd
CLEAN_FILES += *.tokd

##-- tokenizer master xml output (slowest step so far: 7.25 Ktok/sec ~ 47.0 Kchr/sec ~ 13sec for ex1 (kraepelin))
%.t.xml: %.tokd %.bx %.cx dta-tokwrap-tt2xml.perl
	./dta-tokwrap-tt2xml.perl "$*.tokd" "$*.bx" "$*.cx" -f -o "$@"
tokd-xml: $(XML_SOURCES:.xml=.t.xml)
no-tokd-xml: ; rm -f *.t.xml
t-xml: tokd-xml
no-t-xml: no-tokd-xml
tt-xml: t-xml
no-tt-xml: no-t-xml
CLEAN_FILES += *.t.xml

##-- standoff (via xsl)
standoff: s-xml w-xml a-xml
no-standoff: no-s-xml no-w-xml no-a-xml
%-standoff:
	$(MAKE) $*.s.xml $*.w.xml $*.a.xml

%.s.xml: dta-tokwrap-ttxml2sxml.xsl %.t.xml
	xsltproc --stringparam xmlbase "$*.w.xml" -o "$@" $^
s-xml: $(XML_SOURCES:.xml=.s.xml)
no-s-xml: ; rm -f *.s.xml
CLEAN_FILES += *.s.xml

%.w.xml: dta-tokwrap-ttxml2wxml.xsl %.t.xml
	xsltproc --stringparam xmlbase "$*.xml" -o "$@" $^
w-xml: $(XML_SOURCES:.xml=.w.xml)
no-w-xml: ; rm -f *.w.xml
CLEAN_FILES += *.w.xml

%.a.xml: dta-tokwrap-ttxml2axml.xsl %.t.xml
	xsltproc --stringparam xmlbase "$*.w.xml" -o "$@" $^
a-xml: $(XML_SOURCES:.xml=.a.xml)
no-a-xml: ; rm -f *.a.xml
CLEAN_FILES += *.a.xml

##-- running time summary / ex1 (kraepelin) / uhura
## xml -> cx,sx,tx   1.2s  ~  75.9 Ktok/sec ~ 502.3 Kchr/sec
## sx -> bx0         0.11s ~ 842.8 Ktok/sec ~   5.6 Mchr/sec
## bx0 -> txt        0.30s ~ 303.4 Ktok/sec ~   2.0 Mchr/sec
## txt -> tokd       0.08s ~   1.1 Mtok/sec ~   7.5 Mchr/sec
## tokd -> t.xml    13.13s ~   6.9 Ktok/sec ~  45.9 Kchr/sec  *** SLOW (perl) ***
## t.xml -> s.xml    1.79s ~  59.8 Ktok/sec ~ 336.8 Kchr/sec
## t.xml -> w.xml    8.62s ~  10.6 Ktok/sec ~  70.0 Kchr/sec  *** SLOW (xsl) ***
## t.xml -> a.xml    2.08s ~  43.8 Ktok/sec ~ 289.8 Kchr/sec
## TOTAL            27.31s ~   3.3 Ktok/sec ~  22.1 Kchr/sec

##======================================================================
## Rules: Clean
clean:
	test -z "$(CLEAN_FILES)" || rm -f $(CLEAN_FILES)

realclean: clean
	test -z "$(REALCLEAN_FILES)" || rm -f $(REALCLEAN_FILES)
