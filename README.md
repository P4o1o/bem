# bem — Bash Extension Manager

A secure, lightweight tool for managing shell scripts as commands. Install, enable, disable, update, and remove scripts from a single interface.

## Install

**One command:**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/P4o1o/bem/main/install.sh)
exec bash
```

This installs bem only. To also install the bundled plugins (`search`, `replace`):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/P4o1o/bem/main/install.sh) --full
exec bash
```

**Manual install** (if you prefer to inspect first):

```bash
git clone https://github.com/P4o1o/bem.git ~/.local/share/bem
cd ~/.local/share/bem
./bem init
exec bash
```

> **Tip:** you can always install bundled plugins later with `bem install ~/.local/share/bem/plugins/search` etc.

## How It Works

bem creates **symlinks** in `~/.local/bin/` pointing to your scripts. No aliases, no `eval`, no sourced plugin code. The only file sourced in `.bashrc` is a ~1.8KB autocomplete function.

```
~/.local/bin/
├── bem     -> ~/.local/share/bem/bem
├── search  -> ~/.local/share/bem/plugins/search
└── replace -> ~/.local/share/bem/plugins/replace
```

## Commands

### Lifecycle

**`bem install [-n <n>] <file> ...`** — Install scripts as plugins.

```bash
bem install ~/scripts/myscript.sh             # name from filename
bem install -n deploy ~/work/deploy-prod.sh   # custom name
```

**`bem remove <name ...>`** — Unregister plugins from bem. Original files are kept.

**`bem purge <name ...>`** — Unregister AND permanently delete the original files.

**`bem uninstall`** — Completely remove bem: all symlinks, all data, all `.bashrc` entries. Original plugin files are preserved. Requires double confirmation.

### Control

**`bem enable <name ...>`** / **`bem disable <name ...>`** — Toggle plugins on/off by creating or removing their symlink.

### Info

**`bem list`** — Show all plugins with status.

**`bem status <name ...>`** — Detailed info: file integrity, symlink health, world-writable warnings, git tracking.

**`bem help [name ...]`** — Show plugin documentation or the usage message.

**`bem version`** — Show bem version.

### Updates

**`bem update <name ...>`** — Git-pull specific plugins.

**`bem update-all`** — Git-pull all repo-tracked plugins.

**`bem upgradeable`** — Check which plugins have updates available without pulling them.

**`bem self-update`** — Update bem itself via git.

## Bundled Plugins

### search

Fast file and content search. All queries are literal strings.

```bash
search main                    # find files by name
search -c 'TODO' -e py         # content search in .py files
search -c -i --color error     # case-insensitive with highlights
search -o main                 # open first match in $EDITOR
```

### replace

Safe recursive find-and-replace. Literal strings only — zero regex.

```bash
replace foo bar ./src
replace '$PRICE' '€100' ./templates            # $ is literal
replace 'C:\old\path' 'C:\new\path' ./configs  # backslashes are literal
replace -N --color 'std::cout' 'fmt::print' .  # dry run
replace -e js 'var ' 'const ' ./src            # extension filter
```

## External Plugins

Any executable file can be managed by bem:

```bash
git clone https://github.com/someone/tool.git ~/tools/tool
bem install -n mytool ~/tools/tool/script.sh
bem update mytool       # auto-detected as git repo
bem upgradeable         # check for new versions
```

## Security

See [SECURITY.md](SECURITY.md) for the full security review covering: the symlink vs alias decision, input validation, world-writable detection, concurrency control, atomic writes, git safety, installer security, and known limitations.

Key points:
- **Zero aliases.** Everything is a symlink — no shell parsing, no injection surface.
- **~1.8KB sourced at startup.** Fixed size, never grows.
- **100+ reserved command names** can't be shadowed.
- **All destructive operations** (`remove`, `purge`, `uninstall`) require confirmation.
- **`umask 077`** — all metadata is owner-only.

## Directory Structure

```
~/.local/share/bem/          (installation)
├── bem
├── plugins/
│   ├── search
│   └── replace
├── install.sh
├── SECURITY.md
└── README.md

~/.bem/                      (runtime data)
├── bem_source.bash          (~1.8KB, autocomplete only, read-only)
├── .lock
└── plugins/
    └── <n>/{enabled,path,repo}

~/.local/bin/                (symlinks)
├── bem -> ~/.local/share/bem/bem
└── <n> -> /path/to/script
```

## Requirements

- Bash 4.0+
- `find`, `grep`, `flock`, `realpath`, `stat`, `ln`
- `perl` (for the replace plugin)
- `git` (for update/upgradeable features)

## Uninstall

```bash
bem uninstall
exec bash
```

Or manually:

```bash
for d in ~/.bem/plugins/*/; do [ -d "$d" ] || continue; n="${d%/}"; rm -f ~/.local/bin/"${n##*/}"; done
rm -f ~/.local/bin/bem
sed -i '/^# bem:start$/,/^# bem:end$/d' ~/.bashrc
rm -rf ~/.bem
```

## License

MIT
