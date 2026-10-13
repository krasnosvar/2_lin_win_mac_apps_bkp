# 🛡️ Offline App & OS Backup — "Doomsday" Kit

> **One script, three platforms, complete offline recovery.**
>
> Automated download of **320+ app installers** (Linux, macOS, Windows),
> **131 Fedora repo packages** with all dependencies, **14 bootable ISO images**,
> and **27 VSCode extensions** — everything you need to rebuild a workstation
> from scratch with zero internet access.

---

## 📦 What's Inside

| Category | Count | Description |
|---|---|---|
| **App installers** | 320 entries | RPM, DEB, DMG, PKG, MSI, EXE, AppImage, tar.gz, zip |
| **Fedora repo packages** | 131 packages | Full dependency tree via `dnf download --resolve` |
| **Ubuntu/Debian packages** | 37 packages | Optional, network/remote diagnostics focus |
| **Boot/rescue ISOs** | 14 images | Fedora, Ubuntu, Debian, Kali, Arch, rescue tools |
| **VSCode extensions** | 27 .vsix | Python, Go, Docker, K8s, Terraform, GitLens, AI tools |

### App Categories

| Group | Apps | Examples |
|---|---|---|
| 🌐 Browsers | 22 | Chrome, Brave, Firefox, Vivaldi, Tor, Opera, Floorp |
| 🛠️ DevOps / K8s | 57 | Terraform, Helm, kubectl, k9s, istioctl, SOPS, AWS CLI |
| 💬 Communications | 15 | Telegram, Slack, Zoom, Discord |
| 🔒 Security | 10 | KeePassXC, VeraCrypt |
| 🌐 Network | 18 | Postman, Insomnia, Wireshark, Nmap, WinMTR |
| 🗄️ Database | 5 | DBeaver |
| 📐 CAD / EDA | 11 | FreeCAD, OpenSCAD, KiCad |
| 💻 Dev / IDEs | 36 | VSCode, VSCodium, Zed, Cursor, PyCharm, IntelliJ, Devin |
| 🔤 Languages | 25 | Python, Go, Node.js, Rust, Java (Temurin 8/21) |
| 📦 Containers | 18 | Docker Desktop/Engine, Podman, Rancher Desktop |
| 🎬 Media | 25 | OBS, Shotcut, Audacity, HandBrake, VLC, GIMP, Blender |
| 📝 Office | 18 | LibreOffice + RU langpack, Neovim, Notepad++ |
| 🔧 Utilities | 37 | Rufus, Etcher, draw.io, 7-Zip, Sysinternals, Steam |
| 🔌 Arduino | 12 | Arduino IDE/CLI, MicroPython Lab |
| 🖥️ Virtualization | 11 | VirtualBox, Vagrant |

---

## 🚀 Quick Start

### Linux / macOS

```bash
git clone https://github.com/krasnosvar/2_lin_win_mac_apps_bkp.git
cd 2_lin_win_mac_apps_bkp

# dry-run — see what will be downloaded
./scripts/backup.sh --list

# full download
sudo ./scripts/backup.sh
```

### Windows (PowerShell)

```powershell
git clone https://github.com/krasnosvar/2_lin_win_mac_apps_bkp.git
cd 2_lin_win_mac_apps_bkp

# dry-run
powershell -ExecutionPolicy Bypass -File .\scripts\backup.ps1 -List

# download Windows installers
powershell -ExecutionPolicy Bypass -File .\scripts\backup.ps1 -InstallersOnly
```

### Home dir configs (Linux)

```bash
# from the repository root
./scripts/homedir_configs_bkp.sh                 # -> ~/homedir_configs_bkp-DD-MM-YYYY.zip
./scripts/homedir_configs_bkp.sh --list          # show what will be archived
./scripts/homedir_configs_bkp.sh --no-etc        # skip /etc
./scripts/homedir_configs_bkp.sh --with-secrets  # also ssh/gpg/aws/kube/docker/AI-tool auth
```

Restore: `unzip -d "$HOME" <zip>`; for `/etc`: `sudo unzip -d / <zip> 'etc/*'`.

---

## ⚙️ CLI Options

### backup.sh (Linux / macOS)

| Flag | Description |
|---|---|
| `--list` | Dry-run: show what would be downloaded |
| `--portable` | Include portable archives (tar.gz, zip, AppImage), not just native installers |
| `--os linux\|macos\|windows` | Download for a specific OS only |
| `--no-iso` | Skip ISO image downloads |
| `--no-repo` | Skip Fedora repo package mirroring |
| `--no-vscode` | Skip VSCode extension downloads |
| `--no-apps` | Skip app installer downloads |
| `--only-iso` | Download ISOs only |
| `--fedora-releasever N` | Override Fedora version (default: 44) |
| `--with-ubuntu-repo` | Enable Ubuntu/Debian package mirror (off by default) |
| `--fedora-list FILE` | Use external package list instead of built-in |
| `--ubuntu-list FILE` | Use external Ubuntu package list |

