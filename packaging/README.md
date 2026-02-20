# Packaging

This directory contains distribution packaging files for the Goodix GF511 (27c6:5110)
libfprint driver.

---

## AUR (Arch Linux)

**File:** `aur/PKGBUILD`

### Before publishing to AUR

1. Push the `goodixtls-on-1.94.9` branch to a public git remote.
2. Update the `url=` line in `PKGBUILD` to your remote URL.
3. Generate `.SRCINFO`:
   ```sh
   makepkg --printsrcinfo > .SRCINFO
   ```
4. Push `PKGBUILD` and `.SRCINFO` to an AUR git repo (`https://aur.archlinux.org/`).

### Local test build

```sh
cd aur/
makepkg -si
```

### What this replaces

| AUR package | Issue |
|---|---|
| `libfprint-goodixtls-git` | Broken `meson configure` invocation; stale opencv/doctest deps; missing `-Dgoodixtls=enabled` |

---

## Debian / Ubuntu

**Directory:** `debian/debian/`

This `debian/` tree should be placed **inside** a copy of the source tree, i.e.:

```
libfprint-goodixtls511-1.94.9/
├── debian/          ← contents of debian/debian/
├── libfprint/
├── meson.build
└── ...
```

### Build

```sh
# Install build dependencies
sudo apt-get install debhelper meson ninja-build pkg-config \
    libglib2.0-dev libgusb-dev libgnutls28-dev libgudev-1.0-dev libudev-dev

# Build the .deb (from source root, one level above debian/)
dpkg-buildpackage -us -uc -b
```

The resulting `.deb` installs as `libfprint-2-2-goodixtls511` with
`Conflicts`/`Replaces`/`Provides: libfprint-2-2` so `apt` swaps it cleanly.

### udev note

The `dependency('udev', 'libudev')` fallback is already applied in `meson.build`
in the source tree — **no Debian patch is required**. This is the fix described in
`analysis/12-packaging-aur-debian.md` §"The one real build problem".

### Long-term

Once the upstream MR is merged, the `pkg-gnome` team will update `libfprint` in
Debian/Ubuntu normally and this custom `.deb` can be removed.
