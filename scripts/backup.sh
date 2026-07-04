#!/usr/bin/env bash
#
# backup.sh - one-file offline backup downloader.
#
# Downloads:
#   - app installers from apps.tsv for linux/macos/windows;
#   - Fedora repo RPM packages with resolved dependencies;
#   - Ubuntu/Debian repo DEB packages with dependencies when explicitly enabled;
#   - boot/rescue ISO images.
#
# Usage:
#   ./scripts/backup.sh
#   ./scripts/backup.sh --list
#   ./scripts/backup.sh --portable
#   ./scripts/backup.sh --no-iso
#   ./scripts/backup.sh --no-fedora-repo
#   ./scripts/backup.sh --with-ubuntu-repo
#   ./scripts/backup.sh --fedora-releasever 44
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APPS_MANIFEST="${REPO_DIR}/apps.tsv"
BACKUP_ROOT="${REPO_DIR}/backup"
APP_OUT_DIR="${BACKUP_ROOT}/apps"
ISO_OUT_DIR="${BACKUP_ROOT}/iso"

FEDORA_VER="44"
UBUNTU_LTS="26.04"

LIST_ONLY=0
INSTALLERS_ONLY=1
DO_APPS=1
DO_ISO=1
DO_FEDORA_REPO=1
DO_UBUNTU_REPO=0
DO_VSCODE=1
FEDORA_RELEASEVER="${FEDORA_VER}"
APP_OS_LIST=(linux macos windows)
APP_ARCH=""
FEDORA_LIST=""
UBUNTU_LIST=""

usage() {
  cat <<'EOF'
backup.sh - one-file offline backup downloader.

Usage:
  ./scripts/backup.sh
  ./scripts/backup.sh --list
  ./scripts/backup.sh --portable
  ./scripts/backup.sh --no-iso
  ./scripts/backup.sh --no-fedora-repo
  ./scripts/backup.sh --with-ubuntu-repo
  ./scripts/backup.sh --fedora-releasever 44
  ./scripts/backup.sh --no-vscode

Main outputs:
  backup/apps/
  backup/repo-packages/
  backup/iso/
  backup/vscode-extensions/
EOF
}

default_fedora_packages() {
  cat <<'EOF'
git
wget2-wget
gnupg2
lsb_release
apt
ca-certificates
curl
dnf-plugins-core
plasma-workspace-x11
sysfsutils
sysstat
htop
fd-find
ripgrep
direnv
tree
byobu
tmux
screen
bat
rsync
lsof
strace
smartmontools
lm_sensors
radeontop
nvtop
gh
vim-enhanced
neovim
zsh
libreoffice
gimp
gimp-devel
libheif-freeworld
inkscape
blender
audacity
vlc
flameshot
telegram-desktop
librecad
kicad
kicad-packages3d
kicad-doc
ffmpeg-libs
obs-studio
mpv
ktorrent
pdftk-java
qemu-kvm
virt-install
virt-manager
virt-viewer
libvirt-daemon-kvm
libvirt-daemon-config-network
veracrypt
keepassxc
vivaldi-stable
chromium
fedora-workstation-repositories
google-chrome-stable
brave-browser
opera-stable
arp-scan
mtr
wireshark
wireshark-cli
traceroute
nmap
nmap-ncat
tcpdump
whois
bind-utils
socat
ethtool
iproute-tc
iw
wavemon
openconnect
NetworkManager-openconnect
openfortivpn
openvpn
NetworkManager-openvpn
wireguard-tools
net-tools
openssh-server
remmina
sshuttle
tigervnc
plasma-nm
postgresql
mariadb
mongocli
mongodb-atlas-cli
task
ansible
terraform
packer
tofu
docker-ce
docker-ce-cli
containerd.io
docker-buildx-plugin
docker-compose-plugin
k9s
age
yq
jq
awscli2
jsonnet
podman
skopeo
toolbox
nodejs
python3
golang
golangci-lint
protobuf-compiler
golang-google-protobuf
golang-google-grpc
graphviz
java-21-openjdk-devel
java-25-openjdk-devel
minicom
esptool
code
codium
cursor
antigravity
devin-desktop
warp-terminal
EOF
}

