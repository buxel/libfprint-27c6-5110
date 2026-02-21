# 06 — Upstream libfprint Driver Structure & Out-of-Tree Feasibility

**Date:** 2026-02-16  
**Purpose:** Detailed research on how drivers are structured in upstream libfprint, whether out-of-tree/external drivers are feasible, and what the goodixmoc reference driver looks like.

**Sources Used:**
- `sources.debian.org` — libfprint 1.94.10-1 (Debian sid/forky) — full source access
- `fprint.freedesktop.org/libfprint-dev/` — Official API documentation (GTK-Doc)
- `fprint.freedesktop.org` — Project homepage and supported devices list
- GitLab (freedesktop.org) was **blocked by Anubis bot protection** — could not access directly
- `github.com/nickel-lang/libfprint` — **DOES NOT EXIST** (nickel-lang is an unrelated Nickel config language org)

---

## 1. Upstream Version & Package Metadata

| Property | Value |
|----------|-------|
| **Version** | `1.94.10` |
| **License** | `LGPLv2.1+` |
| **Build system** | Meson (≥ 0.59.0) |
| **Languages** | C (`gnu99`), C++ |
| **Codebase size** | 27,720 KB; SLOC: 70,874 C; 2,228 Python; 318 XML |
| **GLib min version** | 2.68 |
| **Dependencies** | glib-2.0, gio-unix-2.0, gobject-2.0, gusb (≥ 0.2.0), libm |
| **Optional deps** | pixman-1 (for AES drivers), OpenSSL ≥ 3.0 (for uru4000), gudev-1.0 (for SPI), gobject-introspection |
| **SO version** | 2 (libfprint-2.so) |

---

## 2. Complete Driver List (1.94.10)

### Default Drivers (compiled by default)

| Driver ID | Description | Bus | Structure |
|-----------|-------------|-----|-----------|
| `upekts` | UPEK TouchStrip | USB | 2 files: `upekts.c`, `upek_proto.c` |
| `upektc` | UPEK TouchChip | USB | 1 file: `upektc.c` |
| `upeksonly` | UPEK TouchStrip Sensor-Only | USB | 1 file: `upeksonly.c` |
| `upektc_img` | UPEK TouchChip (imaging) | USB | 2 files: `upektc_img.c`, `upek_proto.c` |
| `uru4000` | Digital Persona U.are.U 4000 | USB | 1 file: `uru4000.c` (needs OpenSSL) |
| `aes1610` | AuthenTec AES1610 | USB | 1 file (+ aeslib helper) |
| `aes1660` | AuthenTec AES1660 | USB | 1 file (+ aeslib, aesx660 helpers) |
| `aes2501` | AuthenTec AES2501 | USB | 1 file (+ aeslib helper) |
| `aes2550` | AuthenTec AES2550 | USB | 1 file (+ aeslib helper) |
| `aes2660` | AuthenTec AES2660 | USB | 1 file (+ aeslib, aesx660 helpers) |
| `aes3500` | AuthenTec AES3500 | USB | 1 file (+ aeslib, aes3k helpers; needs pixman) |
| `aes4000` | AuthenTec AES4000 | USB | 1 file (+ aeslib, aes3k helpers; needs pixman) |
| `vcom5s` | Veridicom 5thSense | USB | 1 file |
| `vfs101` | Validity VFS101 | USB | 1 file |
| `vfs301` | Validity VFS301 | USB | 2 files: `vfs301.c`, `vfs301_proto.c` |
| `vfs0050` | Validity VFS0050 | USB | 1 file |
| `vfs5011` | Validity VFS5011 | USB | 1 file |
| `vfs7552` | Validity VFS7552 | USB | 1 file |
| `etes603` | EgisTec ES603 | USB | 1 file |
| `egis0570` | EgisTec 0570 | USB | 1 file |
| `egismoc` | EgisTec MOC | USB | **Subdirectory**: `egismoc/egismoc.c` |
| `elan` | ElanTech | USB | 1 file |
| `elanmoc` | Elan MOC | USB | **Subdirectory**: `elanmoc/elanmoc.c` |
| `synaptics` | Synaptics | USB | **Subdirectory**: `synaptics/synaptics.c`, `bmkt_message.c` |
| **`goodixmoc`** | **Goodix MOC** | **USB** | **Subdirectory**: `goodixmoc/goodix.c`, `goodix_proto.c` |
| `nb1010` | NextBiometrics NB-1010 | USB | 1 file |
| `fpcmoc` | FPC MOC | USB | **Subdirectory**: `fpcmoc/fpc.c` |
| `realtek` | Realtek MOC | USB | **Subdirectory**: `realtek/realtek.c` |
| `focaltech_moc` | Focaltech MOC | USB | **Subdirectory**: `focaltech_moc/focaltech_moc.c` |

