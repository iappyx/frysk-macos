#!/bin/bash
#
# install_frysk_spelling_mac.sh
#
# Adds Frisian (Frysk) spell checking to macOS, system-wide: Pages, Mail,
# Notes, TextEdit, Safari, Chrome and most other Mac apps.
#
# It downloads the Fryske Akademy's free spelling add-on for LibreOffice,
# takes out the Hunspell word list (fy_NL.aff / fy_NL.dic), converts it to
# UTF-8 so macOS reads it reliably, and - after asking you - installs it in
# ~/Library/Spelling. Nothing is installed without your confirmation.
#
# The word list is (c) Fryske Akademy, licensed under the GPL v3.
#
# Usage:
#   bash install_frysk_spelling_mac.sh              download, convert, install
#   bash install_frysk_spelling_mac.sh --file X.zip use an already downloaded add-on (.zip or .oxt)
#   bash install_frysk_spelling_mac.sh --uninstall  remove the Frisian word list again
#
# Uses only tools that come with macOS (curl, unzip, iconv, awk).

set -euo pipefail

URL="https://beheer.frysker.nl/wp-content/uploads/2024/12/fy_NL-20160722.oxt_.zip"
PAGE="https://frysker.nl/downloads"
DEST="$HOME/Library/Spelling"
NAME="fy_NL"

say()  { printf '\n==> %s\n' "$*"; }
fail() { printf '\nError: %s\n' "$*" >&2; exit 1; }

ask() {   # ask "question" -> returns 0 for yes
    local reply
    printf '%s [y/N] ' "$1"
    read -r reply </dev/tty || reply=""
    case "$reply" in [yY]|[yY][eE][sS]|[jJ]|[jJ][aA]) return 0 ;; *) return 1 ;; esac
}

open_settings() {
    # Keyboard settings (macOS 13+ first, older System Preferences as fallback)
    open "x-apple.systempreferences:com.apple.Keyboard-Settings.extension" 2>/dev/null \
        || open "x-apple.systempreferences:com.apple.preference.keyboard?Text" 2>/dev/null \
        || true
}

# ---------------------------------------------------------------- arguments
LOCAL_FILE=""
case "${1:-}" in
    --uninstall)
        FOUND=0
        for f in "$DEST/$NAME.aff" "$DEST/$NAME.dic" "$DEST/$NAME-README.txt"; do
            [ -e "$f" ] && FOUND=1
        done
        [ "$FOUND" = 1 ] || { echo "The Frisian word list is not installed in $DEST."; exit 0; }
        if ask "Remove the Frisian word list from $DEST?"; then
            rm -f "$DEST/$NAME.aff" "$DEST/$NAME.dic" "$DEST/$NAME-README.txt"
            echo "Removed. Restart your apps (or log out and in) to finish."
        else
            echo "Nothing changed."
        fi
        exit 0 ;;
    --file)
        LOCAL_FILE="${2:-}"
        [ -f "$LOCAL_FILE" ] || fail "File not found: $LOCAL_FILE" ;;
    -h|--help)
        sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
        exit 0 ;;
    "") ;;
    *) fail "Unknown option: $1 (try --help)" ;;
esac

[ "$(uname)" = "Darwin" ] || echo "Note: this script is meant for macOS; installing will only help on a Mac."

WORK="$(mktemp -d "${TMPDIR:-/tmp}/frysk-spelling.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------- 1. download
if [ -n "$LOCAL_FILE" ]; then
    say "Using $LOCAL_FILE"
    cp "$LOCAL_FILE" "$WORK/download"
else
    say "Downloading the Frisian spelling add-on from the Fryske Akademy"
    if ! curl -fL --retry 3 --progress-bar -o "$WORK/download" "$URL"; then
        fail "Download failed. The file may have moved; download the LibreOffice/OpenOffice
spelling add-on from $PAGE and run:
    bash $0 --file path/to/the/downloaded/file"
    fi
fi

# ---------------------------------------------------------------- 2. unpack
say "Unpacking"
mkdir -p "$WORK/unpacked"
unzip -q -o "$WORK/download" -d "$WORK/unpacked" 2>/dev/null \
    || fail "The downloaded file is not a zip/oxt archive."
# The download is a zip that contains the .oxt add-on (itself a zip); unpack nested archives.
for i in 1 2 3; do
    FOUND_ARCHIVE=0
    while IFS= read -r arc; do
        FOUND_ARCHIVE=1
        dir="${arc%.*}.d"
        mkdir -p "$dir"
        unzip -q -o "$arc" -d "$dir" && rm -f "$arc"
    done < <(find "$WORK/unpacked" -type f \( -iname '*.oxt' -o -iname '*.zip' -o -iname '*.xpi' \))
    [ "$FOUND_ARCHIVE" = 1 ] || break
done

