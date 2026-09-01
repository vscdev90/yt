# ============================================================
# yt-music setup
# ============================================================
# Maakt yt-music klaar voor gebruik op deze computer:
#   1. Pakt mpv uit (mpv.7z -> mpv/)
#   2. Controleert/installeert yt-dlp via winget
#   3. Voegt deze map toe aan de PATH van de gebruiker
#
# Uitvoeren:  powershell -ExecutionPolicy Bypass -File setup.ps1
# ============================================================

$BaseDir = $PSScriptRoot

Write-Host ""
Write-Host "yt-music setup" -ForegroundColor Cyan
Write-Host "Map: $BaseDir" -ForegroundColor DarkGray
Write-Host ""

# ------------------------------------------------------------
# 1. MPV uitpakken
# ------------------------------------------------------------

$MpvExe = Join-Path $BaseDir "mpv\mpv.exe"
$MpvArchive = Join-Path $BaseDir "mpv.7z"

if (Test-Path $MpvExe) {

    Write-Host "[ok] mpv.exe is al aanwezig." -ForegroundColor Green
}
else {

    Write-Host "[..] mpv.exe ontbreekt, wordt uitgepakt uit mpv.7z..." -ForegroundColor Yellow

    if (!(Test-Path $MpvArchive)) {

        Write-Host "[fout] mpv.7z niet gevonden in $BaseDir" -ForegroundColor Red
        Write-Host "       Kloon de repository opnieuw, mpv.7z hoort erbij te staan." -ForegroundColor Red
        exit 1
    }

    # 7z.exe opzoeken (PATH, of standaard 7-Zip installatiemap)
    $SevenZip = $null

    $cmd = Get-Command 7z -ErrorAction SilentlyContinue

    if ($cmd) {
        $SevenZip = $cmd.Source
    }
    else {

        $candidates = @(
            "$env:ProgramFiles\7-Zip\7z.exe"
            "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
        )

        foreach ($candidate in $candidates) {

            if (Test-Path $candidate) {
                $SevenZip = $candidate
                break
            }
        }
    }

    if (!$SevenZip) {

        Write-Host "[..] 7-Zip niet gevonden, wordt geinstalleerd via winget..." -ForegroundColor Yellow

        winget install --id 7zip.7zip -e --source winget --accept-package-agreements --accept-source-agreements

        $candidates = @(
            "$env:ProgramFiles\7-Zip\7z.exe"
            "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
        )

        foreach ($candidate in $candidates) {

            if (Test-Path $candidate) {
                $SevenZip = $candidate
                break
            }
        }
    }

    if (!$SevenZip) {

        Write-Host "[fout] 7-Zip kon niet gevonden/geinstalleerd worden." -ForegroundColor Red
        Write-Host "       Installeer 7-Zip handmatig en voer setup.ps1 opnieuw uit." -ForegroundColor Red
        exit 1
    }

    & $SevenZip x $MpvArchive "-o$BaseDir\mpv" -y | Out-Null

    if (!(Test-Path $MpvExe)) {

        Write-Host "[fout] Uitpakken van mpv.7z is mislukt." -ForegroundColor Red
        exit 1
    }

    Write-Host "[ok] mpv.exe uitgepakt." -ForegroundColor Green
}

# ------------------------------------------------------------
# 2. yt-dlp controleren
# ------------------------------------------------------------

$ytdlp = Get-Command yt-dlp -ErrorAction SilentlyContinue

if ($ytdlp) {

    Write-Host "[ok] yt-dlp gevonden: $($ytdlp.Source)" -ForegroundColor Green
}
else {

    Write-Host "[..] yt-dlp niet gevonden, wordt geinstalleerd via winget..." -ForegroundColor Yellow

    winget install --id yt-dlp.yt-dlp -e --source winget --accept-package-agreements --accept-source-agreements

    $ytdlp = Get-Command yt-dlp -ErrorAction SilentlyContinue

    if ($ytdlp) {
        Write-Host "[ok] yt-dlp geinstalleerd." -ForegroundColor Green
    }
    else {
        Write-Host "[waarschuwing] yt-dlp kon niet automatisch gevonden worden." -ForegroundColor Yellow
        Write-Host "               Open een nieuwe terminal en voer setup.ps1 opnieuw uit," -ForegroundColor Yellow
        Write-Host "               of installeer handmatig met: winget install yt-dlp.yt-dlp" -ForegroundColor Yellow
    }
}

# ------------------------------------------------------------
# 3. Deze map toevoegen aan de PATH (gebruiker)
# ------------------------------------------------------------

$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")

$pathEntries = @()

if ($currentPath) {
    $pathEntries = $currentPath -split ";" | Where-Object { $_ -ne "" }
}

$alreadyInPath = $pathEntries | Where-Object {
    $_.TrimEnd('\') -ieq $BaseDir.TrimEnd('\')
}

if ($alreadyInPath) {

    Write-Host "[ok] $BaseDir staat al in de PATH." -ForegroundColor Green
}
else {

    $newPath = if ($currentPath) { "$currentPath;$BaseDir" } else { $BaseDir }

    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")

    Write-Host "[ok] $BaseDir toegevoegd aan de PATH." -ForegroundColor Green
    Write-Host "     Open een NIEUWE terminal om dit effect te laten hebben." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Setup klaar. Open een nieuwe terminal en test met: yt daft punk" -ForegroundColor Cyan
Write-Host ""
