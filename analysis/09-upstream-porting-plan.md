# 09 — Upstream Porting Plan: OpenSSL → GnuTLS, SIGFM → NBIS

**Date:** 2026-02-19  
**Goal:** Produce a libfprint MR that can be accepted upstream — no OpenSSL, no pthreads,
no OpenCV, following the exact patterns already used by other upstream drivers.

---

## What Needs to Change (Summary)

| Component | Current | Target | Effort |
|---|---|---|---|
| `goodixtls.c/h` | OpenSSL BIO pair + pthread | GnuTLS custom transport, no thread | ~150 lines rewrite |
| `sigfm/sigfm.cpp` | SIFT via OpenCV | NBIS (built-in) or pure-C SIFT | empirical test first |
| `fp-device-private.h` | `DEFAULT_TEMP_HOT_SECONDS` global changed | `temp_hot_seconds = -1` in driver class | 1 line |
| `meson.build` (root) | `openssl`, `threads`, `opencv` deps | `gnutls` (optional), no opencv | ~20 lines |
| `libfprint/meson.build` | sigfm subdir, C++ build | pure C, sigfm removed | ~15 lines |
| `project()` | `cpp_std=c++17` language | C only | 2 lines |

---

## Phase 1 — NBIS Viability Test (do first, ~1 day)

**Why first:** If NBIS works on upscaled images, OpenCV/SIGFM is eliminated entirely — no
new matching dep, simplest possible upstream story. Spending time on GnuTLS before knowing
this would be premature.

### What to test

The sensor produces 64×80 px images at 508 DPI. libfprint's NBIS path calls `mindtct` on
the image. `mindtct` needs at least ~8–10 reliable minutiae to feed to bozorth3.

The test: write a small standalone C program that calls the libfprint C API directly on
captured images at various upscale factors, and print how many minutiae are detected.

```c
// nbis-test.c
// Build against libfprint-2.so (already installed in /usr/local)
#include <libfprint-2/fprint.h>
#include <glib.h>
#include <stdio.h>

// Load a PGM file, upscale with nearest-neighbor to target_size,
// run through fp_minutiae_from_image() and print the count.
// (The fpi_* internal APIs are not accessible from outside the .so,
//  so test via the enroll/verify example pipeline instead — see below)
```

**Better approach:** Use the already-working `verify` example. Run enroll with the sensor
at various finger press angles and positions, then check match scores. If SIGFM scores are
consistently high (>100 when it works, seen as low as 22 on a marginal scan) and the 20-scan
enrollment produces a robust template, the matching algorithm is capable. The question is
whether NBIS _minutiae detection_ works on the raw images.

**Concrete NBIS test procedure:**

```bash
# 1. Build NBIS standalone tools from the libfprint-bundled source
cd /opt/libfprint-goodixtls/libfprint/nbis/mindtct
make  # produces mindtct binary (check if there's a standalone Makefile)

# 2. Upscale enrolled.pgm to test sizes using ImageMagick or Python PIL
python3 - <<'EOF'
from PIL import Image
img = Image.open('/workspace/enrolled.pgm')
print(f"Original: {img.size}")  # (64, 80)
for scale in [2, 4, 6]:
    up = img.resize((img.width * scale, img.height * scale),
                    Image.BICUBIC)
    up.save(f'/tmp/enrolled_{scale}x.pgm')
    print(f"{scale}x: {up.size}")
EOF

# 3. Run mindtct on each upscaled image
for s in 2 4 6; do
    mindtct /tmp/enrolled_${s}x.pgm /tmp/enrolled_${s}x
    echo "=== ${s}x: $(wc -l < /tmp/enrolled_${s}x.min) minutiae ==="
done
```

**Decision criteria:**

| Minutiae count (4x upscale) | Decision |
|---|---|
| ≥ 15 consistently | Use NBIS — drop SIGFM and OpenCV entirely |
| 8–14 | Risky; try bozorth3 match score, may work |
| < 8 | NBIS cannot work; implement pure-C SIFT replacement |

---

## Phase 2 — GnuTLS Migration (`goodixtls.c` / `goodixtls.h`)

This is independent of Phase 1 and can be done in parallel or immediately after.

### Architecture: why the thread disappears

The current design creates a Unix socket pair and runs `SSL_accept()` blocking in a pthread.
The TLS handshake is driven from `goodix.c` indirectly — the `tls_handshake_run` FpiSsm
forwards bytes through the socket pair sockets. The socket pair is the IPC between:

- **Client side** (`client_fd`): raw encrypted bytes from/to sensor
- **Server side** (`sock_fd`): OpenSSL BIO, decrypts/encrypts

