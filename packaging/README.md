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
