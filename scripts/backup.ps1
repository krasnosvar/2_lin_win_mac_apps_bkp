<#
    backup.ps1 - Windows offline app downloader.

    Files are saved to:  backup\apps\<group>\<app>\<os>-<arch>\<vendor-filename>

    Usage:
      powershell -ExecutionPolicy Bypass -File .\scripts\backup.ps1
      powershell -ExecutionPolicy Bypass -File .\scripts\backup.ps1 -Os windows
      powershell -ExecutionPolicy Bypass -File .\scripts\backup.ps1 -Arch x64
      powershell -ExecutionPolicy Bypass -File .\scripts\backup.ps1 -InstallersOnly
      powershell -ExecutionPolicy Bypass -File .\scripts\backup.ps1 -List

    Env:
      $env:GITHUB_TOKEN   optional; raises the GitHub API rate limit for gh: sources.
#>
param(
    [string]$Os   = "windows",
    [string]$Arch = "",
    [switch]$InstallersOnly,
    [switch]$List
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepoDir  = Split-Path -Parent $PSScriptRoot
$Manifest = Join-Path $RepoDir "apps.tsv"
$OutDir   = Join-Path (Join-Path $RepoDir "backup") "apps"

Write-Host "OS=$Os  ARCH=$(if($Arch){$Arch}else{'all'})  TYPES=$(if($InstallersOnly){'installers'}else{'all'})  ->  $OutDir"

function Test-InstallerExt([string]$ext) {
    return $ext -in @("rpm", "deb", "dmg", "pkg", "msi", "exe")
}

function ConvertTo-SafeFileName([string]$name) {
    return (($name -replace '[\\/]', '_').Trim())
}

function Get-UrlPathFileName([string]$url) {
    $clean = ($url -split '#')[0]
    $clean = ($clean -split '\?')[0]
    $name = [IO.Path]::GetFileName($clean)
    if (-not $name) { return $null }
    return (ConvertTo-SafeFileName ([Uri]::UnescapeDataString($name)))
}

function Get-RemoteFileName([string]$url, [string]$fallback, [string]$ext) {
    $name = Get-UrlPathFileName $url
    if ($name -and (($ext -in @("bin", "run")) -or $name.EndsWith(".$ext"))) {
        return $name
    }

    try {
        $r = Invoke-WebRequest -Uri $url -Method Head -MaximumRedirection 10 -UseBasicParsing
        $cd = $r.Headers["Content-Disposition"]
        if ($cd) {
            if ($cd -match "filename\*=UTF-8''([^;]+)") {
                return (ConvertTo-SafeFileName ([Uri]::UnescapeDataString($Matches[1])))
            }
            if ($cd -match 'filename="?([^";]+)"?') {
                return (ConvertTo-SafeFileName $Matches[1])
            }
        }
        $finalName = Get-UrlPathFileName $r.BaseResponse.ResponseUri.AbsoluteUri
        if ($finalName -and (($ext -in @("bin", "run")) -or $finalName.EndsWith(".$ext"))) {
            return $finalName
        }
    } catch {}

    return $fallback
}

# Latest release tag of a GitHub repo via the web redirect (no API rate limit).
function Get-GhLatestTag([string]$repo) {
    $r = Invoke-WebRequest -Uri "https://github.com/$repo/releases/latest" `
            -MaximumRedirection 0 -ErrorAction SilentlyContinue -UseBasicParsing
    $loc = $r.Headers.Location
    if ($loc -match 'tag/(.+)$') { return $Matches[1] }
    return $null
}

# List href basenames (dirs keep trailing slash) from a directory index.
function Get-IndexNames([string]$url) {
    $html = (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
    [regex]::Matches($html, 'href="([^"]+)"') |
        ForEach-Object { $_.Groups[1].Value -replace '.*/(?=[^/])','' -replace '^.*/([^/]+/)$','$1' }
}

# Depth-first, newest-first directory descent with backtracking.
# $segs[0] = dir/file regexes... last element is the file regex.
function Resolve-Dir([string]$url, [string[]]$segs) {
    $seg   = $segs[0]
    $names = Get-IndexNames $url | Where-Object { $_ -match $seg } | Sort-Object -Descending
    if (-not $names) { return $null }
    if ($segs.Count -eq 1) { return ($url.TrimEnd('/') + "/" + ($names | Select-Object -First 1)) }
    foreach ($d in $names) {
        $r = Resolve-Dir ($url.TrimEnd('/') + "/" + ($d.TrimEnd('/')) + "/") $segs[1..($segs.Count-1)]
        if ($r) { return $r }
    }
    return $null
}

# Resolve a source spec to a concrete URL (returns $null if unresolved).
function Resolve-Url([string]$src) {
    if ($src -like "gh:*") {
        # gh:owner/repo:REGEX  -> newest release asset matching REGEX (web-scraped)
        $body  = $src.Substring(3)
        $repo  = $body.Split(":")[0]
        $regex = $body.Substring($repo.Length + 1)
        $tag   = Get-GhLatestTag $repo
        if (-not $tag) { return $null }
        $html  = (Invoke-WebRequest -Uri "https://github.com/$repo/releases/expanded_assets/$tag" -UseBasicParsing).Content
        $file  = [regex]::Matches($html, "/$repo/releases/download/[^""]+") |
                 ForEach-Object { $_.Value.Split("/")[-1] } |
                 Where-Object { $_ -match $regex } | Select-Object -First 1
        if ($file) { return "https://github.com/$repo/releases/download/$tag/$file" }
        return $null
    }
    elseif ($src -like "ghtag:*") {
        # ghtag:owner/repo:URL-TEMPLATE  ({tag}=v1.2.3, {ver}=1.2.3)
        $body = $src.Substring(6)
        $repo = $body.Split(":")[0]
        $tmpl = $body.Substring($repo.Length + 1)
        $tag  = Get-GhLatestTag $repo
        if (-not $tag) { return $null }
        $ver  = $tag -replace '^v',''
        return ($tmpl -replace '\{tag\}',$tag -replace '\{ver\}',$ver)
    }
    elseif ($src -like "dir:*") {
        # dir:BASE|SEG|...|FILEREGEX  -> depth-first, newest-first directory
        # descent WITH BACKTRACKING (skips pre-release folders with no binary).
        $segs = $src.Substring(4).Split("|")
        return (Resolve-Dir $segs[0] $segs[1..($segs.Count-1)])
    }
    elseif ($src -like "page:*") {
        # page:URL|REGEX -> first absolute link on a page whose URL matches REGEX
        $body  = $src.Substring(5)
        $base  = $body.Split("|")[0]
        $regex = $body.Substring($base.Length + 1)
        $html  = (Invoke-WebRequest -Uri $base -UseBasicParsing).Content
        $link  = [regex]::Matches($html, 'https?://[^"'' <>]+') |
                 ForEach-Object { $_.Value } | Where-Object { $_ -match $regex } | Select-Object -First 1
        return $link
    }
    elseif ($src -like "http*://*") { return $src }
    return $null
}

$ok = 0; $fail = 0
foreach ($line in Get-Content $Manifest) {
    if ($line.Trim() -eq "" -or $line.TrimStart().StartsWith("#")) { continue }
    $c = $line -split "`t"
    if ($c.Count -lt 6) { continue }
    $group, $app, $mOs, $mArch, $ext, $source = $c[0], $c[1], $c[2], $c[3], $c[4], $c[5]

    if ($mOs -ne $Os) { continue }
    if ($Arch -and $mArch -ne $Arch) { continue }
    if ($InstallersOnly -and -not (Test-InstallerExt $ext)) { continue }

    try { $url = Resolve-Url $source } catch { $url = $null }
    if (-not $url) {
        Write-Host "  ! SKIP  $group/$app $mOs-$mArch (could not resolve: $source)"
        $fail++; continue
    }

    $destName = Get-RemoteFileName $url "$mOs-$mArch.$ext" $ext
    $destDir = Join-Path (Join-Path (Join-Path $OutDir $group) $app) "$mOs-$mArch"
    $dest    = Join-Path $destDir $destName

    if ($List) { Write-Host "  . $group/$app $mOs-$mArch/$destName  <-  $url"; continue }

    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    Write-Host "  > $group/$app $mOs-$mArch/$destName"
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
        # write <file>.sha256 alongside so integrity can be checked offline later
        $hash = (Get-FileHash -Path $dest -Algorithm SHA256).Hash.ToLower()
        "$hash  $(Split-Path $dest -Leaf)" | Set-Content -NoNewline -Path "$dest.sha256"
        $ok++
    } catch {
        Write-Host "    !! download failed: $url" -ForegroundColor Red
        $fail++
    }
}

Write-Host "done: $ok downloaded, $fail failed/unresolved"
