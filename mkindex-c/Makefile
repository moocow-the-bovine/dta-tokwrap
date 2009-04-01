CC = gcc
LD = $(CC)

CPPFLAGS ?=
CFLAGS ?= -Wall -O2 -pipe
LDFLAGS ?=
LIBS ?= -lexpat

TARGETS = dta-tokwrap-mkindex
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

dta-tokwrap-textindex: dta-tokwrap-textindex.o
	$(LD) $(LDFLAGS) -o $@ $^ $(LIBS)

dta-tokwrap-lschars: dta-tokwrap-lschars.o
	$(LD) $(LDFLAGS) -o $@ $^ $(LIBS)

dta-tokwrap-mkindex: dta-tokwrap-mkindex.o
	$(LD) $(LDFLAGS) -o $@ $^ $(LIBS)

##======================================================================
## Rules: Compling
%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c -o $@ $<

##======================================================================
## Rules: test

.SECONDARY:

%.chr.xml: %.xml ../dta-tokwrap-addchr.perl
	../dta-tokwrap-addchr.perl $< > $@ || (rm -f $@; false)

%.cx: %.cx %.sx %.tx
%.sx: %.cx %.sx %.tx
%.tx: %.cx %.sx %.tx
%.cx %.sx %.tx: %.xml dta-tokwrap-mkindex
	./dta-tokwrap-mkindex $< $*.cx $*.sx $*.tx
CLEAN_FILES += *.cx *.sx *.tx

XML_SOURCES ?= test-raw.chr.xml test1.xml ex1.xml ex2.xml

cx: $(XML_SOURCES:.xml=.cx)
sx: $(XML_SOURCES:.xml=.sx)
tx: $(XML_SOURCES:.xml=.tx)
xx: cx sx tx
no-cx: ; rm -f *.cx
no-sx: ; rm -f *.sx
no-tx: ; rm -f *.tx
no-xx: no-cx no-sx no-tx

##-- TODO
%.xbl: %.xcl ./dta-tokwrap-lsblocks.perl
	./dta-tokwrap-lsblocks.perl $< > $@ || (rm -f $@; false)

xbl: $(XML_SOURCES:.xml=.xbl)
no-xbl:
	rm -f *.xbl

##======================================================================
## Rules: Clean
clean:
	test -z "$(CLEAN_FILES)" || rm -f $(CLEAN_FILES)

realclean: clean
	test -z "$(REALCLEAN_FILES)" || rm -f $(REALCLEAN_FILES)
