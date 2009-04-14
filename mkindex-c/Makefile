CC = gcc
LD = $(CC)

CPPFLAGS ?=
CFLAGS ?= -Wall -O2 -pipe
#CFLAGS ?= -Wall -g
LDFLAGS ?=
LIBS ?= -lexpat

TARGETS = dta-tokwrap-mkindex xml-no-namespaces
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

##-- tokenization (dummy)
%.tokd: %.txt dta-tokenize-dummy.perl
	./dta-tokenize-dummy.perl "$<" -o "$@"
tokd: $(XML_SOURCES:.xml=.tokd)
no-tokd: ; rm -f *.tokd
CLEAN_FILES += *.tokd

##-- standoff
%.s.xml: %.s.xml %.w.xml
%.w.xml: %.s.xml %.w.xml
sw: $(XML_SOURCES:.xml=.s.xml) $(XML_SOURCES:.xml=.w.xml)
ws: sw
no-sw: ; rm -f *.s.xml *.w.xml
no-ws: no-sw
CLEAN_FILES += *.s.xml *.w.xml

%.s.xml %.w.xml: %.cx %.bx %.tokd dta-tokwrap-standoff.perl
	./dta-tokwrap-standoff.perl "$*.cx" "$*.bx" "$*.tokd" -xb="$*.xml" -f


##======================================================================
## Rules: Clean
clean:
	test -z "$(CLEAN_FILES)" || rm -f $(CLEAN_FILES)

realclean: clean
	test -z "$(REALCLEAN_FILES)" || rm -f $(REALCLEAN_FILES)