GnuTLS supports **non-blocking sessions with custom transport callbacks**, making the thread
unnecessary. Instead of a socket pair, we use two in-memory `GByteArray` buffers:

```
Current (OpenSSL + socket pair + pthread):
  sensor ↔ goodix.c ↔ client_fd ↔ [kernel socket] ↔ sock_fd ↔ SSL_accept() [pthread]

Target (GnuTLS + byte arrays, no thread):
  sensor ↔ goodix.c ↔ in_buf/out_buf ↔ gnutls_handshake() [called inline, non-blocking]
```

`gnutls_handshake()` returns `GNUTLS_E_AGAIN` when it needs more data. The FpiSsm state
machine in `goodix.c` already has the right structure (5 states = 5 TLS round trips) —
only the calls at the boundaries change.

### New `goodixtls.h` structure

```c
// goodixtls.h — GnuTLS version
#pragma once

#include <glib.h>
#include <gnutls/gnutls.h>

typedef struct _GoodixTlsServer {
  gnutls_session_t                   session;
  gnutls_psk_server_credentials_t    creds;
  GByteArray                        *in_buf;   // encrypted bytes from sensor
  GByteArray                        *out_buf;  // encrypted bytes to sensor
} GoodixTlsServer;

gboolean goodix_tls_server_init    (GoodixTlsServer *self, GError **error);
gboolean goodix_tls_server_deinit  (GoodixTlsServer *self, GError **error);

// Feed raw encrypted bytes arriving from sensor into the TLS session:
void goodix_tls_client_write (GoodixTlsServer *self, const guint8 *data, guint16 length);

// Drain raw encrypted bytes GnuTLS wants to send to the sensor:
int  goodix_tls_client_read  (GoodixTlsServer *self, guint8 *buf, guint16 max_length);

// Decrypt application data (post-handshake image data):
int  goodix_tls_server_read  (GoodixTlsServer *self, guint8 *data,
                               guint32 length, GError **error);

// Advance the handshake one step; returns TRUE when complete, FALSE = AGAIN:
gboolean goodix_tls_handshake_step (GoodixTlsServer *self, GError **error);
```

### New `goodixtls.c` implementation outline

```c
// goodixtls.c — GnuTLS version (~150 lines)

#include <gnutls/gnutls.h>
#include <gnutls/abstract.h>
#include "goodixtls.h"

// ── Transport callbacks (replaces socket pair) ────────────────────────────

static ssize_t
gx_tls_push (gnutls_transport_ptr_t ptr, const void *data, size_t len)
{
  GoodixTlsServer *self = ptr;
  g_byte_array_append (self->out_buf, data, len);
  return (ssize_t) len;
}

static ssize_t
gx_tls_pull (gnutls_transport_ptr_t ptr, void *data, size_t len)
{
  GoodixTlsServer *self = ptr;
  if (self->in_buf->len == 0) {
    gnutls_transport_set_errno (self->session, EAGAIN);
    return -1;
  }
  size_t n = MIN (len, self->in_buf->len);
  memcpy (data, self->in_buf->data, n);
  g_byte_array_remove_range (self->in_buf, 0, n);
  return (ssize_t) n;
}

static int
gx_tls_pull_timeout (gnutls_transport_ptr_t ptr, unsigned ms)
{
  GoodixTlsServer *self = ptr;
  return self->in_buf->len > 0 ? 1 : 0;
}

// ── PSK server callback (same logic: return 32-byte all-zeros key) ────────

static int
gx_psk_server_cb (gnutls_session_t session, const char *username,
                  gnutls_datum_t *key)
{
  const int len = 32;
  key->data = gnutls_malloc (len);
  if (!key->data)
    return GNUTLS_E_MEMORY_ERROR;
  memset (key->data, 0, len);
  key->size = len;
  return 0;
}

// ── Init / deinit ─────────────────────────────────────────────────────────

gboolean
goodix_tls_server_init (GoodixTlsServer *self, GError **error)
{
  self->in_buf  = g_byte_array_new ();
  self->out_buf = g_byte_array_new ();

  gnutls_psk_allocate_server_credentials (&self->creds);
  gnutls_psk_set_server_credentials_function (self->creds, gx_psk_server_cb);

  gnutls_init (&self->session, GNUTLS_SERVER | GNUTLS_NONBLOCK);
  gnutls_credentials_set (self->session, GNUTLS_CRD_PSK, self->creds);
  // TLS 1.2, PSK-DHE only — matches what the sensor negotiates:
  gnutls_priority_set_direct (self->session,
    "NORMAL:-VERS-ALL:+VERS-TLS1.2:-KX-ALL:+DHE-PSK:+PSK", NULL);

  gnutls_transport_set_ptr  (self->session, self);
  gnutls_transport_set_push_function         (self->session, gx_tls_push);
  gnutls_transport_set_pull_function         (self->session, gx_tls_pull);
  gnutls_transport_set_pull_timeout_function (self->session, gx_tls_pull_timeout);

  return TRUE;
}

gboolean
goodix_tls_server_deinit (GoodixTlsServer *self, GError **error)
{
  gnutls_bye (self->session, GNUTLS_SHUT_RDWR);
  gnutls_deinit (self->session);
  gnutls_psk_free_server_credentials (self->creds);
  g_byte_array_free (self->in_buf,  TRUE);
  g_byte_array_free (self->out_buf, TRUE);
  return TRUE;
}

// ── Data path ─────────────────────────────────────────────────────────────

void
goodix_tls_client_write (GoodixTlsServer *self, const guint8 *data, guint16 length)
{
  g_byte_array_append (self->in_buf, data, length);
}

int
goodix_tls_client_read (GoodixTlsServer *self, guint8 *buf, guint16 max_length)
{
  guint16 n = MIN (max_length, self->out_buf->len);
  if (n == 0) return 0;
  memcpy (buf, self->out_buf->data, n);
  g_byte_array_remove_range (self->out_buf, 0, n);
  return n;
}

int
goodix_tls_server_read (GoodixTlsServer *self, guint8 *data,
                        guint32 length, GError **error)
{
  int ret = gnutls_record_recv (self->session, data, length);
  if (ret < 0)
    g_set_error (error, G_IO_ERROR, G_IO_ERROR_FAILED,
                 "GnuTLS record recv: %s", gnutls_strerror (ret));
  return ret;
}

gboolean
goodix_tls_handshake_step (GoodixTlsServer *self, GError **error)
{
  int ret = gnutls_handshake (self->session);
  if (ret == GNUTLS_E_AGAIN || ret == GNUTLS_E_INTERRUPTED)
    return FALSE;   // need more data — caller advances FpiSsm
  if (ret < 0) {
    g_set_error (error, G_IO_ERROR, G_IO_ERROR_FAILED,
                 "TLS handshake failed: %s", gnutls_strerror (ret));
    return FALSE;
  }
  return TRUE;  // handshake complete
}
```

