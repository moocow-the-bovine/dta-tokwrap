XML_TXT   = ex2.txt.xml
XML_TXTLB = test-raw.txt+lb.xml $(XML_TXT:.txt.xml=.txt+lb.xml)
XML_CHR   = test1.chr.xml test-3k.chr.xml ex1.chr.xml $(XML_TXTLB:.txt+lb.xml=.chr.xml)

XML = $(XML_CHR)
XML_SOURCES = $(XML)

TARGETS = $(XML)

##======================================================================
## Variables: Programs

MKINDEX   ?= ../src/dtatw-mkindex
RMNS      ?= ../src/xml-rm-namespaces
TOKENIZER ?= ../src/dtatw-tokenize-dummy

LSBLOCKS  ?= ../scripts/dtatw-lsblocks.perl
TT2XML    ?= ../scripts/dtatw-tt2xml.perl

PROGRAMS = $(MKINDEX) $(RMNS) $(TOKENIZER)

##======================================================================
## Rules: top-level

all: $(PROGRAMS) $(TARGETS)

.SECONDARY: 

##======================================================================
## Rules: programs

programs: $(PROGRAMS)

$(MKINDEX): ../src/dtatw-mkindex.c
$(RMNS): ../src/xml-rm-namespaces.c
$(TOKENIZER): ../src/dtatw-tokenize-dummy.l

../src/%:
	$(MAKE) -C ../src "$*"

##======================================================================
## Rules: add linebreaks

%.txt+lb.xml: ../scripts/dtatw-add-lb.xsl %.txt.xml
	xsltproc -o "$@" $^
txt+lb: lb
lb: $(XML_TXT:.txt.xml=.txt+lb.xml)
no-lb: ; rm -f $(XML_TXT:.txt.xml=.txt+lb.xml)
REALCLEAN_FILES += $(XML_TXT:.txt.xml=.txt+lb.xml)

##======================================================================
## Rules: add <c> elements

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
## Rules: mkindex: xx=(cx,sx,tx)

xx: cx sx tx
cx: $(XML_SOURCES:.xml=.cx)
sx: $(XML_SOURCES:.xml=.sx)
tx: $(XML_SOURCES:.xml=.tx)
no-cx: ; rm -f $(XML_SOURCES:.xml=.cx)
no-sx: ; rm -f $(XML_SOURCES:.xml=.sx)
no-tx: ; rm -f $(XML_SOURCES:.xml=.tx)
no-xx: no-cx no-sx no-tx

%.cx: %.cx %.sx %.tx
%.sx: %.cx %.sx %.tx
%.tx: %.cx %.sx %.tx
%.cx %.sx %.tx: %.xml $(MKINDEX)
	$(MKINDEX) $< $*.cx $*.sx $*.tx
CLEAN_FILES += *.cx *.sx *.tx

sx-fmt: $(XML_SOURCES:.xml=.sx.fmt)
no-sx-fmt: ; rm -f *.sx.fmt

sx-nons: $(XML_SOURCES:.xml=.sx.nons)
no-sx-nons: ; rm -f *.sx.nons *.sx.nons.fmt

sx-nons-fmt: $(XML_SOURCES:.xml=.sx.nons.fmt)
no-sx-nons-fmt: ; rm -f *.sx.nons.fmt
CLEAN_FILES += *.sx.nons *.sx.fmt *.sx.nons.fmt *.sx.fmt.nons

##======================================================================
## Rules: serialization (serialized block index: bx0)

%.bx0: %.sx $(RMNS) ../scripts/dtatw-insert-hints.xsl ../scripts/dtatw-mark-sortkeys.xsl
	$(RMNS) $< \
	 | xsltproc ../scripts/dtatw-insert-hints.xsl - \
	 | xsltproc ../scripts/dtatw-mark-sortkeys.xsl - \
	 | xmllint --format - \
	 > $@ || (rm -f $@; false)
bx0: $(XML_SOURCES:.xml=.bx0)
no-bx0: ; rm -f *.bx0
CLEAN_FILES += *.bx0

##======================================================================
## Rules: serialized text + index (bx, txt)

