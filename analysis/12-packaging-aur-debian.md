# Packaging Analysis — AUR and Debian/Ubuntu

## Summary

The driver has no OpenSSL, no opencv, no pthreads, no doctest. The dependency
footprint is minimal and maps cleanly to official packages on both Arch and Debian.
The only distro-specific friction is a pkg-config name mismatch for `udev` on Debian.

---

## AUR

### PKGBUILD shape

```bash
pkgname=libfprint-goodixtls511-git
provides=('libfprint' 'libfprint-2.so=2-64')
conflicts=('libfprint' 'libfprint-goodixtls-git')
replaces=('libfprint-goodixtls-git')
```

`provides=('libfprint-2.so=2-64')` is critical — it satisfies the binary-level
`depends` that `fprintd`, `pam-fprint-grosshack`, etc. declare on the `.so` directly.
Without it, pacman may refuse to install those packages after a swap.

### Dependencies

| Array | Packages |
|---|---|
| `depends` | `libgusb`, `gnutls`, `libgudev` |
| `makedepends` | `git`, `meson`, `pkgconf` |
| `optdepends` | `fprintd: D-Bus daemon for fingerprint management` |

No `openssl`, `opencv`, `doctest`, `cmake`, `nss`, `pixman`, `gobject-introspection`,
or `gtk-doc` — all were dependencies of the old OpenCV/C++ sigfm stack.

### `pkgver()` function

Standard pattern for `-git` packages:
```bash
pkgver() {
    cd "$pkgname"
    printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}
```

### `build()` function

```bash
build() {
    cd "${srcdir}/${pkgname}"
    meson setup build \
        --buildtype=release \
        --prefix=/usr \
        -Ddoc=false \
        -Dgtk-examples=false \
        -Dintrospection=false \
        -Dgoodixtls=enabled \
        -Dc_args="-Wno-error=incompatible-pointer-types"
    ninja -C build
}
```

`--prefix=/usr` is essential — without it meson defaults to `/usr/local` and the
`.so` lands outside ldconfig's default search path.

`-Dc_args="-Wno-error=incompatible-pointer-types"` required for GCC 14+ (CachyOS,
Arch). Harmless on older GCC.

### What the existing AUR package (`libfprint-goodixtls-git`) gets right

- `provides`/`conflicts` structure — copy this exactly
- `pkgver()` pattern
- `optdepends` for fprintd

### What it gets wrong (don't copy)

1. `build()` calls `meson ..` → `meson configure` → `meson build` — broken/deprecated
   invocation; correct is `meson setup` then `ninja`
2. Missing `-Dgoodixtls=enabled` — silently skips the driver if gnutls isn't found
3. Missing `-Dc_args` — fails on GCC 14+ (CachyOS ships GCC 15)
4. `opencv` listed in `makedepends` but it's a runtime dep (caught in AUR comments)
5. `git switch` in `prepare()` — redundant if source URL already pins the branch
6. `doctest`, `cmake`, `gobject-introspection`, `gtk-doc`, `nss`, `pixman`, `openssl`
   all listed but not needed

### Source URL

Currently points to 0x00002a's GitHub. For an AUR package based on our fork, point
at the branch on whatever public remote this repo is pushed to. Once the MR is merged
into upstream libfprint, the source becomes `git+https://gitlab.freedesktop.org/libfprint/libfprint.git`.

---

## Debian / Ubuntu

### The one real build problem — `udev` pkg-config name

`meson.build` calls `dependency('udev')`. Debian's `libudev-dev` ships `libudev.pc`
with `Name: libudev`. Meson cannot find `udev` and the build fails.

**Options:**

1. **Patch `meson.build`** via `debian/patches/` to use
   `dependency('udev', 'libudev')` (meson accepts a fallback list) — most correct,
   survives package updates, and the patch is worth sending upstream as a one-liner.
2. **`debian/rules` workaround** — create the shim before `dh_auto_configure` runs:
   ```makefile
   override_dh_auto_configure:
       cp /usr/lib/$(DEB_HOST_MULTIARCH)/pkgconfig/libudev.pc \
          debian/tmp-udev.pc
       sed -i 's/^Name: libudev/Name: udev/' debian/tmp-udev.pc
       PKG_CONFIG_PATH="$(CURDIR)/debian:$$PKG_CONFIG_PATH" \
           dh_auto_configure -- ...
   ```
   Avoids patching upstream code but is brittle.

Recommended: option 1 (patch), because the fix is a one-liner that will likely be
accepted upstream too.

### `debian/control` key fields

```
Source: libfprint-goodixtls511
Section: libs
Priority: optional
Maintainer: ...
Build-Depends: debhelper-compat (= 13),
               meson (>= 0.53),
               ninja-build,
               libglib2.0-dev,
               libgusb-dev,
               libgnutls28-dev,
               libgudev-1.0-dev,
               libudev-dev,
               pkg-config

Package: libfprint-2-2-goodixtls511
Architecture: any
Depends: ${shlibs:Depends}, ${misc:Depends}
Conflicts: libfprint-2-2
Replaces: libfprint-2-2
Provides: libfprint-2-2
Description: libfprint with Goodix GF511 (27c6:5110) fingerprint driver
```

### `debian/rules`

```makefile
%:
    dh $@ --buildsystem=meson

override_dh_auto_configure:
    dh_auto_configure -- \
        -Ddoc=false \
        -Dgtk-examples=false \
        -Dintrospection=false \
        -Dgoodixtls=enabled \
        -Dc_args="-Wno-error=incompatible-pointer-types"
```

### Distro-specific notes

| Distro | GCC | udev issue | doctest | Notes |
|---|---|---|---|---|
| Debian Bookworm (12) | 12 | ✅ need patch/shim | not needed | GCC 12: `-Wincompatible-pointer-types` is warning only |
| Ubuntu 22.04 Jammy | 11 | ✅ need patch/shim | not needed | Same |
| Ubuntu 24.04 Noble | 13 | ✅ need patch/shim | not needed | GCC 13: still warning only (becomes error at GCC 14) |

### Effort estimate

| Task | Time |
|---|---|
| Write `debian/` skeleton | 1 h |
| udev shim patch + test | 1 h |
| `Conflicts`/`Replaces`/`Provides` testing | 1 h |
| Packagecloud / PPA upload + CI | 2 h |
| **Total** | **~5 h** |

The main friction is the `Conflicts`/`Replaces`/`Provides` dance and verifying that
`apt` cleanly swaps `libfprint-2-2` without breaking `fprintd`.

### Long-term

Once the MR is merged into upstream libfprint, the Debian/Ubuntu maintainer
(`libfprint` source package, currently maintained by the pkg-gnome team) would pull
the new release via their normal workflow. A custom `.deb` is only useful in the
interim.
