#!/usr/bin/env bash
# Once per machine: makes the kit's gnome-ext plugin available to Claude Code.
#
#   .gnome-ai-kit/scripts/setup.sh           the plugin, then the tools check below
#   .gnome-ai-kit/scripts/setup.sh --tools   only the tools check
#
# Registers .gnome-ai-kit/ as the `gnome-extensions` plugin marketplace (a directory source,
# so skills are read from here live and a pull is all an update takes), installs the
# `gnome-ext` plugin, and leaves it switched off at user level: each extension's
# .claude/settings.json switches it on (`enabledPlugins`), so it is there in the
# extensions and nowhere else. Safe to run again.
#
# Then lists the tools the extensions' scripts need that this machine lacks, and the
# one pacman command that installs them; it installs nothing itself. What every
# extension needs is listed below (KIT_TOOLS); what one extension needs on top is its
# scripts/ext.conf's EXT_TOOLS. Each entry is CHECK|PACKAGE|WHAT FOR, where CHECK is
# cmd:NAME (a command on PATH) or py:MODULE (importable by python3).

set -euo pipefail

kit=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
root=$(dirname "$kit")

KIT_TOOLS=(
    "cmd:git|git|everything"
    "cmd:gh|github-cli|issues, pull requests, releases"
    "cmd:node|nodejs|ESLint (make lint)"
    "cmd:npm|npm|ESLint (make lint)"
    "cmd:gjs|gjs|the extensions' own checks"
    "cmd:glib-compile-schemas|glib2|make check, make pack"
    "cmd:gnome-extensions|gnome-shell|make pack, the nested shell"
    "cmd:mutter|mutter|the nested shell"
    "cmd:unzip|unzip|make pack's check of the zip"
    "py:gi|python-gobject|the nested shell's driver"
    "cmd:oxipng|oxipng|published screenshots (gnome-ext:screenshots)"
    "cmd:magick|imagemagick|JPEG screenshots, the social preview"
    "cmd:shellcheck|shellcheck|the kit's scripts/check.sh"
)

missing_tools() {
    local entry check pkg why name ext conf seen=" "
    local -a tools=("${KIT_TOOLS[@]/#/kit|}")
    for name in $(python3 -c 'import json,sys; print(" ".join(e["name"] for e in json.load(open(sys.argv[1]))["extensions"]))' "$kit/extensions.json"); do
        conf="$root/$name/scripts/ext.conf"
        [ -f "$conf" ] || continue
        while IFS= read -r entry; do
            [ -n "$entry" ] && tools+=("$name|$entry")
        done < <(bash -c 'EXT_TOOLS=(); source "$1" >/dev/null 2>&1; printf "%s\n" "${EXT_TOOLS[@]}"' _ "$conf")
    done
    for entry in "${tools[@]}"; do
        ext=${entry%%|*}; entry=${entry#*|}
        check=${entry%%|*}; entry=${entry#*|}
        pkg=${entry%%|*}; why=${entry#*|}
        case $check in
            cmd:*) command -v "${check#cmd:}" >/dev/null 2>&1 && continue ;;
            py:*)  python3 -c "import ${check#py:}" >/dev/null 2>&1 && continue ;;
        esac
        printf '  %-22s %-16s %s (%s)\n' "${check#*:}" "$pkg" "$why" "$ext"
        case $seen in *" $pkg "*) ;; *) seen="$seen$pkg " ;; esac
    done
    # shellcheck disable=SC2086  # a list of words
    [ "$seen" = " " ] || printf '\nInstall them with:\n  sudo pacman -S --needed%s\n' "${seen% }"
}

check_tools() {
    local out
    out=$(missing_tools)
    if [ -z "$out" ]; then
        echo "Tools: everything the extensions' scripts use is installed."
    else
        echo "Tools missing on this machine (missing, package, what for, who needs it):"
        echo "$out"
    fi
}

if [ "${1:-}" = --tools ]; then
    check_tools
    exit 0
fi

claude=$(type -P claude || true)
[ -n "$claude" ] || claude=$HOME/.local/bin/claude
if [ ! -x "$claude" ]; then
    echo "setup.sh: Claude Code (claude) is not installed" >&2
    exit 1
fi

marketplaces=$("$claude" plugin marketplace list 2>/dev/null || true)
if grep -qF "($kit)" <<< "$marketplaces"; then
    echo "Marketplace gnome-extensions: already registered"
else
    # Registered from another folder (the kit before .gnome-ai-kit/, or another clone).
    grep -q 'gnome-extensions' <<< "$marketplaces" && "$claude" plugin marketplace remove gnome-extensions
    "$claude" plugin marketplace add "$kit"
fi

if "$claude" plugin list 2>/dev/null | grep -q 'gnome-ext@gnome-extensions'; then
    echo "Plugin gnome-ext: already installed"
else
    "$claude" plugin install gnome-ext@gnome-extensions --scope user
fi

# Off at user level; the extensions' project settings turn it on.
"$claude" plugin disable gnome-ext@gnome-extensions --scope user >/dev/null 2>&1 || true

echo "Done. The gnome-ext skills load in sessions started in an extension beside the kit."
echo
check_tools
