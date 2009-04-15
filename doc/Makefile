DOT = dataflow.dot

TARGETS = $(DOT:.dot=.ps)

##----------------------------------------------------------------------
## Rules: top-level
all: $(TARGETS)

##----------------------------------------------------------------------
## Rules: dot

ps: $(DOT:.dot=.ps)
%.ps: %.dot
	dot -Tps $< -o $@
CLEAN_FILES += $(DOT:.dot=.ps)

##----------------------------------------------------------------------
## Rules: clean
clean:
	rm -f $(CLEAN_FILES)