default_ubuntu_packages() {
  cat <<'EOF'
arp-scan
mtr
wireshark
traceroute
arping
sngrep
nmap
netcat-openbsd
iperf3
tcpdump
whois
dnsutils
telnet
socat
ethtool
iproute2
iw
wavemon
aircrack-ng
sshpass
ldap-utils
openssh-server
remmina
sshuttle
tigervnc-viewer
filezilla
openconnect
network-manager-openconnect
network-manager-openconnect-gnome
openfortivpn
openvpn
network-manager-openvpn
wireguard-tools
net-tools
lsof
strace
smartmontools
EOF
}

vscode_extensions() {
  cat <<'EOF'
ms-python.python
golang.Go
redhat.java
mathiasfrohlich.kotlin
redhat.vscode-yaml
ms-azuretools.vscode-docker
ms-kubernetes-tools.vscode-kubernetes-tools
hashicorp.terraform
ms-vscode-remote.remote-containers
eamodio.gitlens
gitlab.gitlab-workflow
mtxr.sqltools
davidanson.vscode-markdownlint
domdomegg.markdown-inline-preview-vscode
tomoki1207.pdf
Codeium.codeium
github.copilot-chat
usernamehw.errorlens
Gruntfuggly.todo-tree
alefragnani.Bookmarks
humao.rest-client
esbenp.prettier-vscode
ms-vscode.cpptools
rust-lang.rust-analyzer
dbaeumer.vscode-eslint
oderwat.indent-rainbow
redhat.ansible
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --list) LIST_ONLY=1; shift ;;
    --portable|--all-formats) INSTALLERS_ONLY=0; shift ;;
    --os) APP_OS_LIST=("$2"); shift 2 ;;
    --arch) APP_ARCH="$2"; shift 2 ;;
    --no-apps) DO_APPS=0; shift ;;
    --no-iso) DO_ISO=0; shift ;;
    --only-iso) DO_APPS=0; DO_FEDORA_REPO=0; DO_UBUNTU_REPO=0; DO_VSCODE=0; DO_ISO=1; shift ;;
    --no-vscode) DO_VSCODE=0; shift ;;
    --no-fedora-repo|--no-repo) DO_FEDORA_REPO=0; shift ;;
    --fedora-releasever) FEDORA_RELEASEVER="$2"; shift 2 ;;
    --fedora-list) FEDORA_LIST="$2"; shift 2 ;;
    --with-ubuntu-repo) DO_UBUNTU_REPO=1; shift ;;
    --ubuntu-list) UBUNTU_LIST="$2"; DO_UBUNTU_REPO=1; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

is_installer_ext() {
  case "$1" in
    rpm|deb|dmg|pkg|msi|exe) return 0 ;;
    *) return 1 ;;
  esac
}

write_checksum() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    ( cd "$(dirname "$f")" && sha256sum "$(basename "$f")" > "$(basename "$f").sha256" )
  elif command -v shasum >/dev/null 2>&1; then
    ( cd "$(dirname "$f")" && shasum -a 256 "$(basename "$f")" > "$(basename "$f").sha256" )
  fi
}

checksum_ok() {
  local f="$1"
  [ -s "$f" ] || return 1
  [ -s "$f.sha256" ] || return 1
  if command -v sha256sum >/dev/null 2>&1; then
    ( cd "$(dirname "$f")" && sha256sum -c "$(basename "$f").sha256" >/dev/null 2>&1 )
  elif command -v shasum >/dev/null 2>&1; then
    ( cd "$(dirname "$f")" && shasum -a 256 -c "$(basename "$f").sha256" >/dev/null 2>&1 )
  else
    return 1
  fi
}

sanitize_filename() {
  printf '%s\n' "$1" | sed -E 's#[/\\]#_#g; s/^[[:space:]]+//; s/[[:space:]]+$//'
}

url_path_filename() {
  local clean name
  clean="${1%%#*}"
  clean="${clean%%\?*}"
  name="${clean##*/}"
  [ -n "$name" ] && [ "$name" != "$clean" ] || return 1
  name="${name//%20/ }"
  sanitize_filename "$name"
}

content_disposition_filename() {
  awk '
    BEGIN { IGNORECASE = 1 }
    /^content-disposition:/ { line = $0 }
    END {
      sub(/\r$/, "", line)
      if (match(line, /filename\*=UTF-8'\'''\''[^;]+/)) {
        name = substr(line, RSTART + 17, RLENGTH - 17)
        print name
      } else if (match(line, /filename="?[^";]+"?/)) {
        name = substr(line, RSTART + 9, RLENGTH - 9)
        gsub(/^"|"$/, "", name)
        print name
      }
    }
  '
}

