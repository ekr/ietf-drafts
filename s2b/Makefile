# nrappkit is Network Resonance's application development kit.
# See http://nrappkit.sourceforge.net

NRAPPKIT_SRC = /users/ekr/src/nrappkit/src/
NRAPPKIT_MAKE=$(NRAPPKIT_SRC)make/freebsd


YFLAGS	= -dv
CFLAGS	= -g -DYYDEBUG=0 -I$(NRAPPKIT_MAKE) -I$(NRAPPKIT_SRC)util/libekr
LDFLAGS	= -L$(NRAPPKIT_MAKE) -lnrappkit


SRC	= gram.y scan.l 
OBJ	= gram.o scan.o main.o

s2b:	$(OBJ)
	cc $(CFLAGS) -g -o $@ $(OBJ)  $(LDFLAGS)

$(OBJ): y.tab.h

y.tab.h: gram.c gram.y

scan.c  : y.tab.h
scan.o	: y.tab.h

clean	:
	rm -f y.tab.h y.output *.o clic gram.c


