# bem — Bash Extension Manager

A secure, lightweight tool for managing shell scripts as commands.

## Install

**One command** (clones to `~/.local/share/bem` by default):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/P4o1o/bem/main/install.sh)
exec bash
```

**With bundled plugins** (search, replace):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/P4o1o/bem/main/install.sh) --full
```

**Custom location** — bem can live wherever you want:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/P4o1o/bem/main/install.sh) -d ~/my-tools/bem --full
```

**Manual** (clone wherever you want, run init):

```bash
git clone https://github.com/P4o1o/bem.git ~/wherever/you/want
cd ~/wherever/you/want
./bem init
./bem install plugins/search plugins/replace   # optional
exec bash
```

`bem init` creates a symlink `~/.local/bin/bem -> <wherever bem lives>`. Everything else is managed from there. There is no hardcoded install path.

## How It Works

bem creates **symlinks** in `~/.local/bin/` pointing to your scripts. No aliases, no `eval`, no sourced plugin code. The only file sourced in `.bashrc` is a ~1.8KB autocomplete function.

```
~/.local/bin/
├── bem     -> ~/wherever/bem                 (bem itself)
├── search  -> ~/wherever/plugins/search      (plugin)
└── replace -> /some/other/path/replace       (plugin from anywhere)
```

Plugin metadata lives in `~/.bem/plugins/<n>/{enabled, path, repo}`.

## Commands

### Lifecycle

| Command | Description |
|---------|-------------|
| `bem init` | Initialize. Creates symlink for bem, sets up autocomplete. |
| `bem install [-n <n>] <file> ...` | Install scripts as plugins. |
| `bem remove <name ...>` | Unregister plugins. Original files are kept. |
| `bem purge <name ...>` | Unregister AND delete original files. |
| `bem uninstall` | Remove bem completely. Double confirmation. |

### Control

| Command | Description |
|---------|-------------|
| `bem enable <name ...>` | Create symlink (activate). |
| `bem disable <name ...>` | Remove symlink (deactivate). |

### Info

| Command | Description |
|---------|-------------|
| `bem list` | Show all plugins with status. |
| `bem status <name ...>` | Detailed info: file integrity, symlink, permissions. |
| `bem help [name ...]` | Plugin docs or usage message. |
| `bem version` | Show version. |

### Updates

| Command | Description |
|---------|-------------|
| `bem update <name ...>` | Git-pull specific plugins. |
| `bem update-all` | Git-pull all git-tracked plugins. |
| `bem upgradeable` | Check for available updates (fetch only). |
| `bem self-update` | Update bem itself. |

All destructive commands (`remove`, `purge`, `uninstall`) require confirmation. There is no force flag.

## Bundled Plugins

### search

Fast file and content search. Literal strings, no regex.

```bash
search main                    # find files by name
search -c 'TODO' -e py         # content search in .py files
search -c -i --color error     # case-insensitive
search -o main                 # open first match in $EDITOR
```

### replace

Safe recursive find-and-replace. Literal strings only.

```bash
replace foo bar ./src
replace '$PRICE' '€100' ./templates
replace 'C:\old' 'C:\new' ./configs
replace -N --color 'cout' 'print' .    # dry run
replace -e js 'var ' 'const ' ./src    # extension filter
```

## External Plugins

Any executable on your system can be a plugin:

```bash
git clone https://github.com/someone/tool.git ~/tools/tool
bem install -n mytool ~/tools/tool/script.sh
bem update mytool       # git pull (auto-detected)
bem upgradeable         # check for new versions
```

## Security

See **[SECURITY.md](SECURITY.md)** for the full review.

Key points: zero aliases (everything is a symlink), ~1.8KB fixed sourced code, 100+ reserved command names, mandatory confirmation on destructive ops, `umask 077`, atomic writes, `flock` concurrency control, `--ff-only` git pulls, world-writable detection.

## Directory Layout

```
~/wherever/bem/              (the git repo — lives anywhere you want)
├── bem
├── plugins/{search,replace}
├── install.sh
├── SECURITY.md
└── README.md

~/.bem/                      (runtime metadata — managed by bem)
├── bem_source.bash          (autocomplete only, ~1.8KB, read-only)
├── .lock
└── plugins/<n>/{enabled,path,repo}

~/.local/bin/                (symlinks — the commands)
├── bem -> ~/wherever/bem/bem
└── <n> -> /path/to/script
```

## Requirements

- Bash 4.0+
- `find`, `grep`, `flock`, `realpath`, `stat`, `ln`
- `perl` (for the replace plugin)
- `git` (for updates)

## Uninstall

```bash
bem uninstall
exec bash
```

## License

MIT