remote_filename() {
  local url="$1" fallback="$2" ext="$3" name headers effective_url
  name="$(url_path_filename "$url" || true)"
  if [ -n "$name" ] && { [ "$ext" = "bin" ] || [ "$ext" = "run" ] || [[ "$name" == *".${ext}" ]]; }; then
    printf '%s\n' "$name"
    return 0
  fi

  headers="$(curl -fsSIL "$url" 2>/dev/null || true)"
  name="$(printf '%s\n' "$headers" | content_disposition_filename | tail -n1)"
  if [ -n "$name" ]; then
    name="${name//%20/ }"
    sanitize_filename "$name"
    return 0
  fi

  effective_url="$(curl -fsSIL -o /dev/null -w '%{url_effective}' "$url" 2>/dev/null || true)"
  name="$(url_path_filename "$effective_url" || true)"
  if [ -n "$name" ] && { [ "$ext" = "bin" ] || [ "$ext" = "run" ] || [[ "$name" == *".${ext}" ]]; }; then
    printf '%s\n' "$name"
    return 0
  fi

  printf '%s\n' "$fallback"
}

gh_latest_tag() {
  curl -sIL "https://github.com/$1/releases/latest" \
    | grep -i '^location:' | grep -oE 'tag/[^[:space:]]+' \
    | sed 's#tag/##' | tr -d '\r' | tail -n1
}

list_index() {
  curl -fsSL "$1" 2>/dev/null \
    | grep -oE 'href="[^"]+"' | sed -E 's/href="([^"]+)"/\1/' \
    | sed -E 's#^.*/([^/]+/?)$#\1#'
}

resolve_dir() {
  local url="$1" seg="$2"; shift 2
  local names; names="$(list_index "$url" | grep -E "$seg" | sort -Vr)"
  [ -z "$names" ] && return 1
  if [ $# -eq 0 ]; then
    printf '%s%s\n' "$url" "$(printf '%s\n' "$names" | head -n1)"
    return 0
  fi
  local d
  while IFS= read -r d; do
    [ -z "$d" ] && continue
    resolve_dir "${url%/}/${d%/}/" "$@" && return 0
  done <<< "$names"
  return 1
}

resolve_url() {
  local src="$1"
  case "$src" in
    gh:*)
      local body repo regex tag file
      body="${src#gh:}"; repo="${body%%:*}"; regex="${body#*:}"
      tag="$(gh_latest_tag "$repo")"; [ -z "$tag" ] && return 1
      file="$(curl -fsSL "https://github.com/${repo}/releases/expanded_assets/${tag}" \
        | grep -oE "/${repo}/releases/download/[^\"]+" \
        | sed 's#.*/##' | grep -E "$regex" | head -n1)"
      [ -z "$file" ] && return 1
      printf 'https://github.com/%s/releases/download/%s/%s\n' "$repo" "$tag" "$file"
      ;;
    ghtag:*)
      local body repo tmpl tag ver
      body="${src#ghtag:}"; repo="${body%%:*}"; tmpl="${body#*:}"
      tag="$(gh_latest_tag "$repo")"; [ -z "$tag" ] && return 1
      ver="${tag#v}"
      tmpl="${tmpl//\{tag\}/$tag}"; tmpl="${tmpl//\{ver\}/$ver}"
      printf '%s\n' "$tmpl"
      ;;
    dir:*)
      local body; body="${src#dir:}"
      local -a segs; IFS='|' read -r -a segs <<< "$body"
      resolve_dir "${segs[0]}" "${segs[@]:1}"
      ;;
    page:*)
      local body base regex
      body="${src#page:}"; base="${body%%|*}"; regex="${body#*|}"
      curl -fsSL "$base" 2>/dev/null \
        | grep -oE 'https?://[^"'"'"' <>]+' \
        | grep -E "$regex" | head -n1
      ;;
    file:*)
      printf '%s\n' "${src#file:}"
      ;;
    http*://*)
      printf '%s\n' "$src"
      ;;
    *)
      return 1
      ;;
  esac
}

read_package_list() {
  sed -E 's/#.*$//; /^[[:space:]]*$/d; s/^[[:space:]]+//; s/[[:space:]]+$//'
}

fedora_packages() {
  if [ -n "$FEDORA_LIST" ]; then
    read_package_list < "$FEDORA_LIST"
  else
    default_fedora_packages
  fi
}

