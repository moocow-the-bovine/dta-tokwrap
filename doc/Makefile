DOT = dataflow-scripts.dot dataflow-perl.dot dataflow-perl-files.dot

TARGETS = $(DOT:.dot=.ps) $(DOT:.dot=.pdf)

##----------------------------------------------------------------------
## Rules: top-level
all: $(TARGETS)

##----------------------------------------------------------------------
## Rules: dot

ps: $(DOT:.dot=.ps)
%.ps: %.dot
	dot -Tps $< -o $@
CLEAN_FILES += $(DOT:.dot=.ps)

xps: $(DOT:.dot=.xps)
%.xps: %.ps
	gv -spartan -watch -scale=-2 $<

pdf: $(DOT:.dot=.pdf)
%.pdf: %.ps
	ps2pdf $< $@
CLEAN_FILES += $(DOT:.dot=.pdf)

png: $(DOT:.dot=.png)
%.png: %.dot
	dot -Tpng $< -o $@
CLEAN_FILES += $(DOT:.dot=.png)


##----------------------------------------------------------------------
## Rules: clean
clean:
	rm -f $(CLEAN_FILES)