### Changes to `goodix.c` (minimal)

The `tls_handshake_run` SSM in `goodix.c` already has the right structure. The only change
is replacing calls to `goodix_tls_client_read/write` with the GnuTLS-aware versions, and
replacing the `pthread_create` → `goodix_tls_ready` callback sequence with a call to
`goodix_tls_handshake_step()` at the end of each state that fed new bytes in.

Specifically, after `goodix_tls_client_write(data, length)`, call:
```c
GError *err = NULL;
if (goodix_tls_handshake_step(priv->tls_hop, &err)) {
  // handshake done — advance SSM
} else if (err) {
  fpi_ssm_mark_failed(ssm, err);
} else {
  // AGAIN — read more from sensor (next SSM state)
  fpi_ssm_next_state(ssm);
}
```

The `#include <pthread.h>` at the top of `goodix.c` is removed completely.

---

## Phase 3 — SIGFM → NBIS (decision after Phase 1)

### If NBIS works (≥15 minutiae at 4x upscale)

1. Remove `subdir('sigfm')` from `libfprint/meson.build`
2. Remove `libsigfm` from `link_with` and `priv_deps`
3. Remove `install_headers` for `sigfm/sigfm.h`
4. In `goodix5xx.c`, replace the `sigfm_extract()` + `sigfm_match_score()` calls with
   `fpi_image_device_image_captured()` — let libfprint's built-in NBIS pipeline do the work
5. Remove `sigfm/` directory

The goodixtls driver becomes a pure `FpImageDevice` subclass — it captures images and hands
them to libfprint core. Enroll/verify/identify work automatically.

### If NBIS fails (pure-C SIFT replacement needed)

Replace the 3 OpenCV calls with a self-contained C implementation:

```
sigfm/sigfm.cpp  (C++ + OpenCV, 200 lines)
    ↓ becomes
sigfm/sigfm.c    (pure C, ~500 lines)
```

The replacement algorithm: **ORB** (Oriented FAST + BRIEF descriptor) is patent-free,
MIT-licensed, and has published simple C implementations. It produces binary descriptors
matchable with Hamming distance — faster to compute and match than SIFT, and the 80×88
image is so small that computational cost is not a concern either way.