### backup.ps1 (Windows)

| Flag | Description |
|---|---|
| `-List` | Dry-run |
| `-Os windows` | Target OS |
| `-Arch x64` | Target architecture |
| `-InstallersOnly` | Only native installers (MSI/EXE) |

---

## 📁 Repository Structure

```
2_lin_win_mac_apps_bkp/
├── README.md                  # this file
├── apps.tsv                   # 320 app entries — the main download manifest
├── scripts/
│   ├── backup.sh              # Linux/macOS unified downloader (~760 lines)
│   ├── backup.ps1             # Windows PowerShell downloader
│   └── homedir_configs_bkp.sh # zip of $HOME / /etc configs -> ~/homedir_configs_bkp-DD-MM-YYYY.zip
└── backup/                    # ⛔ .gitignored — downloaded payload
    ├── apps/                  #   installers sorted by group/app/os-arch/
    ├── repo-packages/         #   Fedora/Ubuntu RPM/DEB caches
    │   └── fedora-44-x86_64/  #     full dependency tree
    ├── iso/                   #   bootable OS and rescue images
    └── vscode-extensions/     #   .vsix plugins for offline IDE setup
```

---

## 🔧 Manifest Format (`apps.tsv`)

Tab-separated, one row per downloadable file:

```
group    app    os    arch    ext    source
```

**Source types:**

| Prefix | Description | Example |
|---|---|---|
| `https://...` | Direct URL | `https://dl.google.com/...` |
| `gh:owner/repo:REGEX` | Latest GitHub release asset matching regex | `gh:brave/brave-browser:.*x86_64\.rpm$` |
| `ghtag:owner/repo:URL` | GitHub tag substituted into URL template | `ghtag:helm/helm:https://get.helm.sh/helm-{tag}-linux-amd64.tar.gz` |
| `dir:BASE\|SEG\|...\|FILE` | Newest file in directory index chain | `dir:https://go.dev/dl/\|go[0-9.]+\.linux-amd64\.tar\.gz$` |
| `page:URL\|REGEX` | First matching link scraped from a page | `page:https://www.wireshark.org/download.html\|...` |

---

## 💿 ISO Images

Auto-downloaded by `backup.sh`:

| Image | Purpose |
|---|---|
| **Fedora Workstation** | Main desktop Linux |
| **Ubuntu Desktop LTS** | Ubuntu 26.04 LTS desktop |
| **Debian netinst** | Minimal Debian stable installer |
| **Kali Linux** | Security / pentest distro |
| **Arch Linux** | Rolling-release Linux |
| **Hiren's BootCD PE** | Windows PE rescue & diagnostics |
| **Rescuezilla** | GUI backup / restore / clone |
| **Ventoy** | Multi-boot USB creator (Linux + Windows builds) |
| **GParted Live** | Partition management live CD |
| **Clonezilla Live** | Disk imaging & cloning |
| **SystemRescue** | Advanced Linux system rescue toolkit |
| **Redo Rescue** | Easy GUI backup and recovery |
| **UBCD** | Legacy BIOS diagnostic tool collection |

### ⚠️ Manual Download Required

These ISOs cannot be scripted (session-bound links / personal cloud):

| Image | URL |
|---|---|
| Windows 11 | https://www.microsoft.com/software-download/windows11 |
| Sergei Strelec's WinPE | https://sergeistrelec.name/ |

Save manually into `backup/iso/windows11/` and `backup/iso/strelec-winpe/`.

---

## 📦 Fedora Repo Packages (131 packages)

These are system-level packages backed up via `dnf download --resolve`, not standalone installers.
All dependencies are resolved into a single flat folder.

<details>
<summary>Full package list (click to expand)</summary>

**System / CLI tools:**
`git` `wget2-wget` `gnupg2` `lsb_release` `apt` `ca-certificates` `curl`
`dnf-plugins-core` `sysfsutils` `sysstat` `htop` `fd-find` `ripgrep`
`direnv` `tree` `byobu` `tmux` `screen` `bat` `rsync` `lsof` `strace`
`smartmontools` `lm_sensors` `radeontop` `nvtop` `gh` `vim-enhanced`
`neovim` `zsh`

**Desktop / media / office:**
`plasma-workspace-x11` `libreoffice` `gimp` `gimp-devel`
`libheif-freeworld` `inkscape` `blender` `audacity` `vlc` `flameshot`
`telegram-desktop` `librecad` `kicad` `kicad-packages3d` `kicad-doc`
`ffmpeg-libs` `obs-studio` `mpv` `ktorrent` `pdftk-java`

**Virtualization:**
`qemu-kvm` `virt-install` `virt-manager` `virt-viewer`
`libvirt-daemon-kvm` `libvirt-daemon-config-network`

