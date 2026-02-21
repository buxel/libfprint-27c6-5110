# tools/Makefile — Build offline testing tools
#
# Usage:
#   make              build all tools
#   make sigfm-batch  build only sigfm-batch
#   make replay       build only replay-pipeline
#   make clean        remove build artifacts

CC      ?= gcc
CFLAGS  ?= -O2 -g -Wall -Wextra -Wno-unused-parameter
LDFLAGS ?=

# SIGFM source (linked directly — no library dependency)
SIGFM_DIR   = ../libfprint-fork/libfprint/sigfm
SIGFM_SRC   = $(SIGFM_DIR)/sigfm.c
SIGFM_INC   = -I$(SIGFM_DIR)

.PHONY: all clean

all: sigfm-batch replay-pipeline

# ── sigfm-batch: SIGFM enrollment + verification benchmark ──────────
sigfm-batch: sigfm-batch.c $(SIGFM_SRC) $(SIGFM_DIR)/sigfm.h
	$(CC) $(CFLAGS) $(SIGFM_INC) -o $@ sigfm-batch.c $(SIGFM_SRC) $(LDFLAGS) -lm

# ── replay-pipeline: offline preprocessing replay ───────────────────
replay-pipeline: replay-pipeline.c
	$(CC) $(CFLAGS) -o $@ replay-pipeline.c $(LDFLAGS) -lm

clean:
	rm -f sigfm-batch replay-pipeline
