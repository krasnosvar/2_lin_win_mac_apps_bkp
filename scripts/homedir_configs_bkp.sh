#!/usr/bin/env bash
#
# homedir_configs_bkp.sh - zip user configs from $HOME (and readable files from /etc).
#
# Output: $HOME/homedir_configs_bkp-<dd-mm-YYYY>.zip
#
# Archive layout:
#   <path relative to $HOME>   - home configs (restore: unzip -d "$HOME" ...)
#   etc/...                    - /etc files   (restore: sudo unzip -d / ...)
#
# Credentials (ssh keys, cloud/k8s/docker tokens, gpg, AI-tool auth) are NOT
# included unless --with-secrets is passed. With it, the zip is chmod 600.
#
# Usage (run from the repository root):
#   ./scripts/homedir_configs_bkp.sh
#   ./scripts/homedir_configs_bkp.sh --list
#   ./scripts/homedir_configs_bkp.sh --no-etc
#   ./scripts/homedir_configs_bkp.sh --with-secrets
#
set -euo pipefail

LIST_ONLY=0
DO_ETC=1
DO_SECRETS=0

usage() {
  sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list) LIST_ONLY=1 ;;
    --no-etc) DO_ETC=0 ;;
    --with-secrets) DO_SECRETS=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

: "${HOME:?ERROR: HOME is not set}"
command -v zip >/dev/null || { echo "ERROR: zip is not installed" >&2; exit 1; }

OUT="${HOME}/homedir_configs_bkp-$(date +%d-%m-%Y).zip"
[[ -e "$OUT" ]] && { echo "ERROR: $OUT already exists" >&2; exit 1; }

# ---- paths relative to $HOME -------------------------------------------------
HOME_PATHS=(
  # shell
  .bashrc .bash_profile .bash_logout .profile .zshrc .zprofile .zshenv .p10k.zsh
  .inputrc .tmux.conf .vimrc .gtkrc-2.0
  # git / dev tooling
  .gitconfig .config/git .gitlab .terraform.d/credentials.tfrc.json
  .config/helm .config/k9s .config/htop .config/nvim .config/zed .config/opencode/opencode.json
  .ansible.cfg .ansible/ansible.cfg
  # terminal / desktop
  .byobu .local/share/konsole .config/warp-terminal
  .config/gtk-3.0 .config/gtk-4.0 .config/xsettingsd .config/flameshot .config/mimeapps.list
  .config/user-dirs.dirs .config/user-dirs.locale .config/kdeglobals .config/kdedefaults
  .config/kwinoutputconfig.json .config/konsolesshconfig .config/KDE .config/menus
  .config/autostart .config/systemd .config/dconf
  .config/plasma-org.kde.plasma.desktop-appletsrc
  .local/share/applications
  # apps
  .config/remmina .config/keepassxc .config/obs-studio .config/kicad .config/vlc .config/mpv
  .config/wireshark .config/VeraCrypt .config/inkscape .config/GIMP .config/libreoffice
  # editors / IDEs
  .config/Code/User/settings.json .config/Code/User/keybindings.json
  .config/Code/User/mcp.json .config/Code/User/snippets
  .config/Cursor/User/settings.json .config/Cursor/User/keybindings.json
  .config/Cursor/User/snippets .config/Cursor/User/profiles
  .config/VSCodium/User/settings.json .config/VSCodium/User/keybindings.json
  .config/VSCodium/User/snippets
  .config/Windsurf/User/settings.json .config/Windsurf/User/keybindings.json
  .config/Windsurf/User/snippets
  .vscode/argv.json .cursor/mcp.json .cursor/argv.json
  # AI tools (configs only; sessions/history/caches are skipped)
  .claude/settings.json .claude/CLAUDE.md .claude/skills .claude/commands .claude/agents
  .codex/config.toml .codex/AGENTS.md .codex/rules .codex/skills
  .gemini/settings.json .gemini/GEMINI.md
)

# KDE/Qt-style *rc files in ~/.config
shopt -s nullglob
for f in "${HOME}"/.config/*rc "${HOME}"/.config/*.conf; do
  HOME_PATHS+=("${f#"${HOME}"/}")
done
shopt -u nullglob

SECRET_HOME_PATHS=(
  .ssh .gnupg .aws .kube/config .docker/config.json .netrc .npmrc .config/gh
  .codex/auth.json .gemini/oauth_creds.json .gemini/google_accounts.json
)

# ---- absolute paths in /etc --------------------------------------------------
ETC_PATHS=(
  /etc/hosts /etc/fstab /etc/environment /etc/dnf/dnf.conf /etc/yum.repos.d
  /etc/ssh/ssh_config.d /etc/profile.d /etc/sysctl.d /etc/modprobe.d
  /etc/docker /etc/systemd/system /etc/NetworkManager/conf.d
)
SECRET_ETC_PATHS=(
  /etc/ssh/sshd_config /etc/sudoers.d /etc/NetworkManager/system-connections
)

# ---- collect existing paths --------------------------------------------------
existing_home=()
existing_etc=()

collect() { # collect <array-name> <base-dir> <path>...
  local -n dest="$1"; local base="$2"; shift 2
  local p
  for p in "$@"; do
    if [[ -e "${base}${p}" || -L "${base}${p}" ]]; then
      if [[ -r "${base}${p}" ]]; then dest+=("$p"); else echo "WARN: not readable, skipped: ${base}${p}" >&2; fi
    fi
  done
}

collect existing_home "${HOME}/" "${HOME_PATHS[@]}"
(( DO_SECRETS )) && collect existing_home "${HOME}/" "${SECRET_HOME_PATHS[@]}"
if (( DO_ETC )); then
  collect existing_etc "" "${ETC_PATHS[@]}"
  (( DO_SECRETS )) && collect existing_etc "" "${SECRET_ETC_PATHS[@]}"
fi

(( ${#existing_home[@]} + ${#existing_etc[@]} > 0 )) || { echo "ERROR: nothing to back up" >&2; exit 1; }

if (( LIST_ONLY )); then
  printf '%s\n' "${existing_home[@]}"
  (( ${#existing_etc[@]} )) && printf '%s\n' "${existing_etc[@]}"
  exit 0
fi

# ---- zip ---------------------------------------------------------------------
ZIP_EXCLUDES=(-x '*/.git/*' '*/node_modules/*' '*/Cache/*' '*/CachedData/*' '*/.cache/*' '*.sock' '*/.ssh-agent')

umask 077
if (( ${#existing_home[@]} )); then
  (cd "$HOME" && zip -r -y -q "$OUT" "${existing_home[@]}" "${ZIP_EXCLUDES[@]}")
fi
if (( ${#existing_etc[@]} )); then
  (cd / && zip -r -y -q -g "$OUT" "${existing_etc[@]#/}" "${ZIP_EXCLUDES[@]}")
fi

echo "OK: $OUT ($(du -h "$OUT" | cut -f1))"