### SPI Drivers (Linux only)

| Driver ID | Description | Structure |
|-----------|-------------|-----------|
| `elanspi` | ElanTech Embedded | 1 file (+ udev helper; needs gudev) |

### Virtual Drivers (testing/development)

| Driver ID | Description |
|-----------|-------------|
| `virtual_image` | Virtual image device |
| `virtual_device` | Virtual device |
| `virtual_device_storage` | Virtual device with storage |

### Total: ~30 drivers in the default build

---

## 3. Driver Registration Mechanism — COMPILE-TIME ONLY

### 3.1 How Drivers Are Registered

**There is NO plugin/runtime discovery mechanism.** Drivers are registered at **compile time** through generated C code.

The `libfprint/meson.build` contains this critical code block:

```meson
# Export the drivers' types to the core code
drivers_type_list = []
drivers_type_func = []
drivers_type_list += '#include <glib-object.h>'
drivers_type_list += '#include "fpi-context.h"'
drivers_type_list += ''
drivers_type_func += 'GArray *'
drivers_type_func += 'fpi_get_driver_types (void)'
drivers_type_func += '{'
drivers_type_func += '  GArray *drivers = g_array_new (TRUE, FALSE, sizeof (GType));'
drivers_type_func += '  GType t;'
drivers_type_func += ''
foreach driver: supported_drivers
    drivers_type_list += 'extern GType (fpi_device_' + driver + '_get_type) (void);'
    drivers_type_func += '  t = fpi_device_' + driver + '_get_type ();'
    drivers_type_func += '  g_array_append_val (drivers, t);'
    drivers_type_func += ''
endforeach
drivers_type_list += ''
drivers_type_func += '  return drivers;'
drivers_type_func += '}'

drivers_sources += configure_file(input: 'empty_file',
    output: 'fpi-drivers.c',
    capture: true,
    command: [
        'echo',
        '\n'.join(drivers_type_list + [] + drivers_type_func)
    ])
```

### 3.2 What This Generates

At build time, Meson generates `fpi-drivers.c`, which looks like this:

```c
#include <glib-object.h>
#include "fpi-context.h"

extern GType (fpi_device_upekts_get_type) (void);
extern GType (fpi_device_goodixmoc_get_type) (void);
// ... one line per driver ...

GArray *
fpi_get_driver_types (void)
{
  GArray *drivers = g_array_new (TRUE, FALSE, sizeof (GType));
  GType t;

  t = fpi_device_upekts_get_type ();
  g_array_append_val (drivers, t);

  t = fpi_device_goodixmoc_get_type ();
  g_array_append_val (drivers, t);

  // ... one block per driver ...

  return drivers;
}
```

### 3.3 Implications for Out-of-Tree Drivers

**This is the fundamental blocker for out-of-tree drivers:**

1. **Each driver must expose a GObject `_get_type()` function** — this is the GObject type registration function
2. **The `fpi-drivers.c` file is auto-generated** at build time from the `supported_drivers` list
3. **The `fpi_get_driver_types()` function is the ONLY way** drivers are discovered by `FpContext`
4. **There is no `dlopen()`, no plugin directory scan, no runtime loading mechanism whatsoever**
5. **The driver is compiled into a static library** (`libfprint-drivers`) which is **statically linked** into the final shared library (`libfprint-2.so`)

### 3.4 Build Linkage Chain

```
drivers_sources (per-driver .c files)
    ↓ compiled into
static_library('fprint-drivers')
    ↓ statically linked with
static_library('fprint-private')
    ↓ all linked into
shared_library('fprint-2')    ← This is libfprint-2.so
```

