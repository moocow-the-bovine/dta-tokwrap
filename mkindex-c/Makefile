CC = gcc
LD = $(CC)

CPPFLAGS ?=
CFLAGS ?= -Wall -O2 -pipe
LDFLAGS ?=
LIBS ?= -lexpat

TARGETS = dta-tokwrap-textindex
#dta-tokwrap-lschars
#dta-tokwrap-mkindex

##======================================================================
## Variables: cleanup

CLEAN_FILES = *.o
REALCLEAN_FILES = $(TARGETS)

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

%.ix: %.ix %.tx
%.tx: %.ix %.tx
%.ix %.tx: %.xml dta-tokwrap-textindex
	./dta-tokwrap-textindex $< $*.ix $*.tx
CLEAN_FILES += *.ix *.tx

XML_SOURCES ?= test-raw.chr.xml test1.xml ex1.xml ex2.xml

ix: $(XML_SOURCES:.xml=.ix)
tx: $(XML_SOURCES:.xml=.tx)
ixtx: ix tx
no-ix: ; rm -f *.ix
no-tx: ; rm -f *.tx
no-ixtx: no-ix no-tx

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
