# tools/Makefile — Build offline testing tools
#
# Usage:
#   make -C tools            build all benchmark tools
#   make -C tools sigfm-batch build only sigfm-batch
#   make -C tools replay     build only replay-pipeline
#   make -C tools nbis       build NBIS test binaries
#   make -C tools clean      remove build artifacts

CC      ?= gcc
CFLAGS  ?= -O2 -g -Wall -Wextra -Wno-unused-parameter
LDFLAGS ?=

# SIGFM source (linked directly — no library dependency)
SIGFM_DIR   = ../libfprint-fork/libfprint/sigfm
SIGFM_SRC   = $(SIGFM_DIR)/sigfm.c
SIGFM_INC   = -I$(SIGFM_DIR)

.PHONY: all clean nbis

all: benchmark/sigfm-batch benchmark/replay-pipeline

# ── sigfm-batch: SIGFM enrollment + verification benchmark ──────────
benchmark/sigfm-batch: benchmark/sigfm-batch.c $(SIGFM_SRC) $(SIGFM_DIR)/sigfm.h
	$(CC) $(CFLAGS) $(SIGFM_INC) -o $@ benchmark/sigfm-batch.c $(SIGFM_SRC) $(LDFLAGS) -lm

# ── replay-pipeline: offline preprocessing replay ───────────────────
benchmark/replay-pipeline: benchmark/replay-pipeline.c
	$(CC) $(CFLAGS) -o $@ benchmark/replay-pipeline.c $(LDFLAGS) -lm

# ── NBIS tests (delegates to nbis-test/Makefile) ────────────────────
nbis:
	$(MAKE) -C nbis-test

clean:
	rm -f benchmark/sigfm-batch benchmark/replay-pipeline
	$(MAKE) -C nbis-test clean
