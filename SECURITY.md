# Security Review — bem v0.1.0
  
Scope: `bem`, `install.sh`, bundled plugins (`search`, `replace`)

---

## 1. Architecture Summary

bem manages shell scripts as "plugins" by creating **symlinks** in `~/.local/bin/` that point to the original script files. Plugin metadata (enabled state, file path, git tracking) is stored as individual files inside `~/.bem/plugins/<name>/`.

The only file sourced by `.bashrc` is a ~2KB autocomplete function. bem itself and all plugins are invoked via symlinks — no aliases, no `eval`, no dynamic code generation.

## 2. Threat Model

### In scope

| ID | Threat | Impact |
|----|--------|--------|
| T1 | Shell injection via crafted plugin names or paths | Arbitrary code execution |
| T2 | Path traversal (e.g. `../../../etc/passwd`) | File read/write outside registry |
| T3 | Shadowing system commands (`ls`, `sudo`) | Privilege escalation, user confusion |
| T4 | World-writable plugin scripts | Any local user can backdoor a plugin |
| T5 | Concurrent access corrupting state | Plugin registry inconsistency |
| T6 | Partial writes on crash | Sourced file becomes invalid |
| T7 | Unsafe git operations | Unintended code from upstream |
| T8 | Supply chain via curl installer | Arbitrary code execution |
| T9 | Symlink confusion | Overwriting files not managed by bem |

### Out of scope

| Threat | Reason |
|--------|--------|
| Malicious plugin code | bem is a manager, not a sandbox. Plugins run with full user permissions. Only install scripts you trust. |
| Root-level attackers | A root attacker can modify any file. No userspace tool can defend against this. |
| Compromised git remote | If an upstream repo is compromised, `git pull` will fetch malicious code. This is inherent to git-based distribution. Use signed commits and review diffs. |

## 3. Mitigations

### 3.1 Symlinks vs Aliases

**Decision: symlinks.** This is the most consequential security choice in bem.

An alias like `alias myplugin='/path/to/script'` is shell code that runs through bash's parser. If the path contains single quotes, backticks, `$()`, or `\`, the alias can become a code injection vector. Escaping all edge cases correctly is error-prone and has been a real-world vulnerability source in similar tools.

A symlink is a filesystem pointer resolved by the kernel. There is no string parsing, no quoting, no expansion. A path containing any combination of special characters works identically. The only failure mode — a broken symlink — is safe (command not found).

Additionally, symlinks eliminate the need to source plugin-related code in `.bashrc`. The previous alias-based design sourced one alias per plugin in every new shell. With symlinks, the sourced file is a fixed ~2KB autocomplete function regardless of how many plugins are installed. This minimizes the attack surface of code that runs on every shell startup.

### 3.2 Input Validation

**Plugin names** are validated against `^[a-zA-Z0-9_][a-zA-Z0-9._-]*$` with a maximum length of 64 characters. This prevents:

- Path traversal: names cannot start with `.` or contain `/`, blocking `..`, `.hidden`, and `/etc/evil`.
- Shell metacharacters: spaces, quotes, backticks, `$`, `*`, `?`, `|`, `;`, `&`, `(`, `)` are all rejected.
- Flag confusion: names cannot start with `-`, so they can't be confused with command-line options.

**Reserved name blocklist.** Over 100 common system commands (`ls`, `cat`, `sudo`, `git`, `python`, `vim`, etc.) are blocked as plugin names. This prevents both accidental shadowing and deliberate hijacking of critical commands.

**File paths** are resolved through `realpath` and validated as regular, readable files. This rejects directories, device nodes, named pipes, and non-existent paths.

### 3.3 World-Writable Detection

A plugin whose script file is world-writable is a security vulnerability: any local user can modify it, and it will be executed by the plugin owner.

bem detects world-writable files at two points:
1. **At install time**: a visible warning is shown.
2. **In `bem status`**: the file is flagged as `WORLD-WRITABLE`.

This doesn't block installation (the user may have a reason), but ensures the risk is visible.

### 3.4 File Permissions

