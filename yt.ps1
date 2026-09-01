# ============================================================
# yt-music
# ============================================================

$BaseDir = $PSScriptRoot

$MpV = Join-Path $BaseDir "mpv\mpv.exe"

$YtDlpCommand = Get-Command yt-dlp -ErrorAction SilentlyContinue

if ($YtDlpCommand) {
    $YtDlp = $YtDlpCommand.Source
}
else {
    $YtDlp = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links\yt-dlp.exe"
}

$StateFile = "$env:TEMP\yt-music-state.json"
$PidFile   = "$env:TEMP\yt-music-mpv.pid"
$CmdPidFile = "$env:TEMP\yt-music-cmd.pid"

$PipeName = "yt-mpv"

# ============================================================
# CONTROLE
# ============================================================

if (!(Test-Path $MpV)) {
    Write-Host "MPV niet gevonden:" -ForegroundColor Red
    Write-Host $MpV
    Write-Host "Voer setup.ps1 uit om mpv uit te pakken." -ForegroundColor Yellow
    exit 1
}

if (!(Test-Path $YtDlp)) {
    Write-Host "yt-dlp niet gevonden:" -ForegroundColor Red
    Write-Host $YtDlp
    Write-Host "Voer setup.ps1 uit om yt-dlp te installeren." -ForegroundColor Yellow
    exit 1
}

# ============================================================
# MPV
# ============================================================

function Get-Mpv {

    if (!(Test-Path $PidFile)) {
        return $null
    }

    try {

        $id = [int](Get-Content $PidFile -Raw).Trim()

        if ($id -le 0) {
            return $null
        }

        return Get-Process -Id $id -ErrorAction SilentlyContinue
    }
    catch {

        return $null
    }
}

function Stop-Mpv {

    $p = Get-Mpv

    if ($p) {

        Write-Host "MPV stoppen..." -ForegroundColor DarkGray

        Stop-Process `
            -Id $p.Id `
            -Force `
            -ErrorAction SilentlyContinue

        Start-Sleep -Milliseconds 300
    }

    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
}

function Start-Music($Url) {

    Stop-Mpv

    Start-Sleep -Milliseconds 500

    Write-Host ""
    Write-Host "MPV starten..." -ForegroundColor DarkGray

    $arguments = @(
        "--no-video"
        "--force-window=no"
        "--really-quiet"

        "--input-ipc-server=\\.\pipe\$PipeName"

        # Gebruik expliciet jouw yt-dlp
        "--script-opts=ytdl_hook-ytdl_path=$YtDlp"

        "--ytdl-format=bestaudio/best"

        "--"
        $Url
    )

    try {

        $p = Start-Process `
            -FilePath $MpV `
            -ArgumentList $arguments `
            -WorkingDirectory $BaseDir `
            -WindowStyle Hidden `
            -PassThru

        $p.Id | Set-Content $PidFile

        # Geef MPV tijd om de IPC pipe te maken
        $ready = $false

        for ($i = 0; $i -lt 20; $i++) {

            Start-Sleep -Milliseconds 250

            if ($p.HasExited) {
                break
            }

            try {

                $testPipe = New-Object System.IO.Pipes.NamedPipeClientStream(
                    ".",
                    $PipeName,
                    [System.IO.Pipes.PipeDirection]::Out
                )

                $testPipe.Connect(100)

                $testPipe.Dispose()

                $ready = $true
                break
            }
            catch {
                # Pipe nog niet klaar
            }
        }

        if ($p.HasExited) {

            Remove-Item $PidFile -Force -ErrorAction SilentlyContinue

            return $false
        }

        if (!$ready) {

            Write-Host "MPV IPC pipe kon niet worden geopend." -ForegroundColor Red

            Stop-Mpv

            return $false
        }

        return $true
    }
    catch {

        Write-Host ""
        Write-Host "MPV kon niet worden gestart." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor DarkRed

        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue

        return $false
    }
}

# ============================================================
# MPV IPC
# ============================================================

function Send-Mpv($Command) {

    $mpv = Get-Mpv

    if (!$mpv) {
        return $false
    }

    try {

        $pipe = New-Object System.IO.Pipes.NamedPipeClientStream(
            ".",
            $PipeName,
            [System.IO.Pipes.PipeDirection]::Out
        )

        $pipe.Connect(1500)

        $writer = New-Object System.IO.StreamWriter($pipe)

        $writer.AutoFlush = $true

        $message = @{
            command = @($Command)
        }

        $json = $message | ConvertTo-Json -Compress

        $writer.WriteLine($json)

        $writer.Dispose()
        $pipe.Dispose()

        return $true
    }
    catch {

        return $false
    }
}

# ============================================================
# STATE
# ============================================================

function Save-State($State) {

    try {

        $State |
            ConvertTo-Json -Depth 20 |
            Set-Content $StateFile -Encoding UTF8

        return $true
    }
    catch {

        return $false
    }
}

function Load-State {

    if (!(Test-Path $StateFile)) {
        return $null
    }

    try {

        return Get-Content $StateFile -Raw |
            ConvertFrom-Json
    }
    catch {

        return $null
    }
}

