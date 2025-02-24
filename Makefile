EXE=fortea
LFLAGS=-lSystem -syslibroot `xcrun -sdk macosx --show-sdk-path` -arch arm64
SRCS=fortea.s
OBJS=$(SRCS:.s=.o)

all: $(EXE)

$(EXE): $(OBJS)
	ld $(LFLAGS) -o $@ $(OBJS)

fortea.o: fortea.s
	as -o $@ fortea.s

clean:
	rm -f $(OBJS) $(EXE)
