#!/bin/sh
# Run this to generate all the initial makefiles, etc.

test -n "$srcdir" || srcdir=$(dirname "$0")
test -n "$srcdir" || srcdir=.

# On macOS, wire Homebrew-installed deps into the autotools env.
if [ "$(uname -s)" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
    # wxWidgets' aclocal macros (wxwin.m4) so AM_OPTIONS_WXCONFIG /
    # AM_PATH_WXCONFIG resolve without manual symlinks.
    wx_aclocal=$(dirname "$(find -L "$(brew --prefix wxwidgets 2>/dev/null)" -name wxwin.m4 2>/dev/null | head -1)")
    if [ -n "$wx_aclocal" ] && [ -d "$wx_aclocal" ]; then
        ACLOCAL_PATH="$wx_aclocal${ACLOCAL_PATH:+:$ACLOCAL_PATH}"
        export ACLOCAL_PATH
    fi

    # Spek depends on FFmpeg's RDFT API (avfft.h), removed in FFmpeg 7+.
    # Prefer the keg-only ffmpeg@6 if installed.
    ffmpeg6_pc=$(brew --prefix ffmpeg@6 2>/dev/null)/lib/pkgconfig
    if [ -d "$ffmpeg6_pc" ]; then
        PKG_CONFIG_PATH="$ffmpeg6_pc${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
        export PKG_CONFIG_PATH
    fi
fi

(
  cd "$srcdir" &&
  touch config.rpath &&
  autoreconf -fiv
) || exit
test -n "$NOCONFIGURE" || "$srcdir/configure" "$@"
