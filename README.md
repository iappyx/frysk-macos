# Frisian spell checking for macOS

A small installer that adds **Frisian (Frysk) spell checking to macOS**. It
works system-wide in Pages, Mail, Notes, TextEdit, Safari, Chrome and most
other Mac apps.

It uses the official word list of the [Fryske Akademy](https://www.fryske-akademy.nl/),
based on the *Foarkarswurdlist* and the 2015 spelling rules. The Akademy
publishes it as a free add-on for LibreOffice; this script makes it work on
the Mac itself.

## Install

Download `install_frysk_spelling_mac.sh`, open Terminal and run:

```
bash ~/Downloads/install_frysk_spelling_mac.sh
```

The script:

1. **Downloads** the Fryske Akademy's spelling add-on from Frysker.nl.
2. **Unpacks** the Hunspell word list (`fy_NL.aff` and `fy_NL.dic`).
3. **Converts** it from Latin-1 to UTF-8, so macOS reads it reliably. The words
   themselves are unchanged.
4. **Checks** the result.
5. **Asks** before installing it in `~/Library/Spelling`. If a Frisian word list
   is already installed, it is kept as a backup.

Then switch Frisian on: **System Settings → Keyboard → Text Input → Edit… →
Spelling → Set Up…**, tick Frisian (it may be listed as "fy_NL"), and restart
your apps.

It needs no administrator rights and no extra software. It only uses tools
that come with macOS: curl, unzip, iconv and awk.

### Options

| Command | What it does |
|---|---|
| `bash install_frysk_spelling_mac.sh` | Download, convert and install |
| `bash install_frysk_spelling_mac.sh --file path/to/addon.zip` | Use an add-on you already downloaded (`.zip` or `.oxt`) |
| `bash install_frysk_spelling_mac.sh --uninstall` | Remove the Frisian word list again |

If the download link ever stops working, download the LibreOffice/OpenOffice
spelling add-on from [frysker.nl/downloads](https://frysker.nl/downloads) and
use `--file`.

## Limitations

- **Microsoft Word for Mac** uses its own spell checker and is not covered. For
  Word, you can use [Iepen Fryske Stavering](https://iappyx.github.io/iepen-fryske-stavering/) (also by iappyx).
- **Firefox and LibreOffice** have their own spell checkers too. Install the
  Akademy's Mozilla or LibreOffice add-on in those programs directly.
- The word list is **version 2016-07-22**, so words added to Frisian since then
  may be marked as unknown.

## License

- **The installer script** is released under the [MIT License](LICENSE).
- **The Frisian word list** is © Fryske Akademy and licensed under the
  [GNU General Public License v3](https://www.gnu.org/licenses/gpl-3.0.html).
  It is not included in this repository: the script downloads it from the
  Fryske Akademy, and installs the Akademy's README with it.

This project is not affiliated with or endorsed by the Fryske Akademy.
