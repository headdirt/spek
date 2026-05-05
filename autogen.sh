#!/bin/sh
# Run this to generate all the initial makefiles, etc.

test -n "$srcdir" || srcdir=$(dirname "$0")
test -n "$srcdir" || srcdir=.

# On macOS, expose wxWidgets' aclocal macros (wxwin.m4) from Homebrew so
# AM_OPTIONS_WXCONFIG / AM_PATH_WXCONFIG resolve without manual symlinks.
if [ "$(uname -s)" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
    wx_aclocal=$(dirname "$(find -L "$(brew --prefix wxwidgets 2>/dev/null)" -name wxwin.m4 2>/dev/null | head -1)")
    if [ -n "$wx_aclocal" ] && [ -d "$wx_aclocal" ]; then
        ACLOCAL_PATH="$wx_aclocal${ACLOCAL_PATH:+:$ACLOCAL_PATH}"
        export ACLOCAL_PATH
    fi
fi

(
  cd "$srcdir" &&
  touch config.rpath &&
  autoreconf -fiv
) || exit
test -n "$NOCONFIGURE" || "$srcdir/configure" "$@"