ORB reference: "ORB: an efficient alternative to SIFT or SURF" (Rublee et al., 2011).
C reference implementation: `fast-cpp-9-implementation` + BRIEF descriptor (~400 lines).

The `sigfm/meson.build` then becomes:
```meson
libsigfm = static_library('sigfm',
    ['sigfm.c'],
    # no opencv, no doctest, no cpp_std
)
```

---

## Phase 4 — Build System (`meson.build`)

This directly mirrors how upstream handles the `nss` helper for `uru4000`:

### Root `meson.build` changes

**1. Remove `cpp_std=c++17` from `project()` default_options** (once sigfm is pure C).

**2. Replace the `goodixtls` helper block** (lines 224–235 currently):

```meson
# Before:
elif i == 'goodixtls'
    openssl_dep = dependency('openssl', required: false)
    if not openssl_dep.found()
        error('openssl is required for @0@ and possibly others'.format(driver))
    endif
    optional_deps += openssl_dep

    threads_dep = dependency('threads', required: false)
    if not threads_dep.found()
        error('threads is required for @0@ and possibly others'.format(driver))
    endif
    optional_deps += threads_dep

# After:
elif i == 'goodixtls'
    gnutls_dep = dependency('gnutls', version: '>= 3.6.0', required: get_option('goodixtls'))
    if not gnutls_dep.found()
        error('gnutls >= 3.6.0 is required for @0@'.format(driver))
    endif
    optional_deps += gnutls_dep
```

**3. Add a build option** so packagers can explicitly enable/disable the driver:

```meson
# In meson_options.txt, add:
option('goodixtls', type: 'feature', value: 'auto',
    description: 'Enable Goodix TLS sensor support (requires GnuTLS)')
```

This follows the exact pattern of the upstream `introspection`, `gtk-examples`, `doc` options.

### `libfprint/meson.build` changes

The `helper_sources` entry for `goodixtls` doesn't change — the same 4 files, just with
GnuTLS inside instead of OpenSSL:

```meson
'goodixtls' :
    [ 'drivers/goodixtls/goodix_proto.c',
      'drivers/goodixtls/goodix.c',
      'drivers/goodixtls/goodixtls.c',
      'drivers/goodixtls/goodix5xx.c' ],
```

Remove sigfm integration:
```meson
# Remove:
subdir('sigfm')
# ...
priv_deps = deps + libsigfm
# ...
link_with: [libnbis, libsigfm],
# ...
install_headers(['sigfm/sigfm.h'], subdir: versioned_libname + '/sigfm')

# After (sigfm gone, NBIS path):
priv_deps = deps
# ...
link_with: [libnbis],
```

### `project()` languages

Once sigfm is pure C, remove `'cpp'` from the `project()` languages list:
```meson
# Before:
project('libfprint', [ 'c', 'cpp' ], ...)

# After:
project('libfprint', [ 'c' ], ...)
```

This is significant for upstream: a fingerprint library having C++ in its build
is unusual and will be questioned in MR review.

---

## Phase 5 — Thermal Fix (1 line)

Revert our `fp-device-private.h` change (Bug 3 fix). Instead, set it per-driver in
`goodix5xx.c` or `goodix511.c` class_init, following `goodixmoc`'s exact pattern:

```c
// In fpi_device_goodixtls511_class_init (goodix511.c):
dev_class->temp_hot_seconds = -1;  // sensor has no overcurrent risk; disable thermal model
```

This is the correct upstream approach. The global default stays at 3 minutes (fine for all
other drivers). Our fork's test environment just happens to need a longer timeout.

---

## Phase 6 — Upstream Submission Checklist

Before opening a GitLab MR:

- [ ] Builds clean with `-Werror` on GCC 11, GCC 14, and Clang 16
- [ ] No `-Wno-error=incompatible-pointer-types` flag needed (fix the underlying casts)
- [ ] `meson setup build -Dintrospection=false -Ddoc=false && ninja -C build` works from clean
- [ ] `ninja -C build test` passes (at least the SSM and device unit tests)
- [ ] No C++ files in the driver (pure C)
- [ ] No OpenSSL, no pthreads, no OpenCV
- [ ] GnuTLS is an optional dep (`-Dgoodixtls=disabled` builds without it)
- [ ] `temp_hot_seconds = -1` set in driver class, not global default
- [ ] VID/PID table includes all known 51xx variants: 5110, 5117, 5120, 521d
- [ ] udev rules include 27c6:5110 (and other 51xx PIDs)
- [ ] GTK-Doc for any new public-facing symbols (there should be none — all driver-internal)
- [ ] Commit messages reference the firmware requirement and the TLS protocol

---

## Build and Install Process (Streamlined)