All three static libraries are linked together into the single `libfprint-2.so`. **There is no separate .so per driver.**

---

## 4. Does libfprint Support Out-of-Tree / External Drivers?

### Answer: **NO — categorically not.**

Evidence:
1. **No plugin API exists** — the `fpi_get_driver_types()` function is compile-time generated
2. **No dlopen/plugin loading code** anywhere in the codebase
3. **The driver API is explicitly marked as unstable** — from the docs: *"This API is solely intended for drivers. It is purely internal and neither API nor ABI stable."*
4. **The HACKING.md** does not mention any out-of-tree mechanism
5. **Driver headers are private** — they are not installed (only public API headers like `fp-context.h`, `fp-device.h`, etc. are installed)

### What This Means for goodixtls

To add the goodixtls driver, you **must** either:
1. **Fork libfprint and compile a custom version** — this is what the AUR package does
2. **Submit upstream** — get the driver merged into the official tree
3. **Hack a pseudo-plugin mechanism** — theoretically possible by patching `fpi-drivers.c` generation or `FpContext`, but fragile and unsupported

**Option 1 (fork) is the only practical approach** for community drivers that upstream won't accept.

---

## 5. HACKING.md — Full Contribution Guidelines

### Contents (from upstream 1.94.10):

```markdown
# Contributing to libfprint

## GLib
Although the library uses GLib internally, libfprint is designed to provide
a completely neutral interface to its application users. So, the public
APIs should never return GLib data types.

## License clarification
Although this library's license could allow for shims that hook
up into proprietary blobs to add driver support for some unsupported devices,
the intent of the original authors, and of current maintainers of the library,
was for this license to allow _integration into_ proprietary stacks,
not _integration of_ proprietary code in the library.

As such, no code to integrate proprietary drivers will be accepted in libfprint
upstream. Proprietary drivers would make it impossible to debug problems in
libfprint, as we wouldn't know what the proprietary driver does behind the
library's back.
```

Key policy points:
- **No proprietary driver shims** will be accepted upstream
- Contributors are encouraged to **reverse-engineer** proprietary protocols to create open-source drivers
- **Two APIs**: external (for apps) and internal (for drivers); the prefix `fpi_` marks internal functions
- **All public API additions must have gtk-doc comments**
- Patches go via **GitLab merge requests**: `https://gitlab.freedesktop.org/libfprint/libfprint/merge_requests`

### Driver contribution requirements:
> Drivers are not usually written by libfprint developers, but when they are, we require:
> - 3 stand-alone devices. Not in a laptop or another embedded device
> - specifications of the protocol

### Coding Standards
- Build system enforces **strict warnings** (`-Werror=...` for many categories)
- C standard: **gnu99**
- GLib version defines enforced: `GLIB_VERSION_MIN_REQUIRED` / `GLIB_VERSION_MAX_ALLOWED`
- **No mention of uncrustify** in HACKING.md or meson.build — the project does NOT appear to use an automated code formatter (unlike, say, GNOME projects that use clang-format)
- Compile flags include strict `-Wmissing-prototypes`, `-Wstrict-prototypes`, `-Werror=redundant-decls`, etc.

---

## 6. The goodixmoc Reference Driver — Detailed Structure

### 6.1 File Listing

The `goodixmoc` driver is in `libfprint/drivers/goodixmoc/`:

| File | Size | Purpose |
|------|------|---------|
| `goodix.c` | 51,471 bytes | Main driver implementation — all operations |
| `goodix.h` | 1,812 bytes | State machine enums, GObject type declaration |
| `goodix_proto.c` | 16,200 bytes | Protocol encoding/decoding, CRC8/CRC32, packet building/parsing |
| `goodix_proto.h` | 6,491 bytes | Protocol structures, command constants, message types |

**Total: 4 files (2 .c + 2 .h), ~76 KB total**

### 6.2 meson.build Registration

In `libfprint/meson.build`:
```meson
driver_sources = {
    ...
    'goodixmoc' :
        [ 'drivers/goodixmoc/goodix.c', 'drivers/goodixmoc/goodix_proto.c' ],
    ...
}
```