bem runs with `umask 077`. All files in `~/.bem/` are created with owner-only permissions:
- Directories: `700`
- Files (metadata): `600`
- Source file: `444` (read-only after generation)

This prevents other users on a shared system from reading or modifying plugin metadata.

### 3.5 Concurrency Control

All write operations (`install`, `remove`, `purge`, `enable`, `disable`) acquire an exclusive lock on `~/.bem/.lock` using `flock(2)`. This prevents two concurrent bem invocations from:
- Creating conflicting symlinks.
- Partially removing a plugin while another operation reads its state.
- Writing to the same metadata files simultaneously.

If a lock is held, the second invocation fails immediately with a clear error message rather than waiting indefinitely.

### 3.6 Atomic Writes

The autocomplete source file is written using a temp file + `mv` pattern:

```
mktemp -> write to tmpfile -> chmod 444 -> mv tmpfile to final path
```

`mv` within the same filesystem is an atomic operation (single `rename(2)` syscall). This ensures:
- No half-written file if the process is killed mid-write.
- Other shells cannot source a partially written file.
- If `mktemp` or `chmod` fails, the old file remains intact.

### 3.7 Symlink Safety

- **No overwrite of non-symlinks.** `_create_link` refuses to replace anything that is not a symlink. If `~/.local/bin/search` is a real binary, bem will not destroy it.
- **Targeted removal.** `_remove_link` only deletes symlinks. Regular files are left alone with a warning.
- **Stale cleanup.** `_sync_links` detects and removes broken symlinks, but only for plugins that exist in the bem registry.
- **Uninstall isolation.** `cmd_uninstall` removes only symlinks that correspond to registered plugins, then the `bem` symlink itself. It does not `rm ~/.local/bin/*`.

### 3.8 Destructive Command Confirmation

All destructive operations require interactive confirmation with no global force flag:

| Command | Behavior | Confirmation |
|---------|----------|-------------|
| `remove` | Unregister from bem, keep original files | One per plugin |
| `purge` | Unregister AND delete original files | One per plugin (with warning) |
| `uninstall` | Remove bem, all data, all symlinks, bashrc entries | Double confirmation |

There is no `-f` or `--force` flag on any destructive command. This is deliberate.

### 3.9 Clean .bashrc Management

bem wraps its `.bashrc` entries in block markers:

```bash
# bem:start
export PATH="${HOME}/.local/bin:${PATH}"
source '/home/user/.bem/bem_source.bash'
# bem:end
```

On `uninstall`, the entire block is removed with `sed '/^# bem:start$/,/^# bem:end$/d'`. This is safe because:
- The markers are hardcoded strings, not user input — no sed injection.
- The pattern is anchored to full lines (`^...$`), preventing partial matches.
- Everything outside the block is preserved exactly.

### 3.9 Git Safety

- `git pull` uses `--ff-only` everywhere. This refuses to create merge commits, preventing an attacker from exploiting merge conflict resolution to inject code.
- `git fetch --quiet` in `upgradeable` only downloads refs, never modifies the working tree. It is safe to run at any time.
- Git repo detection uses `git -C <dir> rev-parse --is-inside-work-tree`, which does not modify state.

### 3.10 Installer Security

The curl-based installer (`install.sh`) follows these practices:

- **Inspectable.** Users are encouraged to read the script before running it. The README shows both the pipe-to-bash method and the inspect-first method.
- **Shallow clone.** Uses `git clone --depth 1` to minimize downloaded code.
- **No `sudo`.** The installer never requests or requires root privileges.
- **umask 077.** Applied before any file creation.
- **Fail-fast.** `set -euo pipefail` ensures any error halts execution immediately rather than continuing in a broken state.
- **Explicit dependency check.** Verifies `git`, `realpath`, `flock`, and optionally `perl` before proceeding.

**Acknowledged risk:** piping curl output to bash is inherently risky. The script could be modified server-side between inspection and execution. For maximum security, users should clone the repo manually and inspect the code.

## 4. Plugin Security (search, replace)

### replace

