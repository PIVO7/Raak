# Raak!

Een zeeslagspel voor kinderen, in dezelfde speelgoedstijl als
[Dobbel](https://github.com/PIVO7/Yathzee),
[Vier op een rij](https://github.com/PIVO7/VierOpEenRij) en Memo.

Hussel je vloot, leg hem geheim klaar en schiet om de beurt op de zee
van de ander. Raak? Dan mag je meteen nog een keer! Speel met z'n
tweeën aan één toestel (met een overgavescherm zodat niemand kan
spieken) of solo tegen Dommel, Robbie of Professor Punt — drie
tegenstanders die eerlijk mikken: ze kennen jouw vloot niet en jagen
zoals een mens dat doet, van gok tot dambordpatroon.

- SwiftUI, Swift 6, iOS 17+
- Drie zeeën (6×6, 8×8 of 10×10) met een groeiende vloot
- Profielen met statistieken, winreeks en meeste treffers
- Eén gezinsdeelbare aankoop (Gezinsversie) ontgrendelt alle
  tegenstanders, kleurenthema's en statistieken, achter een ouder-poort
- Toegankelijk: VoiceOver, Verminder beweging en Onderscheid zonder kleur

## Bouwen

Het Xcode-project wordt gegenereerd met [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```
xcodegen generate
open Raak.xcodeproj
```

`project.yml` is de bron van waarheid; het `.xcodeproj` staat gewoon mee
in het archief zodat klonen zonder XcodeGen ook werkt.
