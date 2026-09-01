# yt-music

Muziek van YouTube afspelen vanuit de terminal, zonder video. Zoek een nummer, kies uit de resultaten en bedien het afspelen (pauze, volgende, loop, verbergen) met het `yt` commando.

## Vereisten

- Windows met PowerShell
- [7-Zip](https://www.7-zip.org/) (om `mpv.7z` uit te pakken) — `setup.ps1` installeert dit automatisch via winget als het ontbreekt
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) — `setup.ps1` installeert dit automatisch via winget als het ontbreekt
- `mpv.exe` wordt **niet** meegeleverd in git (staat in `.gitignore`, is te groot). In plaats daarvan staat een gecomprimeerde `mpv.7z` in de repo, die `setup.ps1` uitpakt naar `mpv/`.

## Installatie op een nieuwe computer

1. Clone deze repository naar een map naar keuze, bijvoorbeeld:
   ```
   git clone <repo-url> C:\yt-music
   ```
2. Open PowerShell in die map en voer de setup uit:
   ```
   powershell -ExecutionPolicy Bypass -File setup.ps1
   ```
   Dit script doet drie dingen:
   - Pakt `mpv.exe` uit `mpv.7z` uit naar `mpv/` (installeert 7-Zip via winget indien nodig)
   - Controleert of `yt-dlp` aanwezig is, en installeert het anders via winget
   - Voegt de repo-map toe aan de PATH van je gebruikersaccount, zodat het `yt` commando overal werkt
3. Open een **nieuwe** terminal (nodig zodat de PATH-wijziging actief wordt) en test:
   ```
   yt daft punk
   ```

Je hoeft dit niet per se naar `C:\yt-music` te clonen — alle scripts gebruiken hun eigen locatie (`$PSScriptRoot` / `%~dp0`), dus elke map werkt.

## Gebruik

```
yt <zoekterm>       Zoek op YouTube en kies een resultaat om af te spelen
yt next             Volgend resultaat uit de laatste zoekopdracht
yt previous         Vorig resultaat uit de laatste zoekopdracht
yt pause            Pauzeer / hervat het afspelen
yt stop             Stop mpv
yt loop             Zet loop van het huidige nummer aan/uit
yt hide             Verberg het terminalvenster (Ctrl+H om weer te tonen)
```

Bij `yt <zoekterm>` krijg je een gepagineerde lijst met zoekresultaten (10 per pagina). Kies een nummer, of navigeer met `N` (volgende pagina), `P` (vorige pagina), `Q` (annuleren).

## Hoe het werkt

- `yt.cmd` is de ingang van het `yt` commando en roept `yt.ps1` aan (moet in dezelfde map staan).
- `yt.ps1` zoekt via `yt-dlp` op YouTube en speelt de gekozen video audio-only af via `mpv` (`--no-video`), aangestuurd via een named pipe (mpv's IPC).
- De status van de laatste zoekopdracht (resultaten + huidige index) wordt tijdelijk opgeslagen in `%TEMP%\yt-music-state.json`, zodat `next`/`previous` werken.
- `yt-watchdog.ps1` stopt mpv automatisch zodra het terminalvenster wordt gesloten.
- `yt-hide.ps1` verbergt/toont het terminalvenster via `yt hide` (Ctrl+H om terug te halen).

## Bestanden

| Bestand | Doel |
|---|---|
| `yt.cmd` | Ingang van het `yt` commando |
| `yt.ps1` | Hoofdlogica: zoeken, afspelen, bedienen |
| `yt-watchdog.ps1` | Stopt mpv als het terminalvenster sluit |
| `yt-hide.ps1` | Verberg/toon terminalvenster via hotkey |
| `setup.ps1` | Eenmalige installatie op een nieuwe computer |
| `mpv.7z` | Gecomprimeerde mpv-installatie (wordt uitgepakt naar `mpv/`) |
| `mpv/` | Uitgepakte mpv-installatie (`mpv.exe` zelf is gitignored) |

## Handmatige installatie (als `setup.ps1` niet gebruikt kan worden)

1. Pak `mpv.7z` uit naar de map `mpv/` (zodat `mpv\mpv.exe` bestaat), bijvoorbeeld met 7-Zip: rechtermuisklik → "Uitpakken naar mpv\".
2. Installeer yt-dlp: `winget install yt-dlp.yt-dlp`
3. Voeg de map met `yt.cmd` handmatig toe aan je PATH:
   - Windows-instellingen → "Omgevingsvariabelen bewerken" → onder "Gebruikersvariabelen" `Path` bewerken → nieuwe regel met het pad naar deze map.
4. Open een nieuwe terminal en test met `yt <zoekterm>`.
