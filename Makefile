XML_TXT   = ex2.txt.xml
XML_TXTLB = test-raw.txt+lb.xml ex1.txt+lb.xml $(XML_TXT:.txt.xml=.txt+lb.xml)
XML_CHR   = test1.chr.xml test-3k.chr.xml $(XML_TXTLB:.txt+lb.xml=.chr.xml)

XML = $(XML_CHR)

TARGETS = $(XML)

##======================================================================
## Rules: top-level

all: $(TARGETS)

##======================================================================
## Rules: add linebreaks

%.txt+lb.xml: ../scripts/dtatw-add-lb.xsl %.txt.xml
	xsltproc -o "$@" $^
txt+lb: lb
lb: $(XML_TXT:.txt.xml=.txt+lb.xml)
no-lb: ; rm -f $(XML_TXT:.txt.xml=.txt+lb.xml)
CLEAN_FILES += $(XML_TXT:.txt.xml=.txt+lb.xml)

##======================================================================
## Rules: add <c> elements

%.chr.xml: %.txt+lb.xml ../scripts/dtatw-add-c.perl
	../scripts/dtatw-add-c.perl $< -o $@
chr: $(XML_CHR)
no-chr: ; rm -f $(XML_TXTLB:.txt+lb.xml=.chr.xml)
CLEAN_FILES += $(XML_TXTLB:.txt+lb.xml=.chr.xml)

##======================================================================
## Rules: cleanup
clean:
	rm -f $(CLEAN_FILES)