Following upstream conventions, the full build from a clean checkout should be:

```bash
# One-time: create build directory with options matching upstream packaging
meson setup build \
    --prefix=/usr \
    --buildtype=release \
    -Ddoc=false \
    -Dintrospection=false \
    -Dgtk-examples=false \
    -Dgoodixtls=enabled

# Build
ninja -C build

# Test
ninja -C build test

# Install (replaces system libfprint)
sudo ninja -C build install
sudo ldconfig
```

The `-Dgoodixtls=enabled` explicitly requires GnuTLS. Without it, `auto` mode silently
disables the driver if GnuTLS is not present — correct for a distro building libfprint for
hardware it may not have, but we want to fail loudly during development.

For the Ubuntu 22.04 devcontainer, the only additional setup is the `udev.pc` shim (the
container doesn't have a real udev, so the shim is needed for meson to find libudev):

```bash
cp /usr/lib/x86_64-linux-gnu/pkgconfig/libudev.pc /usr/local/lib/pkgconfig/udev.pc
sed -i 's/^Name: libudev/Name: udev/' /usr/local/lib/pkgconfig/udev.pc
```

No other special flags. No `doctest.pc` shim needed once sigfm is gone (doctest was only
used by sigfm's test suite).

---

## Precedents in Upstream Tree

The following upstream patterns are directly applicable:

| Pattern | Where it's used | How we use it |
|---|---|---|
| `helper_sources` for shared driver code | `goodixmoc`, `uru4000`, `synaptics` | `goodixtls` helper = 4 shared files |
| Optional dep per helper | `nss` for `uru4000`, `udev` for `elanspi` | `gnutls` for `goodixtls` |
| `temp_hot_seconds = -1` | `goodixmoc` (line from class_init) | Same, in goodix511 class_init |
| `FpImageDevice` subclass | `elan`, `aes*`, many others | goodixtls511 stays FpImageDevice |
| `-Dfeature=enabled/auto/disabled` | `introspection`, `gtk-examples` | `-Dgoodixtls=auto` |
| Pure C, no C++ | All upstream drivers | Remove cpp from project() |

The `uru4000` driver is the closest existing precedent for "a driver that needs a
crypto library for USB communication" — it uses NSS. The upstream already accepted
that pattern. GnuTLS is a smaller ask than NSS (lighter, more common, fully
LGPL-compatible).

---

## File Change Map

```
libfprint/drivers/goodixtls/
    goodixtls.h          REWRITE  (~110 lines; GnuTLS struct + API)
    goodixtls.c          REWRITE  (~150 lines; GnuTLS transport, no pthread)
    goodix.c             MODIFY   (~20 lines; remove pthread.h include;
                                   replace handshake inline calls)
    goodix511.c          MODIFY   (1 line: temp_hot_seconds = -1)
    goodix.h             UNCHANGED
    goodix5xx.c          MODIFY   (if NBIS: remove sigfm calls, use
                                   fpi_image_device_image_captured)
    goodix5xx.h          MODIFY   (remove sigfm.h include if NBIS)
    goodix_proto.c/.h    UNCHANGED

libfprint/sigfm/
    (directory)          DELETE   (if NBIS works)
                         MODIFY   (if pure-C SIFT: rewrite sigfm.cpp → sigfm.c,
                                   update meson.build)

meson.build (root)
    project()            MODIFY   remove cpp_std=c++17, remove 'cpp' language
    goodixtls block      REWRITE  openssl+threads → gnutls
    meson_options.txt    ADD      option('goodixtls', type: 'feature', value: 'auto')

libfprint/meson.build
    sigfm subdir         REMOVE
    priv_deps            MODIFY   remove libsigfm
    link_with            MODIFY   remove libsigfm
    install_headers      REMOVE   (sigfm/sigfm.h)

libfprint/fp-device-private.h
    DEFAULT_TEMP_HOT_SECONDS   REVERT our change (back to 3*60)
    DEFAULT_TEMP_COLD_SECONDS  REVERT our change (back to 9*60)
```

---

## Implementation Order

1. **Phase 1**: NBIS test — 1 day. Determines Phase 3 scope.
2. **Phase 2**: GnuTLS migration — 2–3 days. Independent of Phase 1.
3. **Phase 4**: Build system — 0.5 days. Do alongside Phase 2/3.
4. **Phase 3**: SIGFM decision — 1 day (NBIS) or 3–4 days (pure-C ORB).
5. **Phase 5**: Thermal fix — 30 minutes.
6. **Phase 6**: Upstream checklist — 1–2 days of cleanup.

**Total: 6–10 days of focused work.**