In root `meson.build`, it's in the `default_drivers` list:
```meson
default_drivers = [
    ...
    'goodixmoc',
    ...
]
```

**No helper_sources needed** — the goodixmoc driver is entirely self-contained with no shared modules.

### 6.3 Driver Architecture

Unlike the goodixtls community driver (which subclasses `FpImageDevice`), the upstream **goodixmoc driver subclasses `FpDevice` directly**:

```c
struct _FpiDeviceGoodixMoc
{
  FpDevice           parent;         // Direct FpDevice subclass, NOT FpImageDevice!
  FpiSsm            *task_ssm;
  FpiSsm            *cmd_ssm;
  FpiUsbTransfer    *cmd_transfer;
  gboolean           cmd_cancelable;
  pgxfp_sensor_cfg_t sensorcfg;
  gint               enroll_stage;
  gint               max_enroll_stage;
  gint               max_stored_prints;
  GPtrArray         *list_result;
  guint8             template_id[TEMPLATE_ID_SIZE];
  gboolean           is_power_button_shield_on;
};

G_DEFINE_TYPE (FpiDeviceGoodixMoc, fpi_device_goodixmoc, FP_TYPE_DEVICE)
```

**Key distinction**: MOC (Match-On-Chip) drivers subclass `FpDevice` directly because matching happens in the sensor firmware. Image-based drivers (like goodixtls would be) subclass `FpImageDevice` because they capture raw images for the host to match.

### 6.4 Class Initialization — How Operations Are Registered

```c
static void
fpi_device_goodixmoc_class_init (FpiDeviceGoodixMocClass *klass)
{
  FpDeviceClass *dev_class = FP_DEVICE_CLASS (klass);

  dev_class->id = "goodixmoc";
  dev_class->full_name = "Goodix MOC Fingerprint Sensor";
  dev_class->type = FP_DEVICE_TYPE_USB;
  dev_class->scan_type = FP_SCAN_TYPE_PRESS;
  dev_class->id_table = id_table;
  dev_class->nr_enroll_stages = DEFAULT_ENROLL_SAMPLES;  // 8
  dev_class->temp_hot_seconds = -1;  // Always-on OK

  dev_class->open   = gx_fp_init;
  dev_class->close  = gx_fp_exit;
  dev_class->probe  = gx_fp_probe;
  dev_class->enroll = gx_fp_enroll;
  dev_class->delete = gx_fp_template_delete;
  dev_class->clear_storage = gx_fp_template_delete_all;
  dev_class->list   = gx_fp_template_list;
  dev_class->verify   = gx_fp_verify_identify;
  dev_class->identify = gx_fp_verify_identify;

  fpi_device_class_auto_initialize_features (dev_class);
  dev_class->features |= FP_DEVICE_FEATURE_DUPLICATES_CHECK;
}
```

### 6.5 USB VID/PID Table

All devices use vendor ID `0x27c6` (Goodix Technology):

```c
static const FpIdEntry id_table[] = {
  { .vid = 0x27c6,  .pid = 0x5840,  },
  { .vid = 0x27c6,  .pid = 0x6014,  },
  { .vid = 0x27c6,  .pid = 0x6092,  },
  { .vid = 0x27c6,  .pid = 0x6094,  },
  { .vid = 0x27c6,  .pid = 0x609A,  },
  { .vid = 0x27c6,  .pid = 0x609C,  },
  { .vid = 0x27c6,  .pid = 0x60A2,  },
  { .vid = 0x27c6,  .pid = 0x60A4,  },
  { .vid = 0x27c6,  .pid = 0x60BC,  },
  { .vid = 0x27c6,  .pid = 0x60C2,  },
  { .vid = 0x27c6,  .pid = 0x6304,  },
  { .vid = 0x27c6,  .pid = 0x631C,  },
  { .vid = 0x27c6,  .pid = 0x633C,  },
  { .vid = 0x27c6,  .pid = 0x634C,  },
  { .vid = 0x27c6,  .pid = 0x6384,  },
  { .vid = 0x27c6,  .pid = 0x639C,  },
  { .vid = 0x27c6,  .pid = 0x63AC,  },
  { .vid = 0x27c6,  .pid = 0x63BC,  },
  { .vid = 0x27c6,  .pid = 0x63CC,  },
  { .vid = 0x27c6,  .pid = 0x6496,  },
  { .vid = 0x27c6,  .pid = 0x650A,  },
  { .vid = 0x27c6,  .pid = 0x650C,  },
  { .vid = 0x27c6,  .pid = 0x6582,  },
  { .vid = 0x27c6,  .pid = 0x6584,  },
  { .vid = 0x27c6,  .pid = 0x658C,  },
  { .vid = 0x27c6,  .pid = 0x6592,  },
  { .vid = 0x27c6,  .pid = 0x6594,  },
  { .vid = 0x27c6,  .pid = 0x659A,  },
  { .vid = 0x27c6,  .pid = 0x659C,  },
  { .vid = 0x27c6,  .pid = 0x6A94,  },
  { .vid = 0x27c6,  .pid = 0x6512,  },
  { .vid = 0x27c6,  .pid = 0x689A,  },
  { .vid = 0x27c6,  .pid = 0x66A9,  },
  { .vid = 0,  .pid = 0,  .driver_data = 0 },   /* terminating entry */
};
```