ubuntu_packages() {
  if [ -n "$UBUNTU_LIST" ]; then
    read_package_list < "$UBUNTU_LIST"
  else
    default_ubuntu_packages
  fi
}

download_apps_for_os() {
  local os="$1" ok=0 skip=0 fail=0
  echo "==================== APPS: ${os} ===================="
  if [ "$INSTALLERS_ONLY" = 1 ]; then
    echo "OS=${os}  ARCH=${APP_ARCH:-all}  TYPES=installers  ->  ${APP_OUT_DIR}"
  else
    echo "OS=${os}  ARCH=${APP_ARCH:-all}  TYPES=all  ->  ${APP_OUT_DIR}"
  fi

  while IFS=$'\t' read -r group app m_os m_arch ext source; do
    [ -z "${group:-}" ] && continue
    case "$group" in \#*) continue ;; esac
    [ "$m_os" = "$os" ] || continue
    if [ -n "$APP_ARCH" ] && [ "$m_arch" != "$APP_ARCH" ]; then continue; fi
    if [ "$INSTALLERS_ONLY" = 1 ] && ! is_installer_ext "$ext"; then
      skip=$((skip+1))
      continue
    fi

    url="$(resolve_url "$source" || true)"
    if [ -z "$url" ]; then
      echo "  ! SKIP  ${group}/${app} ${m_os}-${m_arch} (could not resolve: ${source})"
      fail=$((fail+1))
      continue
    fi

    dest_name="$(remote_filename "$url" "${m_os}-${m_arch}.${ext}" "$ext")"
    dest_dir="${APP_OUT_DIR}/${group}/${app}/${m_os}-${m_arch}"
    dest="${dest_dir}/${dest_name}"

    if [ "$LIST_ONLY" != 1 ] && checksum_ok "$dest"; then
      echo "  = OK    ${group}/${app} ${m_os}-${m_arch}/${dest_name} (checksum ok)"
      skip=$((skip+1))
      continue
    fi

    echo "  · ${group}/${app} ${m_os}-${m_arch}/${dest_name}  <-  ${url}"
    if [ "$LIST_ONLY" = 1 ]; then
      continue
    fi

    mkdir -p "$dest_dir"
    if curl -fL --retry 3 --retry-delay 2 -C - -o "$dest" "$url"; then
      write_checksum "$dest"
      ok=$((ok+1))
    else
      echo "    !! failed: ${url}" >&2
      fail=$((fail+1))
    fi
  done < "$APPS_MANIFEST"

  echo "done ${os}: ${ok} downloaded, ${skip} skipped, ${fail} failed/unresolved"
}

iso_entries() {
  cat <<EOF
fedora-workstation	dir:https://download.fedoraproject.org/pub/fedora/linux/releases/${FEDORA_VER}/Workstation/x86_64/iso/|Fedora-Workstation-.*x86_64.*\.iso$
ubuntu-desktop-lts	dir:https://releases.ubuntu.com/${UBUNTU_LTS}/|ubuntu-${UBUNTU_LTS}.*-desktop-amd64\.iso$
debian-netinst	dir:https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/|debian-[0-9].*-amd64-netinst\.iso$
kali-installer	dir:https://cdimage.kali.org/current/|kali-linux-.*-installer-amd64\.iso$
arch	dir:https://mirror.rackspace.com/archlinux/iso/latest/|archlinux-.*-x86_64\.iso$
hirens-bootcd-pe	file:https://www.hirensbootcd.org/files/HBCD_PE_x64.iso
rescuezilla	gh:rescuezilla/rescuezilla:rescuezilla-.*\.iso$
ventoy-linux	gh:ventoy/Ventoy:ventoy-.*-linux\.tar\.gz$
ventoy-windows	gh:ventoy/Ventoy:ventoy-.*-windows\.zip$
gparted-live	page:https://sourceforge.net/projects/gparted/rss?path=/gparted-live-stable|https://sourceforge.net/projects/gparted/files/gparted-live-stable/[0-9.-]+/gparted-live-[0-9.-]+-amd64\.iso/download
clonezilla-live	page:https://sourceforge.net/projects/clonezilla/rss?path=/clonezilla_live_stable|https://sourceforge.net/projects/clonezilla/files/clonezilla_live_stable/[0-9.-]+/clonezilla-live-[0-9.-]+-amd64\.iso/download
systemrescue	page:https://sourceforge.net/projects/systemrescuecd/rss?path=/sysresccd-x86|https://sourceforge.net/projects/systemrescuecd/files/sysresccd-x86/[0-9.-]+/systemrescue-[0-9.-]+-amd64\.iso/download
redorescue	gh:redorescue/redorescue:redorescue-[0-9.-]+\.iso$
ubcd	file:https://mirror.sysadmin.network/pub/ubcd/ubcd533.iso
EOF
}

