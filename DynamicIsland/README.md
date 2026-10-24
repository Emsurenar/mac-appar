# Dynamic Island för Mac

En Dynamic Island som växer ur notchen på MacBook – byggd i SwiftUI med Apples egna fjäderanimationer.

- **Nu spelas** från alla appar (Musik, Spotify, Safari, Chrome, Podcasts …): omslag, titel, artist, spola, spela/pausa, nästa/föregående.
- **Live-aktivitet**: omslag och equalizer i omslagets färg på var sida om notchen medan musik spelas, och en kort titt vid låtbyte.
- **Ljud**: volym, ljud av, och val av ljudutgång (AirPods, högtalare, AirPlay …) direkt i ön, samt ljusstyrka.
- **Hem**: brickor som i Hem-appen för scener och tillbehör, via dina Genvägar (se nedan).
- **HUD**: volym, ljusstyrka och byte av ljudutgång visas i ön. Kan ersätta systemets volymruta (kräver Hjälpmedel).

## Bygga och köra

```bash
./build.sh --run
```

Appen hamnar i `build/Dynamic Island.app`. Den har ingen Dock-ikon – högerklicka på ön eller använd kugghjulet för inställningar och för att avsluta.

## Hem

HomeKit går inte att använda från vanliga Mac-appar (bara Catalyst-appar med ett betalt utvecklarkonto), så ön kör dina genvägar i stället:

1. Öppna **Genvägar** och skapa en mapp som heter **Hem** (namnet går att ändra i inställningarna).
2. Lägg till genvägar med åtgärden **Styr hem** – till exempel "Tänd vardagsrummet" eller en scen som "God natt".
3. De dyker upp som brickor i ön. Börjar namnet med en emoji blir den ikonen, annars väljs en symbol från namnet (lampa, lås, värme, fläkt …).
4. Vill du att brickan visar läge: låt genvägen sluta med att returnera texten `på` eller `av`.

## Så funkar "Nu spelas"

Sedan macOS 15.4 svarar MediaRemote bara Apple-signerade processer. `Bridge/NowPlayingBridge.m` laddas därför in i `/usr/bin/perl` och pratar med appen via stdin/stdout (JSON-rader ut, kommandon in).

## Felsökning

`CONFIG=debug ./build.sh` bygger en debug-version som kan rendera alla lägen till bilder:

```bash
"build/Dynamic Island.app/Contents/MacOS/DynamicIsland" --snapshots /tmp/island
```

`--trace` skriver ut varje tillståndsbyte.