**Note:** PID `0x5110` (the MateBook 14 AMD 2020 sensor) is **NOT in this list**. The `goodixmoc` driver does NOT support it. The 5110 requires a TLS-based protocol (goodixtls), not the MOC protocol.

### 6.6 Operational Pattern — State Machine (SSM)

The driver uses `FpiSsm` (Sequential State Machine) extensively:

**Init sequence** (on open):
```
GOODIX_INIT_VERSION → GOODIX_INIT_CONFIG → GOODIX_INIT_TEMPLATE_LIST → [GOODIX_INIT_RESET_DEVICE]
```

**Enroll sequence:**
```
GOODIX_ENROLL_PWR_BTN_SHIELD_ON → GOODIX_ENROLL_ENUM → GOODIX_ENROLL_CREATE →
GOODIX_ENROLL_CAPTURE → GOODIX_ENROLL_UPDATE → GOODIX_ENROLL_WAIT_FINGER_UP →
GOODIX_ENROLL_CHECK_DUPLICATE → GOODIX_ENROLL_COMMIT → GOODIX_ENROLL_PWR_BTN_SHIELD_OFF
```

**Verify sequence:**
```
GOODIX_VERIFY_PWR_BTN_SHIELD_ON → GOODIX_VERIFY_CAPTURE → GOODIX_VERIFY_IDENTIFY →
GOODIX_VERIFY_PWR_BTN_SHIELD_OFF
```

**Command sub-SSM** (for each USB command):
```
GOODIX_CMD_SEND → GOODIX_CMD_GET_ACK → GOODIX_CMD_GET_DATA
```

### 6.7 Key APIs Used by goodixmoc

| API | Source | Purpose |
|-----|--------|---------|
| `G_DEFINE_TYPE()` | GObject | Type registration macro |
| `FpDeviceClass` vfuncs | `fpi-device.h` | Driver operation callbacks |
| `FpIdEntry` | `fpi-device.h` | USB VID/PID table |
| `FpiSsm` / `fpi_ssm_new()` / `fpi_ssm_start()` | `fpi-ssm.h` | State machine management |
| `FpiUsbTransfer` / `fpi_usb_transfer_*()` | `fpi-usb-transfer.h` | USB bulk transfers |
| `fpi_device_get_usb_device()` | `fpi-device.h` | Get GUsbDevice handle |
| `fpi_device_probe_complete()` | `fpi-device.h` | Finish probe |
| `fpi_device_open_complete()` | `fpi-device.h` | Finish open |
| `fpi_device_close_complete()` | `fpi-device.h` | Finish close |
| `fpi_device_enroll_complete()` | `fpi-device.h` | Finish enrollment |
| `fpi_device_verify_complete()` | `fpi-device.h` | Finish verification |
| `fpi_device_verify_report()` | `fpi-device.h` | Report verify result |
| `fpi_device_identify_complete()` | `fpi-device.h` | Finish identification |
| `fpi_device_identify_report()` | `fpi-device.h` | Report identify result |
| `fpi_device_delete_complete()` | `fpi-device.h` | Finish delete |
| `fpi_device_list_complete()` | `fpi-device.h` | Finish listing stored prints |
| `fpi_device_clear_storage_complete()` | `fpi-device.h` | Finish storage clear |
| `fpi_device_enroll_progress()` | `fpi-device.h` | Report enroll stage progress |
| `fpi_device_set_nr_enroll_stages()` | `fpi-device.h` | Dynamic enroll stage count |
| `fpi_device_report_finger_status_changes()` | `fpi-device.h` | Finger on/off reporting |
| `fpi_device_error_new()` / `fpi_device_retry_new()` | `fpi-device.h` | Error construction |
| `fpi_device_class_auto_initialize_features()` | `fpi-device.h` | Auto-detect features from vfuncs |
| `fpi_print_set_type()` / `fpi_print_set_device_stored()` | `fpi-print.h` | Print metadata |
| `fpi_print_generate_user_id()` | `fpi-print.h` | Generate user ID |
| `fpi_print_fill_from_user_id()` | `fpi-print.h` | Fill print from user ID |
| `FpiByteReader` | `fpi-byte-reader.h` | Protocol packet parsing |
| `drivers_api.h` | libfprint internal | Umbrella include for all driver APIs |

