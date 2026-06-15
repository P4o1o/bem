# bem

Bash Extension Manager.

`bem` installs shell scripts as commands by creating symlinks in `~/.bem/bin`.

No aliases. No wrappers. No metadata database.

## Install

Run:

```bash
./bem init
```

Add the lines printed by `bem init` to your `.bashrc` file.

Reload Bash:

```bash
exec bash
```

Check:

```bash
bem version
```

## Usage

Install a script:

```bash
bem install ./script.sh
```

Install with a custom name:

```bash
bem install -n mycmd ./script.sh
```

Install multiple scripts:

```bash
bem install ./a.sh ./b.sh
bem install -n a ./a.sh -n b ./b.sh
```

List installed commands:

```bash
bem list
bem ls
```

Show status:

```bash
bem status name
```

Remove a command:

```bash
bem remove name
bem rm name
```

This removes only the symlink from `~/.bem/bin`.
The original script is not deleted.

Uninstall `bem`:

```bash
bem uninstall-bem
```

Then remove the `PATH` and completion lines from your `.bashrc` file.

## Commands

```text
bem init
bem install [-n name] file ...
bem remove name ...
bem rm name ...
bem list
bem ls
bem status name ...
bem uninstall-bem
bem version
bem help
```

## Files

```text
~/.bem/
  bem_completion
  bin/
    bem -> /path/to/bem
    name -> /path/to/script
```

## Names

Command names must match:

```text
^[a-zA-Z0-9_][a-zA-Z0-9._-]*$
```

Maximum length: `64`.

`bem` refuses to install a command if the name already exists.
