# aseprite-build-script

Neatly builds Aseprite from source on linux or macOS.

```sh
curl -fsSL https://raw.githubusercontent.com/othmanelfadil/aseprite-build-script/main/get.sh | bash
```
That fetches a remote script which clones this repo into a temp directory and runs the real installer from there. If you'd rather read the code before running it, (which is a reasonable thing to want for anything piped into bash),clone it yourself instead and run it locally:

```sh
git clone https://github.com/othmanelfadil/aseprite-build-script.git
cd aseprite-build-script
./install.sh
```

This Clones the Aseprite repo, then installs whatever build packages are missing and grabs the matching prebuilt Skia Library, after that it compiles with CMake and Ninja , drops the binary , finally it makes a desktop launcher on linux (only for now). Running it again would update Aseprite.

## Is this actually allowed?

TLDR Yes. 
lONG VERSION: Aseprite's EULA restricts handing out pre-built binaries. Compiling the source yourself is the documented, supported path; the project's own INSTALL.md explains how to do it, and ships `build.sh`/`build.cmd` scripts for it. This script automates the same steps from INSTALL.md and never downloads or redistributes a built copy of Aseprite.

## Requirements

- Linux or macOS. On Linux, detection goes by package manager family not by the exact distro name so Fedora/Debian/Arch/openSUSE and so on, are all covered with their derivatives.
- about 10 Gb of free disk space.
- sudo, to install missing packages (they vary per distro).
- git and curl.

Windows support is currently in the works as Aseprite needs Visual Studio 2022 there (?), to bypass this current limitation consider using WSL.

## Usage

```sh
./install.sh [options]
```

| Flag | Description |
|---|---|
| `-y`, `--yes` | Don't ask for confirmation |
| `-v`, `--ref <tag>` | Build this tag/branch instead of the latest release |
| `-j`, `--jobs <N>` | Parallel build jobs for ninja |
| `--prefix <dir>` | Where to install (default `~/.local/share/aseprite-installer`) |
| `--skip-deps` | Don't touch OS packages |
| `--reinstall` | Rebuild even if this ref is already installed |
| `--debug` | Debug build instead of RelWithDebInfo |
| `--uninstall` | Remove the installed build and exit |
| `-h`, `--help` | Usage |

A few examples:

```sh
./install.sh                  # latest stable release
./install.sh -y -j 8          # skip prompts, 8 build jobs
./install.sh --ref v1.3.13    # a specific version
./install.sh --ref main       # main branch
```

Flags pass through the curl install too, after `bash -s --`:

```sh
curl -fsSL https://raw.githubusercontent.com/othmanelfadil/aseprite-build-script/main/get.sh | bash -s -- -y -j 8
```

## How it builds

1. Installs missing packages for your distro.
2. Clones (or updates) `aseprite/aseprite` and checks out the resolved ref.
3. Reads the required Skia version from `laf/misc/skia-tag.txt`, then builds the download URL the same way Aseprite's own `skia-url.sh` does, and caches the archive.
4. Compiles. On Linux this is a direct `cmake` + `ninja` call using the flags INSTALL.md documents for Linux, notably `-stdlib=libstdc++`, which the prebuilt Skia needs to link correctly. On macOS it use Aseprite's own `build.sh --auto`, since that platform doesn't have the stdlib mismatch problem, and upstream's script tracks Xcode/SDK changes better than a hardcoded flag list would.
5. Copies the binary into a versioned directory and symlinks it in.

## Where things end up

```
~/.local/share/aseprite-installer/
├── src/            cloned source, reused on later runs
├── versions/<ref>/  built binary + data for each version you've built
└── installed-ref     which one is currently linked
~/.local/bin/aseprite  symlink to the current version
~/.cache/aseprite-installer/skia/  cached Skia downloads
~/.local/share/applications/aseprite.desktop  Linux launcher
```

## Uninstalling

```sh
./uninstall.sh            # remove the binary, symlink, desktop file
./uninstall.sh --purge    # also wipe the cloned source and cached Skia
```

## License

The scripts here are MIT, see [LICENSE](LICENSE). Aseprite itself has its
own license, see "Is this actually allowed?" above.