# aseprite-build-script

Neatly builds Aseprite from source on linux or macOS.

```sh
git clone https://github.com/othmanelfadil/aseprite-build-script.git
cd aseprite-build-script
./install.sh
```

Clones the Aseprite repo, then installs whatever build packages are missing and grabs the matching prebuilt Skia Library, after that it compiles with CMake and Ninja , drops the binary , finally it makes a desktop launcher on linux (only for now). Running it again would update Aseprite.

## Requirements

- Linux and macOS.
- about 10 Gb of free disk space

Windows support is currently in the works as Aseprite needs Visual Studio 2022 there (?), to bypass this current limitation consider using WSL.

## Usage

```sh
./install.sh [options]
```

## How it builds

1. Installs missing packages for your distro.
2. Clones (or updates) `aseprite/aseprite` and checks out the resolved ref.
3. Reads the required Skia version from `laf/misc/skia-tag.txt`, then builds the download URL the same way Aseprite's own `skia-url.sh` does, and caches the archive.
4. Compiles. On Linux this is a direct `cmake` + `ninja` call using the flags INSTALL.md documents for Linux, notably `-stdlib=libstdc++`, which the prebuilt Skia needs to link correctly. On macOS it use Aseprite's own `build.sh --auto`, since that platform doesn't have the stdlib mismatch problem, and upstream's script tracks Xcode/SDK changes better than a hardcoded flag list would.
5. Copies the binary into a versioned directory and symlinks it in.

## Uninstalling

```sh
./uninstall.sh            # remove the binary, symlink, desktop file
./uninstall.sh --purge    # also wipe the cloned source and cached Skia
```