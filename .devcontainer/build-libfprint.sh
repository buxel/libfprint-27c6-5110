#!/bin/bash
# Build and install the goodixtls libfprint fork from the workspace.
# Automatically runs on first container creation via postCreateCommand.
# Re-run manually after source changes: /opt/build-libfprint.sh
set -e

SOURCE=/workspace/libfprint-fork

if [ ! -d "$SOURCE" ]; then
    echo "ERROR: $SOURCE not found."
    echo "The libfprint source should be at /workspace/libfprint-fork (part of the repo)."
    exit 1
fi

echo "=== Building libfprint goodixtls (SIGFM branch) ==="
echo "    Source: $SOURCE"
cd "$SOURCE"

# Ubuntu 22.04 ships libudev.pc (pkg-config Name: libudev), but this fork's
# meson.build calls dependency('udev') which looks for udev.pc.
# Create a shim so meson resolves 'udev' → libudev.
PCDIR=/usr/local/lib/pkgconfig
mkdir -p "$PCDIR"
if ! pkg-config --exists udev 2>/dev/null; then
    echo "Creating udev.pc shim → libudev"
    LIBUDEV_PC=$(find /usr -name "libudev.pc" 2>/dev/null | head -1)
    if [ -z "$LIBUDEV_PC" ]; then
        echo "ERROR: libudev.pc not found. Is libudev-dev installed?"
        exit 1
    fi
    cp "$LIBUDEV_PC" "$PCDIR/udev.pc"
    sed -i 's/^Name: libudev/Name: udev/' "$PCDIR/udev.pc"
    echo "  Created $PCDIR/udev.pc"
fi

# Configure
# --wipe only works on an existing meson build dir; fall back to plain setup on a fresh clone.
if [ -f build/build.ninja ]; then
    SETUP_FLAGS="--wipe"
else
    rm -rf build
    SETUP_FLAGS=""
fi
meson setup build \
    -Ddoc=false \
    -Dgtk-examples=false \
    -Dintrospection=false \
    -Dc_args="-Wno-error=incompatible-pointer-types" \
    $SETUP_FLAGS

# Build and install
ninja -C build
ninja -C build install
ldconfig

echo ""
echo "=== libfprint goodixtls installed successfully ==="
echo "  Source:         /workspace/libfprint-fork"
echo "  Flash firmware: cd /opt/goodix-fp-dump && .venv/bin/python3 run_5110.py"
echo "  Then enroll:    fprintd-enroll"
