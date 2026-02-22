NBIS_ROOT = ../../libfprint-fork/libfprint/nbis
FP_SRC    = ../../libfprint-fork/libfprint

# Include paths
CFLAGS = -O2 -g \
    -I$(NBIS_ROOT)/include \
    -I$(NBIS_ROOT)/libfprint-include \
    -I$(FP_SRC) \
    $(shell pkg-config --cflags glib-2.0) \
    -Wno-unused-result \
    -Wno-incompatible-pointer-types \
    -Wno-int-conversion \
    -Wno-unused-function

LDFLAGS = $(shell pkg-config --libs glib-2.0) -lm

# All bundled NBIS sources (mindtct + bozorth3)
MINDTCT_SRC = $(wildcard $(NBIS_ROOT)/mindtct/*.c)
BOZORTH_SRC = $(wildcard $(NBIS_ROOT)/bozorth3/*.c)
NBIS_SRCS   = $(MINDTCT_SRC) $(BOZORTH_SRC)

SRCS = nbis-minutiae-test.c $(NBIS_SRCS)

all: nbis-minutiae-test nbis-bozorth3-test

nbis-minutiae-test: nbis-minutiae-test.c $(NBIS_SRCS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

nbis-bozorth3-test: nbis-bozorth3-test.c $(NBIS_SRCS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f nbis-minutiae-test nbis-bozorth3-test

.PHONY: all clean