### 6.8 External Dependencies

The goodixmoc driver has **ZERO external dependencies** beyond what libfprint itself provides (GLib, GUsb). This contrasts with goodixtls which needs OpenSSL and pthreads.

---

## 7. Comparison: goodixmoc vs. goodixtls Architecture

| Aspect | goodixmoc (upstream) | goodixtls (community fork) |
|--------|---------------------|---------------------------|
| **Superclass** | `FpDevice` (direct) | `FpImageDevice` (via chain) |
| **Sensor type** | Match-On-Chip (MOC) | Image-based + TLS |
| **Files** | 4 (2 .c + 2 .h) | 10 (5 .c + 5 .h) |
| **Total size** | ~76 KB | ~40+ KB |
| **Inheritance** | FpDevice → FpiDeviceGoodixMoc | FpDevice → FpImageDevice → FpiDeviceGoodixTls → FpiDeviceGoodixTls5xx → FpiDeviceGoodixTls511 |
| **Matching** | On-chip (sensor firmware) | Host-side (libfprint NBIS/bozorth3) |
| **External deps** | None | OpenSSL + pthreads |
| **TLS** | None needed | Required for sensor communication |
| **Firmware** | Standard | Requires flashing via goodix-fp-dump |
| **Image processing** | No images (templates only) | Raw image capture + assembly |
| **Build integration** | driver_sources only | driver_sources + helper_sources |

### Key Insight

The goodixmoc and goodixtls drivers handle **completely different Goodix sensor families**:
- **goodixmoc**: Sensors with PIDs like 0x5840, 0x6xxx — these have on-chip matching firmware
- **goodixtls**: Sensors with PID 0x5110 — these are image-based sensors requiring TLS-encrypted communication and host-side matching

They share the vendor ID `0x27c6` and the `goodix_proto.*` naming, but the protocols are **completely different**.

---

## 8. Mentions of "goodixtls" or "MOH" in Upstream

### Debian Code Search Result
- **"goodixtls"**: **ZERO results** in the entire Debian archive for the libfprint package
- **"MOH"**: Not present in any upstream libfprint source file

### Supported Devices List
- The Goodix entries on `fprint.freedesktop.org/supported-devices.html` are **all "Goodix MOC Fingerprint Sensor"**
- PID `0x5110` is **NOT listed** as a supported device
- No "goodixtls" or "TLS" variant appears anywhere

### Conclusion
**goodixtls has never been merged upstream and is not referenced anywhere in the upstream codebase.**

---

## 9. Upstream Development Velocity

### What We Can Determine

| Metric | Value | Source |
|--------|-------|--------|
| Release version | 1.94.10 | Debian package, fprint.freedesktop.org |
| Debian package date | Current in Debian sid | sources.debian.org |
| Codebase size | 70,874 SLOC C | Debian metadata |
| Driver count | ~30 | meson.build analysis |
| Recent additions | egismoc, elanmoc, fpcmoc, realtek, focaltech_moc, nb1010 | These are all MOC-pattern drivers, suggesting active development |