**Security / browsers:**
`veracrypt` `keepassxc` `vivaldi-stable` `chromium`
`fedora-workstation-repositories` `google-chrome-stable` `brave-browser`
`opera-stable`

**Networking / VPN:**
`arp-scan` `mtr` `wireshark` `wireshark-cli` `traceroute` `nmap`
`nmap-ncat` `tcpdump` `whois` `bind-utils` `socat` `ethtool` `iproute-tc`
`iw` `wavemon` `openconnect` `NetworkManager-openconnect` `openfortivpn`
`openvpn` `NetworkManager-openvpn` `wireguard-tools` `net-tools`
`openssh-server` `remmina` `sshuttle` `tigervnc` `plasma-nm`

**Databases:**
`postgresql` `mariadb` `mongocli` `mongodb-atlas-cli`

**DevOps / containers:**
`task` `ansible` `terraform` `packer` `tofu` `docker-ce` `docker-ce-cli`
`containerd.io` `docker-buildx-plugin` `docker-compose-plugin` `k9s`
`age` `yq` `jq` `awscli2` `jsonnet` `podman` `skopeo` `toolbox`

**Languages / build:**
`nodejs` `python3` `golang` `golangci-lint` `protobuf-compiler`
`golang-google-protobuf` `golang-google-grpc` `graphviz`
`java-21-openjdk-devel` `java-25-openjdk-devel` `minicom` `esptool`

**Editors / AI tools:**
`code` `codium` `cursor` `antigravity` `devin-desktop` `warp-terminal`

</details>

---

## 🧩 VSCode Extensions (27 plugins)

Backed up as `.vsix` files from the Microsoft Marketplace for offline installation
across VSCode, VSCodium, Cursor, Windsurf, and other compatible forks.

<details>
<summary>Extension list (click to expand)</summary>

| Extension ID | Purpose |
|---|---|
| `ms-python.python` | Python language support |
| `golang.Go` | Go language support |
| `redhat.java` | Java language support |
| `mathiasfrohlich.kotlin` | Kotlin language support |
| `rust-lang.rust-analyzer` | Rust language server |
| `ms-vscode.cpptools` | C/C++ IntelliSense & debugging |
| `dbaeumer.vscode-eslint` | JavaScript/TypeScript linter |
| `esbenp.prettier-vscode` | Code formatter |
| `redhat.vscode-yaml` | YAML support |
| `ms-azuretools.vscode-docker` | Docker integration |
| `ms-kubernetes-tools.vscode-kubernetes-tools` | Kubernetes support |
| `hashicorp.terraform` | Terraform / HCL |
| `redhat.ansible` | Ansible playbook support |
| `ms-vscode-remote.remote-containers` | Dev Containers |
| `eamodio.gitlens` | Advanced Git integration |
| `gitlab.gitlab-workflow` | GitLab CI/CD integration |
| `mtxr.sqltools` | SQL client |
| `davidanson.vscode-markdownlint` | Markdown linting |
| `domdomegg.markdown-inline-preview-vscode` | Inline Markdown preview |
| `tomoki1207.pdf` | PDF viewer |
| `Codeium.codeium` | AI code completion |
| `github.copilot-chat` | GitHub Copilot Chat |
| `usernamehw.errorlens` | Inline error highlighting |
| `Gruntfuggly.todo-tree` | TODO/FIXME tree view |
| `alefragnani.Bookmarks` | Code bookmarks |
| `humao.rest-client` | HTTP client |
| `oderwat.indent-rainbow` | Indentation visualization |

</details>

---

## 🔄 Runtime Policy

| Runtime | Policy |
|---|---|
| **Python** | System `python3` via Fedora repos; standalone installer for Windows/macOS |
| **Java** | OpenJDK 21 + 25 from Fedora repos; Temurin 8 + 21 as standalone for cross-platform |
| **Node.js** | Latest LTS from nodejs.org |
| **Go** | Current stable upstream toolchain |
| **Rust** | `rustup-init` bootstrap binary |

---

## 🖥️ Platform Notes

- **Linux**: Kernel/desktop-specific tools (`iproute-tc`, `ethtool`, KVM/libvirt, NetworkManager plugins) are in the Fedora repo backup, not standalone installers.
- **macOS**: `backup.sh` works for app installers and ISOs. Fedora RPM mirroring is skipped automatically if `dnf` is not found.
- **Windows**: `backup.ps1` handles MSI/EXE downloads. Linux equivalents map to Windows tools: `strace` → Sysinternals Process Monitor, `mtr` → WinMTR, `traceroute` → `tracert`.

---

## 📋 Requirements

- **Linux**: `bash`, `curl`, `dnf` (for Fedora repo mirror), `gh` (GitHub CLI, for `gh:` sources)
- **macOS**: `bash`, `curl`, `gh`
- **Windows**: PowerShell 5.1+

---

## 📄 License

MIT
