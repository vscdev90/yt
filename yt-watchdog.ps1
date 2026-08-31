param(
    [Parameter(Mandatory=$true)]
    [int]$ParentPid,

    [Parameter(Mandatory=$true)]
    [string]$PidFile
)

# ============================================================
# yt-music CMD WATCHDOG
# ============================================================

while ($true) {

    Start-Sleep -Milliseconds 1000

    $parent = Get-Process `
        -Id $ParentPid `
        -ErrorAction SilentlyContinue

    # CMD bestaat nog
    if ($parent) {
        continue
    }

    # CMD is verdwenen -> MPV stoppen

    if (Test-Path $PidFile) {

        try {

            $mpvPid = [int](
                Get-Content $PidFile -Raw
            ).Trim()

            if ($mpvPid -gt 0) {

                $mpv = Get-Process `
                    -Id $mpvPid `
                    -ErrorAction SilentlyContinue

                if ($mpv) {

                    Stop-Process `
                        -Id $mpvPid `
                        -Force `
                        -ErrorAction SilentlyContinue
                }
            }
        }
        catch {}
    }

    Remove-Item `
        $PidFile `
        -Force `
        -ErrorAction SilentlyContinue

    break
}