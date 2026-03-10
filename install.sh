#!/usr/bin/env bash
#
# bem installer
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/P4o1o/bem/main/install.sh)
#   bash <(curl -fsSL https://raw.githubusercontent.com/P4o1o/bem/main/install.sh) --full
#
# Options:
#   -f, --full    Also install bundled plugins (search, replace).
#   -h, --help    Show this help.
#
# To inspect before running:
#   curl -fsSL https://raw.githubusercontent.com/P4o1o/bem/main/install.sh | less
#

set -euo pipefail
umask 077

readonly BEM_REPO="https://github.com/P4o1o/bem.git"
readonly INSTALL_DIR="${HOME}/.local/share/bem"

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

ESSENTIAL_INSTALL=false
FULL_INSTALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--full) FULL_INSTALL=true ;;
        -e|--essential) ESSENTIAL_INSTALL=true ;;
        -h|--help)
            cat <<EOF
${B}bem installer${N}

Usage:
  bash install.sh                       bem only (RECOMMENDED)
  bash install.sh ${G}--full${N}        bem + bundled plugins (search, replace)
  bash install.sh ${G}--essential${N}   Download source code only (no git repo)

Options:
  -f, --full                            Also install bundled plugins.
        
  -e, --essential                       Download requested source code only,
                                        not all the git repo. 'curl' must be
                                        available to download the files.
                                        Use this only if you don't want to
                                        install git on your system.
                                        Note: you won't get updates or be able
                                        to contribute.

  -h, --help                            Show this help.
EOF
            exit 0
            ;;
        *)
            die "Unknown option: $1. Use -h for help."
            ;;
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

if [[ "$ESSENTIAL_INSTALL" == false ]]; then
    command -v git &>/dev/null ||  die "git is required for normal installation but not found."
else
    command -v curl &>/dev/null || die "curl is required for essential installation but not found."
fi

if [[ "$FULL_INSTALL" == true ]]; then
    command -v perl &>/dev/null || warn "'perl' not found. The 'replace' plugin requires it."
fi

# ── Install ──────────────────────────────────────────────────────────────────

if [[ -d "$INSTALL_DIR" ]]; then
    msg "Existing installation found at ${INSTALL_DIR}."
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        msg "Updating..."
        if ! git -C "$INSTALL_DIR" pull --ff-only 2>&1; then
            die "Failed to update. To reinstall: rm -rf ${INSTALL_DIR} && re-run."
        fi
    fi
else
    if [[ "$ESSENTIAL_INSTALL" == true ]]; then
        msg "Downloading bem script to ${INSTALL_DIR}..."
        mkdir -p "$(dirname "$INSTALL_DIR")"
        curl -fsSL "${BEM_REPO}/raw/main/LICENSE" -o "${INSTALL_DIR}/LICENSE" \
            || die "Failed to download the code LICENSE. Check your network and the URL."
        curl -fsSL "${BEM_REPO}/raw/main/bem" -o "${INSTALL_DIR}/bem" \
            || die "Failed to download bem script. Check your network and the URL."
    else
        msg "Cloning bem to ${INSTALL_DIR}..."
        mkdir -p "$(dirname "$INSTALL_DIR")"
        git clone --depth 1 "$BEM_REPO" "$INSTALL_DIR" \
            || die "Failed to clone repository. Check your network and the URL."
    fi
fi

# Make bem executable
chmod +x "${INSTALL_DIR}/bem"

# Run init
msg ""
msg "Running ${B}bem init${N}..."
bash "${INSTALL_DIR}/bem" init

# ── Bundled plugins (only with --full) ───────────────────────────────────────

if [[ "$FULL_INSTALL" == true ]]; then
    msg ""
    msg "Installing bundled plugins..."
    if [[ "$ESSENTIAL_INSTALL" == true ]]; then
        msg "Downloading bem plugins to ${INSTALL_DIR}/plugins..."
        mkdir -p "${INSTALL_DIR}/plugins"
        curl -fsSL "${BEM_REPO}/raw/main/plugins/search" -o "${INSTALL_DIR}/plugins/search" \
            || die "Failed to download search plugin. Check your network and the URL."
        curl -fsSL "${BEM_REPO}/raw/main/plugins/replace" -o "${INSTALL_DIR}/plugins/replace" \
            || die "Failed to download replace plugin. Check your network and the URL."
    fi
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

if [[ "$FULL_INSTALL" == false && "$ESSENTIAL_INSTALL" == false ]]; then
    msg ""
    msg "To install bundled plugins later:"
    msg "  ${G}bem install ${INSTALL_DIR}/plugins/search${N}"
    msg "  ${G}bem install ${INSTALL_DIR}/plugins/replace${N}"
fi