download_isos() {
  local ok=0 fail=0
  echo "==================== ISO IMAGES ===================="
  while IFS=$'\t' read -r name source; do
    [ -z "${name:-}" ] && continue
    url="$(resolve_url "$source" || true)"
    if [ -z "$url" ]; then
      echo "  ! SKIP  ${name} (could not resolve: ${source})"
      fail=$((fail+1))
      continue
    fi
    fname="$(url_path_filename "$url" || printf '%s.iso' "$name")"
    echo "  · ${name}: ${fname}  <-  ${url}"
    if [ "$LIST_ONLY" = 1 ]; then
      continue
    fi
    mkdir -p "${ISO_OUT_DIR}/${name}"
    dest="${ISO_OUT_DIR}/${name}/${fname}"
    if checksum_ok "$dest"; then
      echo "    = checksum ok"
      continue
    fi
    if curl -fL --retry 3 --retry-delay 2 -C - -o "$dest" "$url"; then
      write_checksum "$dest"
      ok=$((ok+1))
    else
      echo "    !! failed: ${url}" >&2
      fail=$((fail+1))
    fi
  done < <(iso_entries)
  echo "done isos: ${ok} downloaded, ${fail} failed/unresolved"
}

download_fedora_repo() {
  echo "==================== FEDORA REPO PACKAGES ===================="
  if ! command -v dnf >/dev/null 2>&1; then
    echo "dnf not found; skipping Fedora repo packages. Use --no-fedora-repo on non-Fedora hosts."
    return 0
  fi

  local releasever="$FEDORA_RELEASEVER"
  local arch; arch="$(rpm -E %_arch 2>/dev/null || uname -m)"
  local out_dir="${BACKUP_ROOT}/repo-packages/fedora-${releasever}-${arch}"
  mapfile -t packages < <(fedora_packages)

  echo "Fedora release: ${releasever}  arch: ${arch}"
  echo "Packages: ${#packages[@]}  ->  ${out_dir}"
  if [ "$LIST_ONLY" = 1 ]; then
    printf '  · %s\n' "${packages[@]}"
    echo "dry-run only; no RPMs downloaded"
    return 0
  fi

  mkdir -p "$out_dir"
  local fail_log="${out_dir}/FAILED.txt"
  : > "$fail_log"
  local ok=0 fail=0 pkg
  for pkg in "${packages[@]}"; do
    echo "  > ${pkg}"
    if dnf -y --nogpgcheck --releasever="$releasever" --forcearch="$arch" \
      --setopt=gpgcheck=0 --setopt=repo_gpgcheck=0 \
      download --resolve --skip-unavailable --exclude="*.i686" --destdir "$out_dir" "$pkg"; then
      ok=$((ok+1))
    else
      echo "$pkg" >> "$fail_log"
      fail=$((fail+1))
    fi
  done

  if command -v sha256sum >/dev/null 2>&1; then
    ( cd "$out_dir" && find . -maxdepth 1 -type f -name '*.rpm' -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS )
  fi
  echo "done fedora repo: ${ok} package requests ok, ${fail} failed; RPMs -> ${out_dir}"
  [ "$fail" -eq 0 ] || echo "failed package names -> ${fail_log}"
}