# ============================================================
# CMD PID
# ============================================================

function Get-ParentCmdPid {

    try {

        $process = Get-CimInstance Win32_Process -Filter "ProcessId=$PID"

        if (!$process) {
            return $null
        }

        $parentPid = [int]$process.ParentProcessId

        if ($parentPid -le 0) {
            return $null
        }

        $parent = Get-Process -Id $parentPid -ErrorAction SilentlyContinue

        if (!$parent) {
            return $null
        }

        if ($parent.ProcessName -ieq "cmd") {
            return $parentPid
        }

        # Bijvoorbeeld PowerShell -> cmd
        $currentPid = $parentPid

        for ($i = 0; $i -lt 5; $i++) {

            $p = Get-CimInstance `
                Win32_Process `
                -Filter "ProcessId=$currentPid" `
                -ErrorAction SilentlyContinue

            if (!$p) {
                break
            }

            $currentPid = [int]$p.ParentProcessId

            if ($currentPid -le 0) {
                break
            }

            $candidate = Get-Process `
                -Id $currentPid `
                -ErrorAction SilentlyContinue

            if ($candidate -and $candidate.ProcessName -ieq "cmd") {
                return $currentPid
            }
        }
    }
    catch {}

    return $null
}

# ============================================================
# CMD WATCHDOG STARTEN
# ============================================================

function Start-CmdWatchdog {

    $cmdPid = Get-ParentCmdPid

    if (!$cmdPid) {
        return
    }

    # PID opslaan
    $cmdPid | Set-Content $CmdPidFile

    $watchdog = Join-Path $BaseDir "yt-watchdog.ps1"

    if (!(Test-Path $watchdog)) {
        return
    }

    # Alleen starten als er nog geen watchdog draait
    $existing = Get-Process powershell,pwsh -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Id -ne $PID
        }

    # De watchdog zelf wordt herkenbaar via de commandline.
    $watchdogRunning = $false

    foreach ($proc in $existing) {

        try {

            $info = Get-CimInstance `
                Win32_Process `
                -Filter "ProcessId=$($proc.Id)" `
                -ErrorAction SilentlyContinue

            if ($info.CommandLine -and
                $info.CommandLine -like "*yt-watchdog.ps1*") {

                $watchdogRunning = $true
                break
            }
        }
        catch {}
    }

    if ($watchdogRunning) {
        return
    }

    Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList @(
            "-NoProfile"
            "-ExecutionPolicy"
            "Bypass"
            "-WindowStyle"
            "Hidden"
            "-File"
            $watchdog
            "-ParentPid"
            $cmdPid
            "-PidFile"
            $PidFile
        ) `
        -WindowStyle Hidden `
        -WorkingDirectory $BaseDir | Out-Null
}

# ============================================================
# PLAY RESULT
# ============================================================

function Play-Result($Result, $Index) {

    Write-Host ""
    Write-Host "Gekozen:" -ForegroundColor DarkGray
    Write-Host $Result.title -ForegroundColor Green
    Write-Host ""
    Write-Host "Afspelen..." -ForegroundColor Cyan

    $Url = "https://www.youtube.com/watch?v=$($Result.id)"

    if (Start-Music $Url) {

        $state = Load-State

        if ($state) {

            $state.currentIndex = $Index

            Save-State $state
        }

        return $true
    }

    Write-Host ""
    Write-Host "MPV kon de YouTube-stream niet starten." -ForegroundColor Red
    Write-Host ""

    return $false
}

# ============================================================
# GEEN COMMANDO
# ============================================================

if ($args.Count -eq 0) {

    Write-Host ""
    Write-Host "Gebruik:" -ForegroundColor Cyan
    Write-Host "  yt <zoekterm>"
    Write-Host "  yt next"
    Write-Host "  yt previous"
    Write-Host "  yt pause"
    Write-Host "  yt stop"
    Write-Host "  yt loop"
    Write-Host "  yt hide"
    Write-Host ""

    exit
}

$command = $args[0].ToLower()

# ============================================================
# HIDE
# ============================================================

if ($command -eq "hide") {

    $cmdPid = Get-ParentCmdPid

    if (!$cmdPid) {
        Write-Host "CMD-venster kon niet worden gevonden." -ForegroundColor Red
        exit 1
    }

    $hideScript = Join-Path $BaseDir "yt-hide.ps1"

    if (!(Test-Path $hideScript)) {
        Write-Host "yt-hide.ps1 niet gevonden." -ForegroundColor Red
        exit 1
    }

    $cmdPid | Set-Content $CmdPidFile

    Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList @(
            "-NoProfile"
            "-NonInteractive"
            "-ExecutionPolicy"
            "Bypass"
            "-WindowStyle"
            "Hidden"
            "-File"
            $hideScript
            "-CmdPid"
            $cmdPid
        ) `
        -WindowStyle Hidden `
        -WorkingDirectory $BaseDir | Out-Null

    exit
}

# ============================================================
# WATCHDOG
# ============================================================

Start-CmdWatchdog

# ============================================================
# STOP
# ============================================================

if ($command -eq "stop") {

    Stop-Mpv

    Write-Host "Muziek gestopt." -ForegroundColor Yellow

    exit
}

