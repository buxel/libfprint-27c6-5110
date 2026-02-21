# Devcontainer Handoff — Next Steps

## Current State (2026-02-19)

We are on a **USB-booted CachyOS Linux** machine (the physical Huawei MateBook 14 AMD 2020).
The sensor `27c6:5110` is confirmed present: `lsusb | grep 27c6` shows it.
The host OS has GCC 15 and Python 3.14 — neither is suitable for building the community driver.

A **Podman container image has been built** and is ready:

```
localhost/goodix-fp-dev   latest   ~1.84 GB
```

### What's in the container

| Component | Version | Path |
|---|---|---|
| Ubuntu | 22.04 | — |
| GCC | 11.4.0 | `/usr/bin/gcc` |
| OpenCV | 4.5.4 | system |
| GnuTLS | 3.7.3 | system |
| OpenSSL | 3.0.2 | system |
| Python | 3.10.12 | system + venv |
| libfprint SIGFM fork | 0x2a/dev/goodixtls-sigfm | `/opt/libfprint-goodixtls` |
| goodix-fp-linux-dev/libfprint | main | `/opt/libfprint-goodix-fp-linux-dev` |
| goodix-fp-dump | main + firmware submodule | `/opt/goodix-fp-dump` |
| goodix-fp-dump Python venv | pyusb, pycryptodome, etc. | `/opt/goodix-fp-dump/.venv` |
| fprintd | 1.94.2 | system |

The libfprint fork is **not yet compiled** — an Ubuntu 22.04 quirk with `udev.pc` vs `libudev.pc`
requires a one-time shim. A helper script handles this:

```
/opt/build-libfprint.sh
```

---

## How to Start the Container

```bash
# Start an interactive shell with USB passthrough:
podman run --rm -it \
    --privileged \
    --net=host \
    --device=/dev/bus/usb \
    -v /dev/bus/usb:/dev/bus/usb \
    -v /home/buxel/llm-fingerprint-research:/workspace \
    goodix-fp-dev

# Or use VS Code Dev Containers (open the repo, "Reopen in Container")
# The .devcontainer/devcontainer.json is already configured.
```

---

## Immediate Next Steps (in order)

### Step 1 — Build libfprint inside the container

```bash
bash /opt/build-libfprint.sh
```

This will:
1. Create a `udev.pc` shim (Ubuntu 22.04 names it `libudev.pc` — meson needs `udev.pc`)
2. Run `meson setup build` with the `-Wno-error=incompatible-pointer-types` workaround
3. `ninja && ninja install && ldconfig`

Expected outcome: `libfprint-2.so` installed under `/usr/local/lib`.

If the build **fails with meson errors**, check `meson-logs/meson-log.txt` in the build dir
and add any missing `pkg-config` shims to the script similarly to the udev shim.

If the build **fails with GCC errors** (incompatible pointer types), the `goodixtls` driver
code has issues that the flag doesn't fully cover — see [02-development-status-and-known-issues.md](02-development-status-and-known-issues.md#8-gcc-15-compilation-failure-%EF%B8%8F-cachyos-specific) for the GCC 15 fix (GCC 11 should not hit this, but the pattern is documented).

### Step 2 — Flash the sensor firmware

```bash
cd /opt/goodix-fp-dump
.venv/bin/python3 run_5110.py
```

**Critical:** Always use `.venv/bin/python3`, not bare `python3`. Running as root breaks the
PATH-based venv lookup (tip from Discord, 2025-08-14).

Expected output: progress messages, no Python exceptions. If it hangs or errors with a USB
claim error, check `journalctl` or `dmesg` on the host — a kernel driver may have claimed
the device. Unbind it: `echo '1-X.Y' > /sys/bus/usb/drivers/usbhid/unbind`.

### Step 3 — Test standalone image capture

```bash
cd /opt/goodix-fp-dump
.venv/bin/python3 run_5110.py
```

(Same command — the script both flashes and captures test images.) Look for `.png` output
files in the working directory. If images are captured, **the hardware is working**.

### Step 4 — Test fprintd enrollment

```bash
fprintd-enroll
# Place finger on sensor 5 times when prompted
fprintd-verify
```

**Most likely failure:** `"Failed to detect minutiae: No minutiae found"` — this is the known
SIGFM issue. It means libfprint was built without SIGFM active, or OpenCV pre-processing
broke. Compare `pkg-config --modversion opencv4` inside the container (should be 4.5.4).

If enrollment works: **we have a working driver baseline**. Document the exact version hashes
of every component that worked.

---

## Key Files

| File | Purpose |
|---|---|
| [.devcontainer/Dockerfile](../.devcontainer/Dockerfile) | Container definition — Ubuntu 22.04, all deps, cloned repos |
| [.devcontainer/devcontainer.json](../.devcontainer/devcontainer.json) | VS Code devcontainer config with USB passthrough |
| [.devcontainer/build-libfprint.sh](../.devcontainer/build-libfprint.sh) | One-time build script for libfprint inside container |
| [00-action-plan-and-threads-to-pull.md](00-action-plan-and-threads-to-pull.md) | Overall plan and community threads |
| [06-implementation-strategy.md](06-implementation-strategy.md) | Full upstream contribution strategy (GnuTLS, GLib async, SIGFM) |

---

## Why Ubuntu 22.04 (Not CachyOS)

The host CachyOS has:
- **GCC 15** — breaks the goodixtls driver (`incompatible-pointer-types` are errors in GCC 15)
- **Python 3.14** — goodix-fp-dump requires 3.10 range
- **OpenCV 4.x (latest)** — API changes broke SIGFM's image preprocessing pipeline

Ubuntu 22.04 LTS pins all three at the known-working versions. The container solves the
environment problem without touching the host.

---

## Known Risk: udev.pc Shim

The `build-libfprint.sh` script copies `libudev.pc` → `udev.pc` under `/usr/local/lib/pkgconfig`
and patches the `Name:` field. This is a container-local workaround and has no effect outside
the container. If meson still complains about `udev`, verify:

```bash
pkg-config --exists udev && echo ok || echo missing
pkg-config --modversion udev
```
