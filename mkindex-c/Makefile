CC = gcc
LD = $(CC)

CPPFLAGS ?=
CFLAGS ?= -Wall -O2 -pipe
LDFLAGS ?=
LIBS ?= -lexpat

TARGETS = dta-tokwrap-mkindex dta-tokwrap-mkindex2 xml-no-namespaces
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

##======================================================================
## Rules: Compling
%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c -o $@ $<

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

%.cx2: %.cx2 %.sx2 %.tx2
%.sx2: %.cx2 %.sx2 %.tx2
%.tx2: %.cx2 %.sx2 %.tx2
%.cx2 %.sx2 %.tx2: %.xml dta-tokwrap-mkindex2
	./dta-tokwrap-mkindex2 $< $*.cx2 $*.sx2 $*.tx2
CLEAN_FILES += *.cx2 *.sx2 *.tx2

cx: $(XML_SOURCES:.xml=.cx)
sx: $(XML_SOURCES:.xml=.sx)
tx: $(XML_SOURCES:.xml=.tx)
xx: cx sx tx

no-cx: ; rm -f *.cx *.cx2
no-sx: ; rm -f *.sx *.sx2
no-tx: ; rm -f *.tx *.tx2
no-xx: no-cx no-sx no-tx

##--
cx2: $(XML_SOURCES:.xml=.cx2)
sx2: $(XML_SOURCES:.xml=.sx2)
tx2: $(XML_SOURCES:.xml=.tx2)
xx2: cx2 sx2 tx2

sx2-fmt: $(XML_SOURCES:.xml=.sx2.fmt)

no-cx2: no-cx
no-sx2: no-sx
no-tx2: no-tx
no-xx2: no-xx


##-- namespace removal

sx2-nons: $(XML_SOURCES:.xml=.sx2.nons)
%.nons: % xml-no-namespaces
	./xml-no-namespaces $< $@
no-sx2-nons:  ; rm -f *.nons
sx2-nons-fmt: $(XML_SOURCES:.xml=.sx2.nons.fmt)
CLEAN_FILES += *.nons

##-- Block indices, v1
%.bx: %.sx ./dta-tokwrap-lsblocks.perl
	./dta-tokwrap-lsblocks.perl $< > $@ || (rm -f $@; false)

bx: $(XML_SOURCES:.xml=.bx)
no-bx: ; rm -f *.bx *.bx2 *.bx2s
CLEAN_FILES += *.bx

##-- serialization, v2

%.bx2: %.sx2 ./xml-no-namespaces ./xsltpipe.perl insert-implicit-breaks.xsl mark-sortkeys.xsl
	./xml-no-namespaces $< | ./xsltpipe.perl insert-implicit-breaks.xsl mark-sortkeys.xsl - -format -o $@
bx2: $(XML_SOURCES:.xml=.bx2)
no-bx2: no-bx
CLEAN_FILES += *.bx2

%.bx2s: %.bx2 ./dta-tokwrap-lsblocks2.perl
	./dta-tokwrap-lsblocks2.perl $< > $@ || (rm -f $@; false)
bx2s: $(XML_SOURCES:.xml=.bx2s)
CLEAN_FILES += *.bx2s



##======================================================================
## Rules: Clean
clean:
	test -z "$(CLEAN_FILES)" || rm -f $(CLEAN_FILES)

realclean: clean
	test -z "$(REALCLEAN_FILES)" || rm -f $(REALCLEAN_FILES)
