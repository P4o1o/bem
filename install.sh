#!/usr/bin/env bash
#
# bem installer
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/<user>/bem/main/install.sh)
#   bash <(curl -fsSL ...) --full
#   bash <(curl -fsSL ...) -d ~/my/custom/path
#   bash <(curl -fsSL ...) -d ~/my/custom/path --full
#
# Options:
#   -d, --dir DIR   Install location (default: ~/.local/share/bem)
#   -f, --full      Also install bundled plugins (search, replace).
#   -h, --help      Show this help.
#

set -euo pipefail
umask 077

readonly BEM_REPO="https://github.com/<user>/bem.git"
readonly DEFAULT_DIR="${HOME}/.local/share/bem"

# ── Colors ───────────────────────────────────────────────────────────────────

if [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]]; then
    G=$'\033[32m' R=$'\033[31m' Y=$'\033[33m' B=$'\033[1m' D=$'\033[2m' N=$'\033[0m'
else
    G="" R="" Y="" B="" D="" N=""
fi

msg()  { printf '%s\n' "$*"; }
ok()   { printf '%s%s%s\n' "$G" "$*" "$N"; }
warn() { printf '%s%s%s\n' "$Y" "$*" "$N" >&2; }
die()  { printf '%sError: %s%s\n' "$R" "$*" "$N" >&2; exit 1; }

# ── Parse arguments ──────────────────────────────────────────────────────────

FULL_INSTALL=false
INSTALL_DIR="$DEFAULT_DIR"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--full) FULL_INSTALL=true ;;
        -d|--dir)
            [[ $# -ge 2 ]] || die "--dir requires a path."
            INSTALL_DIR="$2"; shift
            ;;
        -h|--help)
            cat <<EOF
${B}bem installer${N}

Usage:
  bash install.sh                          Install bem to default location.
  bash install.sh ${G}--full${N}                   Also install bundled plugins.
  bash install.sh ${G}-d ~/path${N}                Custom install location.
  bash install.sh ${G}-d ~/path --full${N}         Both.

Options:
  -d, --dir DIR   Where to clone bem (default: ${D}~/.local/share/bem${N}).
  -f, --full      Also install bundled plugins (search, replace).
  -h, --help      Show this help.

bem can live anywhere. The install directory is just where the git repo
is cloned. bem creates a symlink in ~/.local/bin/ regardless.
EOF
            exit 0
            ;;
        *) die "Unknown option: $1. Use -h for help." ;;
    esac
    shift
done

# ── Checks ───────────────────────────────────────────────────────────────────

msg "${B}bem${N} installer"
msg ""

if (( BASH_VERSINFO[0] < 4 )); then
    die "Bash 4.0+ is required. You have ${BASH_VERSION}."
fi

for cmd in git realpath flock; do
    command -v "$cmd" &>/dev/null || die "'${cmd}' is required but not found."
done

if [[ "$FULL_INSTALL" == true ]]; then
    command -v perl &>/dev/null || warn "'perl' not found. The 'replace' plugin requires it."
fi

# ── Install ──────────────────────────────────────────────────────────────────

if [[ -d "$INSTALL_DIR" ]]; then
    msg "Existing installation found at ${INSTALL_DIR}."
    msg "Updating..."
    if ! git -C "$INSTALL_DIR" pull --ff-only 2>&1; then
        die "Failed to update. To reinstall: rm -rf ${INSTALL_DIR} && re-run."
    fi
else
    msg "Cloning bem to ${INSTALL_DIR}..."
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone --depth 1 "$BEM_REPO" "$INSTALL_DIR" \
        || die "Failed to clone repository."
fi

chmod +x "${INSTALL_DIR}/bem"

# Run init (this creates the symlink ~/.local/bin/bem -> INSTALL_DIR/bem)
msg ""
msg "Running ${B}bem init${N}..."
bash "${INSTALL_DIR}/bem" init

# ── Bundled plugins ──────────────────────────────────────────────────────────

if [[ "$FULL_INSTALL" == true ]]; then
    msg ""
    msg "Installing bundled plugins..."

    for f in "${INSTALL_DIR}"/plugins/*; do
        [[ -f "$f" ]] || continue
        chmod +x "$f"

        local_name="${f##*/}"
        local_name="${local_name%.sh}"; local_name="${local_name%.bash}"

        if [[ -d "${HOME}/.bem/plugins/${local_name}" ]]; then
            msg "  ${D}${local_name}${N} already installed, skipping."
        else
            if bash "${INSTALL_DIR}/bem" install "$f"; then
                ok "  Installed '${local_name}'."
            else
                warn "  Failed to install '${local_name}'."
            fi
        fi
    done
else
    msg ""
    msg "${D}Tip: re-run with ${G}--full${D} to also install bundled plugins (search, replace).${N}"
fi

# ── Done ─────────────────────────────────────────────────────────────────────

msg ""
ok "Done!"
msg ""
msg "Run ${B}exec bash${N} to apply changes, then:"
msg "  ${G}bem help${N}          show all commands"
msg "  ${G}bem list${N}          list installed plugins"
