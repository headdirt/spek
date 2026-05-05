# Building the macOS bundle

Builds natively on both Apple Silicon (arm64) and Intel (x86_64). The bundle
script auto-detects the Homebrew prefix (`/opt/homebrew` on Apple Silicon,
`/usr/local` on Intel) and tags the resulting DMG with the host architecture
(`Spek-arm64.dmg` or `Spek-x86_64.dmg`).

Using [Homebrew](https://brew.sh) install build dependencies:

    brew install automake coreutils git pkg-config ffmpeg wxwidgets

If `wx-config` cannot be found by autoconf, ensure Homebrew's bin is on PATH
(`eval "$(brew shellenv)"`) and add the wxWidgets aclocal macro:

    BREW_PREFIX=$(brew --prefix)
    WX_M4=$(find "$BREW_PREFIX"/Cellar/wxwidgets -name wxwin.m4 | head -1)
    ln -sf "$WX_M4" "$BREW_PREFIX"/share/aclocal/

Bundle Spek:

    ./dist/osx/bundle.sh

The output is `dist/osx/Spek-<arch>.dmg`. Run on the architecture you intend
to ship for; cross-compiling is not configured.
