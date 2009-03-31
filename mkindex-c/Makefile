CC = gcc
LD = $(CC)

CPPFLAGS ?=
CFLAGS ?= -Wall -O2 -pipe
LDFLAGS ?=
LIBS ?= -lexpat

TARGETS = dta-tokwrap-lschars

all: $(TARGETS)

dta-tokwrap-lschars: dta-tokwrap-lschars.o
	$(LD) $(LDFLAGS) -o $@ $^ $(LIBS)

%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(TARGETS) *.o
