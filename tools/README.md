# tools/ — Offline Testing & Host Utilities

Build, capture, replay, and benchmark tools for the Goodix GF511 driver.

## Directory Structure

```
tools/
├── Makefile                          # top-level: builds benchmark/ tools, delegates to nbis-test/
├── README.md
├── benchmark/                        # A/B testing pipeline
│   ├── capture-corpus.sh             # capture N raw frames from sensor
│   ├── replay-pipeline.c             # offline preprocessing replay
│   └── sigfm-batch.c                 # SIGFM enrollment + verification benchmark
├── nbis-test/                        # NBIS viability tests (Phase 1, see doc 10)
│   ├── Makefile
│   ├── nbis-bozorth3-test.c
│   └── nbis-minutiae-test.c
└── scripts/                          # host utilities
    ├── analyze-capture.py            # image stats + log parsing
    ├── debug-capture.sh              # single-shot capture with debug logging
    ├── install.sh                    # install custom libfprint to /usr/local/lib
    └── uninstall.sh                  # revert to stock libfprint
```

## Build

```bash
make -C tools              # build benchmark tools (sigfm-batch, replay-pipeline)
make -C tools nbis         # build NBIS test binaries
make -C tools clean        # remove all build artifacts
```

Requires GCC and libm. SIGFM source is linked directly from
`../libfprint-fork/libfprint/sigfm/sigfm.c`.

---

## Benchmark Tools

### capture-corpus.sh

Captures N raw frames from the sensor in a loop using `img-capture`.
Saves both driver-processed PGMs and raw pre-processed frames (via `FP_SAVE_RAW`).

```bash
./tools/benchmark/capture-corpus.sh ./corpus/baseline 20
# Press finger once per prompt. Produces:
#   corpus/baseline/calibration.bin     — sensor calibration frame (14,080 bytes)
#   corpus/baseline/raw_0000.bin …      — raw uint16 LE frames (88×80, 14,080 bytes each)
#   corpus/baseline/capture_0001.pgm …  — driver-processed 64×80 PGMs
```

### replay-pipeline

Reads raw `.bin` frames, applies configurable preprocessing (same steps as
`goodix5xx.c`), outputs processed PGMs. Allows A/B testing of preprocessing
parameters on identical sensor data.

```bash
# Single frame
./tools/benchmark/replay-pipeline \
    --raw corpus/baseline/raw_0001.bin \
    --cal corpus/baseline/calibration.bin \
    --boost=10 -o output.pgm

# Batch mode — process all raw frames in a directory
./tools/benchmark/replay-pipeline --batch corpus/baseline --boost=10 -o corpus/boost10
```

| Flag | Default | Purpose |
|------|---------|---------|
| `--boost=N` | 4 | Unsharp mask boost factor |
| `--batch DIR` | — | Process all `raw_*.bin` in DIR |
| `-o PATH` | stdout | Output PGM (single) or directory (batch) |
| `--cal FILE` | — | Calibration frame for subtraction |

### sigfm-batch

Reads PGM files, splits into enrollment and verification sets, runs the full
SIGFM matching pipeline, reports per-frame scores and FRR.

```bash
./tools/benchmark/sigfm-batch \
    --enroll  corpus/baseline/capture_000{1..9}.pgm corpus/baseline/capture_0010.pgm \
    --verify  corpus/baseline/capture_001{1..9}.pgm corpus/baseline/capture_0020.pgm \
    --score-threshold=40
```

| Flag | Default | Purpose |
|------|---------|---------|
| `--enroll FILE …` | — | PGMs to use as enrollment template |
| `--verify FILE …` | — | PGMs to match against the template |
| `--score-threshold=N` | 40 | Minimum score for a match |

**Interpreting results:**

- **Keypoints**: FAST-9 corners detected. Healthy range: 60–128 (capped).
  Below 25 → frame rejected.
- **Score**: Geometrically consistent angle-pairs from matched BRIEF descriptors.
  Scale is O(n²) of matched features. Score 0 = fewer than 5 KNN matches found.
- **FRR**: False Rejection Rate — percentage of genuine attempts that failed.

---

## NBIS Tests

Phase 1 viability tests (see [analysis/10-nbis-viability-test.md](../analysis/10-nbis-viability-test.md)).
Builds against bundled libfprint NBIS sources. Confirmed that NBIS/bozorth3 is
not viable for the 64×80 sensor.

```bash
make -C tools nbis
./tools/nbis-test/nbis-minutiae-test enrolled.pgm
./tools/nbis-test/nbis-bozorth3-test enrolled.pgm verify.pgm
```

---

## Host Scripts

### debug-capture.sh

Single-shot capture with full debug logging. Useful for diagnosing individual
frames.

```bash
./tools/scripts/debug-capture.sh output.pgm
# or with enrollment mode (captures SIGFM metrics):
CAPTURE_MODE=enroll ./tools/scripts/debug-capture.sh
```

### analyze-capture.py

Image statistics and visual analysis of captured PGMs.

```bash
python3 tools/scripts/analyze-capture.py capture.pgm --log capture.log
```

### install.sh / uninstall.sh

Install or remove the custom libfprint `.so` on the host system.

```bash
sudo ./tools/scripts/install.sh      # copies built .so to /usr/local/lib
sudo ./tools/scripts/uninstall.sh    # removes it and restores stock libfprint
```

---

## A/B Testing Workflow

```
  Sensor                    Offline (no sensor needed)
  ──────                    ──────────────────────────
  capture-corpus.sh    →    replay-pipeline    →    sigfm-batch
  (raw .bin + PGM)          (raw → PGM)             (PGM → scores + FRR)
```

1. **Capture** a corpus of raw frames from the real sensor (once)
2. **Replay** through different preprocessing configs (boost, stretch, etc.)
3. **Benchmark** each variant with `sigfm-batch` to compare FRR

This isolates preprocessing changes from finger placement variation.

Full design rationale: [analysis/14-testing-and-benchmarking-strategy.md](../analysis/14-testing-and-benchmarking-strategy.md)