download_ubuntu_repo() {
  echo "==================== UBUNTU/DEBIAN REPO PACKAGES ===================="
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "apt-get not found; skipping Ubuntu/Debian repo packages."
    return 0
  fi
  local codename arch out_dir
  codename="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-unknown}")"
  arch="$(dpkg --print-architecture)"
  out_dir="${BACKUP_ROOT}/repo-packages/ubuntu-${codename}-${arch}"
  mapfile -t packages < <(ubuntu_packages)

  echo "Ubuntu/Debian codename: ${codename}  arch: ${arch}"
  echo "Packages: ${#packages[@]}  ->  ${out_dir}"
  if [ "$LIST_ONLY" = 1 ]; then
    printf '  · %s\n' "${packages[@]}"
    echo "dry-run only; no DEBs downloaded"
    return 0
  fi

  mkdir -p "$out_dir"
  apt-get update
  apt-get install --download-only --reinstall \
    -o Dir::Cache::archives="$out_dir" \
    -o Dir::Cache::archives::partial="${out_dir}/partial" \
    -y "${packages[@]}"
  rm -rf "${out_dir}/partial" "${out_dir}/lock"
  if command -v sha256sum >/dev/null 2>&1; then
    ( cd "$out_dir" && sha256sum ./*.deb > SHA256SUMS )
  fi
  echo "done ubuntu/debian repo: DEBs -> ${out_dir}"
}

download_vscode_extensions() {
  local ext_dir="${BACKUP_ROOT}/vscode-extensions"
  local ok=0 skip=0 fail=0
  
  echo "==================== VSCODE EXTENSIONS ===================="
  if [ "$LIST_ONLY" = 1 ]; then
    echo "Planned VSCode extensions -> ${ext_dir}"
    vscode_extensions | sed 's/^/  · /'
    echo "dry-run only; no extensions downloaded"
    return 0
  fi

  mkdir -p "$ext_dir"
  
  while read -r ext; do
    [ -z "$ext" ] && continue
    case "$ext" in \#*) continue ;; esac
    
    local pub="${ext%%.*}"
    local name="${ext#*.}"
    local url="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${pub}/vsextensions/${name}/latest/vspackage"
    local dest="${ext_dir}/${ext}.vsix"
    
    if [ -s "$dest" ]; then
      echo "  = OK    ${ext} (already exists)"
      skip=$((skip+1))
      continue
    fi
    
    echo "  · ${ext}  <-  ${url}"
    if curl -fsSL -o "${dest}.tmp" "$url"; then
      mv "${dest}.tmp" "$dest"
      ok=$((ok+1))
    else
      echo "    !! failed: ${url}" >&2
      rm -f "${dest}.tmp"
      fail=$((fail+1))
    fi
  done < <(vscode_extensions)
  
  echo "done vscode: ${ok} downloaded, ${skip} skipped, ${fail} failed"
}

print_plan() {
  if [ "$DO_APPS" = 1 ]; then
    if [ "$INSTALLERS_ONLY" = 1 ]; then
      echo "Planned app installers from apps.tsv:"
      awk -F '\t' '
        NF >= 6 && $1 !~ /^#/ && $5 ~ /^(rpm|deb|dmg|pkg|msi|exe)$/ { count[$3]++ }
        END {
          printf "  linux:   %d rpm/deb/etc\n", count["linux"] + 0
          printf "  macos:   %d dmg/pkg/etc\n", count["macos"] + 0
          printf "  windows: %d msi/exe/etc\n", count["windows"] + 0
        }
      ' "$APPS_MANIFEST"
    else
      echo "Planned app files from apps.tsv: all formats, including portable archives/binaries."
    fi
  fi

  if [ "$DO_FEDORA_REPO" = 1 ]; then
    local repo_count
    repo_count="$(fedora_packages | wc -l | tr -d ' ')"
    echo "Planned Fedora ${FEDORA_RELEASEVER} repo packages: ${repo_count} package requests; dependencies resolved into one folder"
  fi
  if [ "$DO_UBUNTU_REPO" = 1 ]; then
    local ubuntu_count
    ubuntu_count="$(ubuntu_packages | wc -l | tr -d ' ')"
    echo "Planned Ubuntu/Debian repo packages: ${ubuntu_count} package requests; dependencies resolved into one folder"
  fi
  if [ "$DO_VSCODE" = 1 ]; then
    local vscode_count
    vscode_count="$(vscode_extensions | wc -l | tr -d ' ')"
    echo "Planned VSCode extensions: ${vscode_count} extensions -> backup/vscode-extensions/"
  fi
  echo
}

print_plan

if [ "$DO_APPS" = 1 ]; then
  for os in "${APP_OS_LIST[@]}"; do
    download_apps_for_os "$os"
  done
fi

if [ "$DO_ISO" = 1 ]; then
  download_isos
fi

if [ "$DO_FEDORA_REPO" = 1 ]; then
  download_fedora_repo
fi

if [ "$DO_UBUNTU_REPO" = 1 ]; then
  download_ubuntu_repo
fi

if [ "$DO_VSCODE" = 1 ]; then
  download_vscode_extensions
fi

echo "==================== ALL DONE ===================="
echo "apps -> ${APP_OUT_DIR}    repo packages -> ${BACKUP_ROOT}/repo-packages    isos -> ${ISO_OUT_DIR}"