serialize: txt
bx: $(XML_SOURCES:.xml=.bx)
txt: $(XML_SOURCES:.xml=.txt)
no-bx: ; rm -f *.bx0 *.bx
no-txt: ; rm -f *.txt

%.bx:  %.bx %.txt
%.txt: %.bx %.txt
%.bx %.txt: %.bx0 %.tx $(LSBLOCKS)
	$(LSBLOCKS) "$*.bx0" "$*.tx" "$*.bx" "$*.txt"
CLEAN_FILES += *.bx

##======================================================================
## Rules: tokenization: dummy, via flex for speed: .t

%.t: %.txt $(TOKENIZER)
	$(TOKENIZER) < "$<" > "$@" || (rm -f "$@"; false)
t: $(XML_SOURCES:.xml=.t)
no-t: ; rm -f *.t
CLEAN_FILES += *.t

##======================================================================
## Rules: tokenized: master xml output

%.t.xml: %.t %.bx %.cx $(TT2XML)
	$(TT2XML) "$*.t" "$*.bx" "$*.cx" -o "$@" -f
t-xml: $(XML_SOURCES:.xml=.t.xml)
no-t-xml: ; rm -f *.t.xml
tokd-xml: t-xml
no-tokd-xml: no-t-xml
tt-xml: t-xml
no-tt-xml: no-t-xml
CLEAN_FILES += *.t.xml *.tokd.xml

##======================================================================
## Rules: standoff (via xsl)

##-- standoff: top level
standoff: s-xml w-xml a-xml
no-standoff: no-s-xml no-w-xml no-a-xml
%-standoff:
	$(MAKE) $*.s.xml $*.w.xml $*.a.xml

##-- standoff: .s.xml
%.s.xml: ../scripts/dtatw-txml2sxml.xsl %.t.xml
	xsltproc --stringparam xmlbase "$*.w.xml" -o "$@" $^
s-xml: $(XML_SOURCES:.xml=.s.xml)
no-s-xml: ; rm -f *.s.xml
CLEAN_FILES += *.s.xml

##-- standoff: .w.xml
%.w.xml: ../scripts/dtatw-txml2wxml.xsl %.t.xml
	xsltproc --stringparam xmlbase "$*.xml" -o "$@" $^
w-xml: $(XML_SOURCES:.xml=.w.xml)
no-w-xml: ; rm -f *.w.xml
CLEAN_FILES += *.w.xml

##-- standoff: .a.xml
%.a.xml: ../scripts/dtatw-txml2axml.xsl %.t.xml
	xsltproc --stringparam xmlbase "$*.w.xml" -o "$@" $^
a-xml: $(XML_SOURCES:.xml=.a.xml)
no-a-xml: ; rm -f *.a.xml
CLEAN_FILES += *.a.xml

##-- running time summary / ex1 (kraepelin) / uhura
## xml -> cx,sx,tx   1.2s  ~  75.9 Ktok/sec ~ 502.3 Kchr/sec
## sx -> bx0         0.11s ~ 842.8 Ktok/sec ~   5.6 Mchr/sec
## bx0 -> txt        0.30s ~ 303.4 Ktok/sec ~   2.0 Mchr/sec
## txt -> t          0.08s ~   1.1 Mtok/sec ~   7.5 Mchr/sec
## t -> t.xml       13.13s ~   6.9 Ktok/sec ~  45.9 Kchr/sec  *** SLOW (perl) ***
## t.xml -> s.xml    1.79s ~  59.8 Ktok/sec ~ 336.8 Kchr/sec
## t.xml -> w.xml    8.62s ~  10.6 Ktok/sec ~  70.0 Kchr/sec  *** SLOW (xsl) ***
## t.xml -> a.xml    2.08s ~  43.8 Ktok/sec ~ 289.8 Kchr/sec
## TOTAL            27.31s ~   3.3 Ktok/sec ~  22.1 Kchr/sec


##======================================================================
## Rules: cleanup
clean:
	rm -f $(CLEAN_FILES)

realclean: clean
	rm -f $(REALCLEAN_FILES)