The original version used `sed -i "s|$SEARCH|$REPLACE|g"`. This was vulnerable to:
- **Delimiter injection:** if `SEARCH` or `REPLACE` contained `|`, sed's `s` command broke.
- **Regex injection:** `.*`, `[`, `]`, `+`, `\1` in the search term would be interpreted as regex.
- **Replacement interpolation:** `&`, `\1`, `\n` in the replacement had special meaning in sed.

The rewrite uses perl's `index()` and `substr()` functions — pure string operations with zero pattern matching or interpolation. The search and replace strings are passed via `$ENV{}`, bypassing perl's argument parsing entirely.

Tested with: `$100`, `@email`, `C:\path`, `.*regex[0]`, `|pipe|`, backticks, single quotes, double quotes, `$(command)`.

### search

All queries use `grep -F` (fixed strings). The original used `find -name "*$QUERY*"`, where a query containing `*` or `?` would be interpreted as glob patterns. The rewrite pipes filenames through `grep -F`, which treats the query as a literal substring.

Both plugins skip binary files and apply `|| true` on all pipelines to prevent `set -euo pipefail` from causing silent crashes on permission errors.

## 5. Memory and Performance

### Sourced code footprint

| Version | Sourced at shell startup |
|---------|------------------------|
| Original (aliases) | ~50 bytes per plugin + autocomplete. Grows linearly. |
| Current (symlinks) | ~2KB fixed. Zero growth regardless of plugin count. |

### Subshell elimination

The original read plugin paths with `$(cat file)`, spawning a subshell + `cat` process for each read. The rewrite uses `IFS= read -r var < file`, which is a bash builtin — no fork, no exec.

Colors use hardcoded ANSI escape sequences instead of spawning `tput` (5 subshells eliminated per invocation).

### Runtime cost

Plugin invocation has zero overhead. A symlink is resolved by the kernel at `exec()` time — there is no shell wrapper, no function dispatch, no redirection. The performance is identical to running the script directly.

## 6. Known Limitations

1. **TOCTOU on install.** Between `validate_file_path` and `ln -s`, the file could theoretically be swapped. This requires an attacker with write access to the file's directory. Mitigation: install from trusted locations.

2. **No checksum verification.** bem does not store or verify checksums of plugin files. A modified plugin file will be executed without warning. `bem status` checks world-writable permissions but not content integrity.

3. **No sandboxing.** Plugins execute with the full permissions of the invoking user. A malicious plugin can read, write, and delete any file the user owns.

4. **Autocomplete runs in shell context.** The `_bem_autocomplete` function iterates `~/.bem/plugins/*/` on every tab completion. This is safe (only reads directory names) but could be slow with thousands of plugins.

5. **Symlink targets are not locked.** After installation, the original file can be moved, deleted, or modified without bem's knowledge. `bem status` detects missing files; modification is not detected.

## 7. Comparison with Original

| Aspect | Original | Rewrite |
|--------|----------|---------|
| Plugin mechanism | Alias in sourced file | Symlink in ~/.local/bin |
| Registry format | Fixed-width binary file | Directory-per-plugin filesystem |
| Modification method | `sed -i` on user input | Atomic file creation, no sed |
| Input validation | None | Regex + reserved names + path traversal |
| Concurrency | None | flock |
| File permissions | Inherited | umask 077 |
| World-writable detection | None | Install + status |
| System command protection | None | 100+ reserved names |
| Sourced code | Grows per plugin | Fixed ~2KB |
| Destructive operations | Minimal confirmation | remove/purge/uninstall with mandatory confirmation |
| replace metacharacters | sed injection | perl index()/substr() |
| search query safety | Glob expansion | grep -F fixed strings |
| .bashrc management | Unstructured appended lines | Block markers (bem:start/end) |

## 8. Recommendations for Users

1. **Review before install.** Inspect `install.sh` and `bem` before running them. This applies to any software, not just bem.
2. **Don't install world-writable scripts.** If bem warns about permissions, fix them.
3. **Use `bem status` regularly.** It detects missing files, broken symlinks, and world-writable targets.
4. **Review plugin updates.** Before `bem update`, consider running `git -C <dir> log HEAD..origin/main` to see what changed.
5. **Avoid `purge` unless certain.** `purge` permanently deletes original files. Use `remove` to unregister without data loss.
