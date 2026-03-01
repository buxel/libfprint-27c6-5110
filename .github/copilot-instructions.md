# Copilot Agent Instructions — libfprint-27c6-5110

## Project Context

This workspace contains a fork of [libfprint](https://gitlab.freedesktop.org/libfprint/libfprint)
adding support for the Goodix GF511 (USB 27c6:5110) TLS fingerprint sensor.
The primary goal is **upstream acceptance** into the main libfprint project.

## Upstreamability Guardrails

Every code change must be evaluated against existing upstream patterns.
Non-conformance creates refactoring debt that delays the merge request.

### Before adding any new file, build target, or test pattern

- Search existing upstream code for how other drivers/modules handle the
  same problem.  Prefer matching the established pattern exactly.
- For test infrastructure: compare against at least 2-3 existing driver
  tests in `tests/` (e.g. `goodixmoc`, `synaptics`, `elanmoc`).
  Match file permissions, import style, assert patterns, and overall flow.
- New files that have no precedent in the upstream tree are a red flag.

### Before introducing new build dependencies or infrastructure

- Verify at least one other driver already uses the same pattern
  (shared libraries, LD_PRELOAD shims, extra meson constructs, etc.).
- If no other driver does it, **flag it as a divergence risk** and propose
  the simpler upstream-aligned alternative first.
- Never add compile-time dependencies to `tests/meson.build` that aren't
  already present in the upstream test infrastructure.

### Before suppressing or downgrading warnings/errors

- `G_DEBUG=fatal-criticals` instead of `fatal-warnings`, `#pragma`
  suppressions, or allowlist exceptions are **code smells**.
- Investigate and fix the root cause in the driver rather than masking it.
- If the warning originates in upstream core code (e.g. `fpi-image-device.c`),
  document the root cause and whether it affects other drivers.

### When modifying shared build files

- `tests/meson.build`, `libfprint/meson.build`, top-level `meson.build`:
  prefer **zero per-driver special-casing**.
- Adding the driver name to the `drivers_tests` list should be sufficient.
- If special-casing is unavoidable, document *why* in both the code comment
  and the commit message.

### General litmus test

> "If this change would make a libfprint maintainer ask
> *'why does this driver need special treatment?'*, rethink the approach
> before implementing."

## Code Style

- C code follows the existing libfprint/GLib style (GNU indent, 2-space
  indentation within braces, `g_autoptr` where applicable).
- Python test scripts follow the pattern in `tests/goodixmoc/custom.py`.
- Commit messages: imperative mood, `area: description` prefix
  (e.g. `goodixtls: fix TLS session teardown`).

## Driver Architecture

- `libfprint/drivers/goodixtls/` — shared TLS + protocol layer
- `libfprint/drivers/goodixtls/goodix5xx.c` — GF5xx scan state machine
- `libfprint/drivers/goodixtls/goodix511.c` — GF511-specific device entry
- `libfprint/drivers/goodixtls/sigfm/` — Signal-Feature Matching library
- `tests/goodixtls511/` — umockdev pcap replay test

## Testing

- `meson test -C build goodixtls511` — run the driver replay test
- `meson test -C build` — full test suite (must not regress)
- Tests use `FP_DEVICE_EMULATION=1` with deterministic TLS for pcap replay
- Test data (`device`, `custom.pcapng`) is recorded from real hardware
