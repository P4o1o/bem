# bem — Bash Extension Manager

A lightweight, secure tool for managing shell scripts and executables as plugins. Install, enable, disable, update, and remove scripts from a single command — with automatic alias generation, git-aware updates, and tab completion.

## Quick Start

```bash
git clone https://github.com/<your-user>/bem.git ~/.local/share/bem
cd ~/.local/share/bem
chmod +x bem
./bem init
exec bash
```

After `init`, bem is available globally and comes with tab completion.

### Install the bundled plugins

```bash
bem install plugins/search plugins/replace
exec bash
```

Now `search` and `replace` are available as commands in your shell.

## How It Works

bem manages a registry of plugins under `~/.bem/plugins/`. Each plugin is a directory containing simple metadata files:

```
~/.bem/plugins/<name>/
├── enabled        # exists if plugin is active
├── path           # absolute path to the script
└── repo           # exists if inside a git repository
```

When you enable or install a plugin, bem regenerates `~/.bem/bem_source.bash` — a file sourced by your `.bashrc` that sets up aliases and autocompletion. No manual `PATH` editing needed.

## Commands

### `bem install [-n <name>] <file> ...`

Install one or more scripts as plugins.

```bash
# Install with auto-detected name (filename minus .sh/.bash)
bem install ~/scripts/myscript.sh

# Install with a custom alias
bem install -n deploy ~/work/deploy-production.sh

# Install multiple at once
bem install plugins/search plugins/replace
```

### `bem remove [-A] [-f] <name> ...`

Remove plugins from the registry.

```bash
bem remove search              # asks for confirmation
bem remove -f search replace   # skip confirmation
bem remove -Af old-tool        # also delete the original file
```

### `bem enable` / `bem disable`

Toggle plugins on and off without removing them.

```bash
bem disable replace     # deactivate
bem enable replace      # reactivate
exec bash               # apply changes
```

### `bem list`

Show all installed plugins with their status and path.

```
  search     [enabled]  <git>  /home/user/.local/share/bem/plugins/search
  replace    [disabled]        /home/user/scripts/replace
```

### `bem status <name> ...`

Detailed info for specific plugins, including whether the target file still exists and is executable.

### `bem update <name> ...` / `bem update-all`

Pull the latest changes via git for plugins that live inside a repository.

```bash
bem update search         # update one
bem update-all            # update all git-tracked plugins
```

### `bem self-update`

Update bem itself (requires bem to be installed from a git clone).

### `bem help <name> ...`

Display documentation for a plugin. Looks for `README.md`, `README`, `HELP.md`, or any `.md`/`.txt` file in the plugin's directory.

### `bem init`

Set up the `~/.bem` directory, generate the source file, and link it to `~/.bashrc`. Safe to run multiple times.

## Bundled Plugins

### search

Fast file and content search with directory exclusions.

```bash
search main                        # find files with "main" in the name
search -c 'TODO' -e py             # search for TODO inside .py files
search -c -i --color error         # case-insensitive content search
search -d ./src -e rs config       # search in a specific directory
search -o main                     # open first match in $EDITOR
```

**Options:** `-c` content mode, `-d` directory, `-e` extension filter, `-i` case-insensitive, `--color` colored output, `-o` open first match.

### replace

Safe recursive find-and-replace. All strings are treated as **literals** — no regex, no metacharacter surprises.

```bash
replace foo bar ./src                          # basic replacement
replace -i 'Hello World' 'Goodbye World' .    # case-insensitive
replace -N --color 'std::cout' 'fmt::print' .  # dry run with matches
replace -e js 'var ' 'const ' ./src            # only in .js files
```

**Options:** `-i` case-insensitive, `-n` dry run (files only), `-N` dry run (files + lines), `-j N` parallel jobs, `-e` extension filter, `--color` colored output.

## Using External Plugins

Plugins don't have to live in the bem repo. Any executable file on your system can be installed:

```bash
# From another git repository
git clone https://github.com/someone/cool-tool.git ~/tools/cool-tool
bem install -n cool ~/tools/cool-tool/cool.sh

# bem detects it's in a git repo, so this works:
bem update cool
```

## Security

bem was designed with security as a priority:

- **No `sed` on user input.** The source file is regenerated atomically from scratch on every change — never patched in-place with `sed` or string interpolation.
- **Strict name validation.** Plugin names are restricted to `[a-zA-Z0-9._-]`, max 64 characters, with path traversal blocked.
- **File locking.** Concurrent bem invocations are prevented via `flock`.
- **Atomic writes.** The source file is written to a temp file first, then moved into place — no half-written state on crash.
- **No eval, no unquoted expansion.** Aliases are generated with properly escaped single quotes.
- **Binary detection.** The replace plugin skips binary files automatically.
- **Literal matching.** Both `search` and `replace` use fixed-string matching (`grep -F`, `perl \Q`), so special characters in queries are never interpreted as patterns.

## Directory Structure

```
bem/
├── bem                  # the main tool
├── plugins/
│   ├── search           # bundled: file/content search
│   └── replace          # bundled: safe find-and-replace
├── LICENSE
└── README.md
```

After initialization:

```
~/.bem/
├── bem_source.bash      # sourced by .bashrc (auto-generated)
├── .lock                # flock file
└── plugins/
    ├── search/
    │   ├── enabled
    │   ├── path
    │   └── repo
    └── replace/
        ├── path
        └── repo
```

## Requirements

- Bash 4.0+
- Core utilities: `find`, `grep`, `flock`, `realpath`, `file`
- `perl` (for the replace plugin)
- `git` (only for update features)

## Uninstall

```bash
# Remove the source line from .bashrc
sed -i "\|source.*bem_source.bash|d" ~/.bashrc

# Delete bem data
rm -rf ~/.bem
```

## License

MIT