AFF="$(find "$WORK/unpacked" -type f -name "$NAME.aff" | head -n 1)"
DIC="$(find "$WORK/unpacked" -type f -name "$NAME.dic" | head -n 1)"
[ -n "$AFF" ] && [ -n "$DIC" ] || fail "Could not find $NAME.aff and $NAME.dic in the add-on."
README="$(find "$WORK/unpacked" -type f -name 'README*' | head -n 1)"

# ---------------------------------------------------------------- 3. convert
say "Converting the word list to UTF-8"
SET_LINE="$(LC_ALL=C grep -m 1 '^SET ' "$AFF" || true)"
ENC="$(printf '%s' "$SET_LINE" | awk '{print $2}' | tr -d '\r')"
[ -n "$ENC" ] || ENC="ISO-8859-1"          # Hunspell's default when no SET line is present
case "$(printf '%s' "$ENC" | tr '[:lower:]' '[:upper:]')" in
    UTF-8|UTF8) ENC="UTF-8" ;;
    ISO8859-1)  ENC="ISO-8859-1" ;;
    ISO8859-15) ENC="ISO-8859-15" ;;
esac
echo "    original encoding: $ENC"

OUT="$WORK/out"
mkdir -p "$OUT"
iconv -f "$ENC" -t UTF-8 "$DIC" > "$OUT/$NAME.dic" || fail "Could not convert $NAME.dic"
iconv -f "$ENC" -t UTF-8 "$AFF" > "$OUT/$NAME.aff.tmp" || fail "Could not convert $NAME.aff"
if [ -n "$SET_LINE" ]; then
    LC_ALL=C awk '!done && /^SET / { print "SET UTF-8"; done = 1; next } { print }' "$OUT/$NAME.aff.tmp" > "$OUT/$NAME.aff"
else
    { printf 'SET UTF-8\n'; cat "$OUT/$NAME.aff.tmp"; } > "$OUT/$NAME.aff"
fi
rm -f "$OUT/$NAME.aff.tmp"

# sanity checks
iconv -f UTF-8 -t UTF-8 "$OUT/$NAME.aff" >/dev/null 2>&1 || fail "Converted $NAME.aff is not valid UTF-8"
iconv -f UTF-8 -t UTF-8 "$OUT/$NAME.dic" >/dev/null 2>&1 || fail "Converted $NAME.dic is not valid UTF-8"
COUNT="$(head -n 1 "$OUT/$NAME.dic" | awk '{print $1}')"
case "$COUNT" in ''|*[!0-9]*) fail "$NAME.dic does not look like a Hunspell word list" ;; esac
[ "$COUNT" -gt 1000 ] || fail "$NAME.dic contains only $COUNT words; something is wrong"
LC_ALL=C grep -q 'Frysl' "$OUT/$NAME.dic" || fail "$NAME.dic does not look like a Frisian word list"
VERSION="$(LC_ALL=C grep -a -m 1 -o 'version: [0-9]*' "$OUT/$NAME.dic" | awk '{print $2}' || true)"
echo "    $COUNT words${VERSION:+, version $VERSION}"

# ---------------------------------------------------------------- 4. install
say "Ready to install"
echo "    This copies $NAME.aff and $NAME.dic to:"
echo "    $DEST"
if [ -e "$DEST/$NAME.aff" ] || [ -e "$DEST/$NAME.dic" ]; then
    echo "    (A Frisian word list is already there; it will be kept as $NAME.aff.bak / $NAME.dic.bak.)"
fi
echo
if ! ask "Install the Frisian word list now?"; then
    KEEP="$HOME/Downloads/$NAME-mac"
    if ask "Save the converted files to $KEEP instead?"; then
        mkdir -p "$KEEP"
        cp "$OUT/$NAME.aff" "$OUT/$NAME.dic" "$KEEP/"
        [ -n "$README" ] && cp "$README" "$KEEP/README.txt"
        echo "Saved in $KEEP"
    else
        echo "Nothing was installed."
    fi
    exit 0
fi

mkdir -p "$DEST"
for f in aff dic; do
    [ -e "$DEST/$NAME.$f" ] && mv -f "$DEST/$NAME.$f" "$DEST/$NAME.$f.bak"
    cp "$OUT/$NAME.$f" "$DEST/$NAME.$f"
done
[ -n "$README" ] && cp "$README" "$DEST/$NAME-README.txt"
say "Installed"

cat <<EOF

One more step: switch Frisian on.
  System Settings > Keyboard > Text Input > Edit... > Spelling > Set Up...
  Tick Frisian (it may be listed as "fy_NL"), or keep "Automatic by Language".
Then restart your apps (or log out and back in).

It works in Pages, Mail, Notes, TextEdit, Safari, Chrome and most other Mac
apps. Microsoft Word uses its own spell checker and is not covered.
To remove it later:  bash $0 --uninstall
EOF
echo
if [ "$(uname)" = "Darwin" ] && ask "Open Keyboard settings now?"; then
    open_settings
fi