### Observations
- The project is **actively maintained** — the 1.94.x series is continuous
- Recent development trend is **MOC drivers** — vendors are shipping match-on-chip sensors and submitting drivers
- The project has added 6+ new MOC drivers since the goodixtls fork was created (~2021-2022)
- GitLab MRs could not be checked due to Anubis bot protection

### Note on Accessing GitLab
The `gitlab.freedesktop.org` instance runs **Anubis anti-bot protection** (JavaScript challenge), which blocks all automated access including fetching tools and CI bots. This is a known issue affecting the entire freedesktop.org GitLab infrastructure.

---

## 10. The FpImageDevice API (for goodixtls-type drivers)

Since goodixtls subclasses `FpImageDevice`, here's the relevant API:

### FpImageDeviceClass

```c
typedef struct {
  FpDeviceClass parent_class;

  gint          bz3_threshold;    // Bozorth3 match threshold (default: 40)
  gint          img_width;        // Image width (0 if dynamic)
  gint          img_height;       // Image height (0 if dynamic)

  void          (*img_open)     (FpImageDevice *dev);
  void          (*img_close)    (FpImageDevice *dev);
  void          (*activate)     (FpImageDevice *dev);
  void          (*change_state) (FpImageDevice *dev, FpiImageDeviceState state);
  void          (*deactivate)   (FpImageDevice *dev);
} FpImageDeviceClass;
```

### Image Device State Machine

```
inactive → activating → idle → await-finger-on → capture → await-finger-off → idle → deactivating → inactive
```

### Completion Functions

| Function | Purpose |
|----------|---------|
| `fpi_image_device_open_complete()` | Report open done |
| `fpi_image_device_close_complete()` | Report close done |
| `fpi_image_device_activate_complete()` | Report activation done |
| `fpi_image_device_deactivate_complete()` | Report deactivation done |
| `fpi_image_device_report_finger_status()` | Report finger on/off |
| `fpi_image_device_image_captured()` | Submit a captured image |
| `fpi_image_device_retry_scan()` | Report scan retry needed |
| `fpi_image_device_set_bz3_threshold()` | Dynamic threshold adjust |

This is the API that the goodixtls driver would use. The libfprint core handles enrollment/verification/identification automatically based on captured images.

---

## 11. Summary & Recommendations

### Key Findings

1. **Out-of-tree drivers are NOT supported** — libfprint has no plugin mechanism. All drivers are compiled in at build time through auto-generated `fpi-drivers.c`.

2. **The driver registration is a compile-time GType enum** — `fpi_get_driver_types()` is generated by Meson and hardcodes all driver type functions.

3. **The goodixmoc driver** (4 files, ~76 KB) is a clean reference for how upstream Goodix drivers work, but it handles MOC sensors (not TLS sensors like the 5110).

4. **goodixtls has zero upstream presence** — not in code, not in issues (that we can access), not in the supported devices list.

5. **The coding standards are implicit** — strict compiler warnings enforced, GTK-Doc required for public API, but no automated formatter like uncrustify.

6. **The upstream project actively adds drivers** but requires 3 standalone devices + protocol specifications for maintainer-written drivers. Community contributions via MR are welcome.

7. **The only viable approach for goodixtls is a custom libfprint build** — either forking upstream or submitting as an MR.

### Strategic Options (Updated)

| Option | Feasibility | Effort | Maintenance |
|--------|-------------|--------|-------------|
| **A. Use existing AUR fork (1.94.5)** | Works now | Low | None (abandoned) |
| **B. Rebase goodixtls onto upstream 1.94.10** | High | Medium | Must track upstream |
| **C. Submit goodixtls as upstream MR** | Uncertain | High | Upstream maintains |
| **D. Build out-of-tree plugin mechanism** | Very Low | Very High | Fragile, unsupported |

**Option B is the recommended path**: take the 10 goodixtls driver files from the 0x00002a fork, port them to build against libfprint 1.94.10's internal APIs, add to `meson.build`, and distribute as a custom-built libfprint package.
