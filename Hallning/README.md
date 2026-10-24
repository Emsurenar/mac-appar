# Hållning

En menyradsapp för Mac som håller koll på hur du sitter – med kameran, Apples Vision och (om du vill) huvudvinkeln från dina AirPods. Den lär sig just din kropp och säger till när du suttit illa en stund, med ett konkret råd som *Dra bak axlarna*, *Sträck på dig* eller *Dra bakhuvudet bakåt*.

- **Var 10:e sekund** tar appen en kort bildserie (kameran är på ungefär en sekund) och läser av axlar, huvud och ansikte med Vision.
- **Kalibrering**: du visar 10 bra och 10 dåliga hållningar. Varje dålig hållning hör ihop med ett eget råd.
- **3-minutersregeln**: när minst 90 % av kontrollerna under 3 minuter visar dålig hållning kommer en påminnelse. Båda värdena går att ändra.
- **AirPods**: AirPods Pro, Max och 3:e generationen och senare ger nackens vinkel som extra signal. Utan dem används bara kameran.
- **Dynamic Island**: med [Dynamic Island](../DynamicIsland) igång visas påminnelser och status i ön, annars som notis.
- **Översikt** med dagens kurva, de senaste 7 dagarna och dagens vanligaste problem.

## Bygga och köra

Kräver macOS 26 och Command Line Tools (Xcode behövs inte).

```bash
cd Hallning
./build.sh --run
```

Appen hamnar i `build/Hållning.app`. Första gången ritas ikonen (`Resources/AppIcon.icns`) med `Scripts/make-icon.swift`. Skriptet signerar med den första kodsigneringsidentiteten i nyckelringen (t.ex. *Dagsplan Development*) så att kamerabehörigheten finns kvar mellan byggen. Välj en annan med `SIGN_IDENTITY="…" ./build.sh`.

Appen har ingen Dock-ikon: den bor i menyraden som en sittande figur. Första gången öppnas kalibreringen automatiskt.

## Behörigheter

| Behörighet | Varför | |
|---|---|---|
| Kamera | Läsa av hållningen | Krävs |
| Notiser | Påminnelser när Dynamic Island inte är igång | Valfri |
| Rörelse (AirPods) | Nackens vinkel | Valfri |

Går något fel: **Systeminställningar → Integritet och säkerhet → Kamera** (eller **Rörelse och kondition**) och slå på Hållning.

## Så funkar det

1. Vision hittar ledpunkter (öron, ögon, näsa, axlar …) och ansiktets ruta och vinklar.
2. Av dem räknas ett tiotal mått fram, t.ex. hur högt huvudet sitter över axlarna i förhållande till axelbredden, hur stort ansiktet är (huvudet fram), axlarnas lutning och hur mycket näsan sjunkit. AirPods bidrar med riktningen på tyngdkraften i huvudet.
3. Måtten jämförs med dina egna kalibrerade hållningar (viktad närmaste-granne, normaliserad mot dina bra hållningar). Liknar ställningen ingenting du kalibrerat räknas den som *osäker* och påverkar inga påminnelser.
4. Stämmer det inte? Tryck *Det här är bra* eller *Dålig hållning* i menyn, eller *Fel – jag satt bra* i notisen. Kontrollen läggs då till i kalibreringen.

Kontrollerna pausar automatiskt när skärmen är låst eller vilar och (om du vill) under videosamtal, när kameran används av en annan app.

## Dynamic Island

Apparna pratar via distribuerade notiser:

- `com.emresunar.Hallning.state` – status vid varje kontroll, vid start och vid avslut.
- `com.emresunar.Hallning.alert` – en påminnelse.
- `com.emresunar.Hallning.command` – knapparna i öns flik: `pause30`, `resume`, `check`, `open`.
- `com.emresunar.DynamicIsland.posture.hello` – ön är igång. Har ön hörts av de senaste 75 sekunderna visas påminnelsen bara där (standard), annars som notis. Det går att ändra under **Inställningar → Påminnelser**.

## Integritet

- Allt sker lokalt på din Mac. Inget skickas någonstans.
- **Bilder sparas aldrig.** Varje bild analyseras i minnet och släpps direkt. Bara ledpunkternas koordinater sparas, för kalibreringen och miniatyrerna.
- Data ligger i `~/Library/Application Support/Hallning/`: `calibration.json` och en fil per dag i `History/` (antal bra och dåliga kontroller per minut, sparas i 30 dagar).
- **Inställningar → Integritet → Radera all data** tar bort allt.
