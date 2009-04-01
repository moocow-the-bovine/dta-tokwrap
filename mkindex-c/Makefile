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

%.xcl: %.xml dta-tokwrap-lschars
	./dta-tokwrap-lschars $< $@

XML_SOURCES ?= test-raw.chr.xml test1.xml ex1.xml ex2.xml

xcl: $(XML_SOURCES:.xml=.xcl)
no-xcl:
	rm -f *.xcl

%.xbl: %.xcl ./dta-tokwrap-lsblocks.perl
	./dta-tokwrap-lsblocks.perl $< > $@ || (rm -f $@; false)

xbl: $(XML_SOURCES:.xml=.xbl)
no-xbl:
	rm -f *.xbl

##======================================================================
## Rules: Clean
clean:
	rm -f $(TARGETS) *.o
