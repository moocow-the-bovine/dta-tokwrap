CC = gcc
LD = $(CC)

CPPFLAGS ?=
CFLAGS ?= -Wall -O2 -pipe
LDFLAGS ?=
LIBS ?= -lexpat

TARGETS = dta-tokwrap-mkindex

all: $(TARGETS)

dta-tokwrap-mkindex: dta-tokwrap-mkindex.o
	$(LD) $(LDFLAGS) -o $@ $^ $(LIBS)

%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(TARGETS) *.o
