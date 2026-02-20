FROM ubuntu:22.04

# Avoid interactive prompts during package install
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# ─────────────────────────────────────────────────────────────────────────────
# All build dependencies in one layer.
# Ubuntu 22.04 ships:
#   GCC 11     — avoids the GCC 15 incompatible-pointer-types breakage in goodixtls
#   OpenCV 4.5.4 — the pre-API-break version needed by SIGFM matching
#   GnuTLS 3.7.3 — for the planned upstream rewrite (OpenSSL also available)
# ─────────────────────────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    gcc-11 g++-11 \
    meson \
    ninja-build \
    pkg-config \
    cmake \
    git \
    wget \
    curl \
    uncrustify \
    # libfprint core dependencies
    libglib2.0-dev \
    libgusb-dev \
    libcairo2-dev \
    libpixman-1-dev \
    libdbus-1-dev \
    # udev / gudev — needed by SPI-capable sensor drivers in the fork
    libudev-dev \
    libgudev-1.0-dev \
    udev \
    # TLS libraries
    # OpenSSL: used by the current community driver
    libssl-dev \
    # GnuTLS: target for upstream-quality rewrite
    libgnutls28-dev \
    # NSS: required by uru4000 and other drivers in the fork
    libnss3-dev \
    # OpenCV 4.5.4 — runtime dep required by SIGFM matching algorithm
    libopencv-dev \
    python3-opencv \
    # GObject introspection + gtk-doc
    gobject-introspection \
    libgirepository1.0-dev \
    gtk-doc-tools \
    # fprintd for enrollment/verification testing
    fprintd \
    libpam-fprintd \
    # Python 3.10 for goodix-fp-dump
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    # USB tools
    usbutils \
    # Debugging helpers
    gdb \
    valgrind \
    strace \
    && rm -rf /var/lib/apt/lists/*

# Make gcc-11 the explicit default
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 100 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 100

# ─────────────────────────────────────────────────────────────────────────────
# Clone source repositories
# ─────────────────────────────────────────────────────────────────────────────

# NOTE: The primary libfprint fork (goodixtls SIGFM branch) is NOT cloned here.
# It lives in the workspace at /workspace/libfprint-fork so changes persist across
# container rebuilds. The source is part of the repo itself (a commit-tracked directory).
# Build is triggered by postCreateCommand in devcontainer.json.

# Community main fork (for reference and PR work)
RUN git clone --depth=1 \
    https://github.com/goodix-fp-linux-dev/libfprint.git \
    /opt/libfprint-goodix-fp-linux-dev

# goodix-fp-dump: firmware flash + standalone image capture tool
RUN git clone --recurse-submodules --depth=1 \
    https://github.com/goodix-fp-linux-dev/goodix-fp-dump.git \
    /opt/goodix-fp-dump

# ─────────────────────────────────────────────────────────────────────────────
# Python venv for goodix-fp-dump
# IMPORTANT: always use .venv/bin/python3 (root breaks PATH venv convention)
# ─────────────────────────────────────────────────────────────────────────────
RUN cd /opt/goodix-fp-dump \
    && python3 -m venv .venv \
    && .venv/bin/pip install --upgrade pip \
    && .venv/bin/pip install -r requirements.txt

# ─────────────────────────────────────────────────────────────────────────────
# Build helper script (also explains the Ubuntu 22.04 udev.pc shim needed)
# ─────────────────────────────────────────────────────────────────────────────
COPY .devcontainer/build-libfprint.sh /opt/build-libfprint.sh
RUN chmod +x /opt/build-libfprint.sh

WORKDIR /workspace

# Convenience banner on bash login
RUN printf '%s\n' \
    'echo "=== Goodix 5110 Dev Container (Ubuntu 22.04 / GCC 11) ==="' \
    'echo "  GCC:    $(gcc --version | head -1)"' \
    'echo "  OpenCV: $(pkg-config --modversion opencv4 2>/dev/null || echo n/a)"' \
    'echo "  GnuTLS: $(pkg-config --modversion gnutls 2>/dev/null || echo n/a)"' \
    'echo "  Python: $(python3 --version)"' \
    'echo ""' \
    'echo "  Sensor:          lsusb | grep 27c6"' \
    'echo "  Source:          /workspace/libfprint-fork (edit here)"' \
    'echo "  Rebuild:         /opt/build-libfprint.sh"' \
    'echo "  Flash firmware:  cd /opt/goodix-fp-dump && .venv/bin/python3 run_5110.py"' \
    'echo "  Enroll:          fprintd-enroll"' \
    >> /etc/bash.bashrc

CMD ["/bin/bash"]