# ============================================================
# PAUSE
# ============================================================

if ($command -eq "pause") {

    if (Send-Mpv @("cycle", "pause")) {

        Write-Host "Pauze/hervat." -ForegroundColor Cyan
    }
    else {

        Write-Host "Er draait geen muziek." -ForegroundColor Yellow
    }

    exit
}

# ============================================================
# LOOP
# ============================================================

if ($command -eq "loop") {

    if (Send-Mpv @("cycle", "loop-file")) {

        Write-Host "Loop aan/uit." -ForegroundColor Cyan
    }
    else {

        Write-Host "Er draait geen muziek." -ForegroundColor Yellow
    }

    exit
}

# ============================================================
# NEXT / PREVIOUS
# ============================================================

if ($command -eq "next" -or $command -eq "previous") {

    $state = Load-State

    if (!$state) {

        Write-Host "Geen zoeklijst beschikbaar." -ForegroundColor Yellow
        Write-Host "Gebruik eerst: yt daft punk"

        exit
    }

    $results = @($state.results)

    if ($results.Count -eq 0) {

        Write-Host "Geen resultaten beschikbaar." -ForegroundColor Yellow

        exit
    }

    $current = [int]$state.currentIndex

    if ($current -lt 0) {
        $current = 0
    }

    if ($command -eq "next") {

        $newIndex = $current + 1

        if ($newIndex -ge $results.Count) {
            $newIndex = 0
        }
    }
    else {

        $newIndex = $current - 1

        if ($newIndex -lt 0) {
            $newIndex = $results.Count - 1
        }
    }

    $selected = $results[$newIndex]

    Play-Result $selected $newIndex

    exit
}

# ============================================================
# SEARCH
# ============================================================

$query = $args -join " "

Write-Host ""
Write-Host "Zoeken naar: $query" -ForegroundColor Cyan
Write-Host ""

$json = & $YtDlp `
    "ytsearch100:$query" `
    "--flat-playlist" `
    "--dump-single-json" `
    "--no-warnings" `
    "--skip-download" `
    2>$null

if (!$json) {

    Write-Host "Geen resultaten gevonden." -ForegroundColor Red

    exit
}

try {

    $data = $json | ConvertFrom-Json
}
catch {

    Write-Host "YouTube-resultaten konden niet worden gelezen." -ForegroundColor Red

    exit
}

$results = @($data.entries)

if ($results.Count -eq 0) {

    Write-Host "Geen resultaten gevonden." -ForegroundColor Red

    exit
}

# ============================================================
# STATE OPSLAAN
# ============================================================

$state = [PSCustomObject]@{
    query = $query
    results = $results
    currentIndex = -1
}

Save-State $state

# ============================================================
# PAGINERING
# ============================================================

$page = 0
$pageSize = 10

while ($true) {

    $start = $page * $pageSize

    $items = @(
        $results |
        Select-Object -Skip $start -First $pageSize
    )

    Clear-Host

    $totalPages = [math]::Ceiling(
        $results.Count / $pageSize
    )

    Write-Host ""
    Write-Host "YouTube resultaten voor: $query" -ForegroundColor Cyan
    Write-Host "Pagina $($page + 1) / $totalPages" -ForegroundColor DarkGray
    Write-Host ""

    for ($i = 0; $i -lt $items.Count; $i++) {

        $number = $i + 1

        $title = [string]$items[$i].title

        if ($title.Length -gt 90) {

            $title = $title.Substring(0,87) + "..."
        }

        Write-Host (
            "{0,2}. {1}" -f $number, $title
        )
    }

    Write-Host ""
    Write-Host "N = volgende pagina | P = vorige pagina | Q = annuleren"
    Write-Host ""

    $choice = Read-Host "Kies"

    # ========================================================
    # NUMMER
    # ========================================================

    if ($choice -match '^[0-9]+$') {

        $number = [int]$choice

        if ($number -ge 1 -and
            $number -le $items.Count) {

            $globalIndex = $start + $number - 1

            $selected = $results[$globalIndex]

            $state.currentIndex = $globalIndex

            Save-State $state

            Play-Result $selected $globalIndex

            break
        }

        Write-Host "Ongeldig nummer." -ForegroundColor Red

        Start-Sleep -Seconds 1

        continue
    }

    # ========================================================
    # VOLGENDE PAGINA
    # ========================================================

    if ($choice.ToLower() -eq "n") {

        if (($start + $pageSize) -lt $results.Count) {

            $page++
        }
        else {

            Write-Host "Dit is de laatste pagina." -ForegroundColor Yellow

            Start-Sleep -Seconds 1
        }

        continue
    }

    # ========================================================
    # VORIGE PAGINA
    # ========================================================

    if ($choice.ToLower() -eq "p") {

        if ($page -gt 0) {

            $page--
        }
        else {

            Write-Host "Dit is de eerste pagina." -ForegroundColor Yellow

            Start-Sleep -Seconds 1
        }

        continue
    }

    # ========================================================
    # ANNULEREN
    # ========================================================

    if ($choice.ToLower() -eq "q") {

        break
    }
}