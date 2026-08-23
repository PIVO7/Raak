# TestFlight — Raak!

De archive staat klaar; dit document bevat de teksten die TestFlight vraagt en
het stappenplan om de eerste build bij testers te krijgen.

## Wat al klaarstaat

- **Archive "Raak 1.0 (1)"** (2026-08-23) — zichtbaar in Xcode → Window →
  **Organizer**. Bevat Raak.app (nl/en/fr) en de dSYM-symbolen, versie
  1.0 (1), minimum iOS 17.0, bundle-id com.pivo7.raak, team VB6FS3N78T.
  Het uploaden zelf (stap 3) vraagt je Apple-account in Xcode; dat is de
  enige stap die niet vooraf kon.
- `ITSAppUsesNonExemptEncryption` staat op NO in het project, dus TestFlight
  slaat de export-compliance-vraag bij elke build over.
- Eén universeel 1024-appicoon (vereist voor de upload) zit in de asset catalog.
- De app is drietalig (nl/en/fr) met Nederlands als ontwikkeltaal.
- De StoreKit-configuratie `Raak.storekit` zit in het run-scheme, zodat de
  Gezinsversie lokaal te testen is vóór het product in App Store Connect staat.

## Stappenplan (eenmalig)

1. **App Store Connect → Apps → ➕ Nieuwe app**
   - Platform iOS, naam **Raak!**, primaire taal **Nederlands**,
     bundle-id **com.pivo7.raak**, SKU bv. `raak-001`.
2. **In-app-aankoop aanmaken** (mag ook later, maar vóór het testen van de
   Gezinsversie): niet-verbruiksartikel `com.pivo7.raak.gezin`,
   gezinsdeling aan — alle waarden staan in [appstore-tekst.md](appstore-tekst.md).
3. **Uploaden**: Xcode → Window → Organizer → archive "Raak 1.0 (1)" →
   **Distribute App → TestFlight & App Store → Upload**. Automatische
   ondertekening regelt het distributiecertificaat.
4. Na 5–15 minuten verwerken verschijnt de build onder het tabblad
   **TestFlight**. Vul daar de testinformatie in (teksten hieronder).
5. **Interne testers** (meteen, geen review): voeg jezelf en gezinsleden toe
   onder Interne testen. Zij krijgen een uitnodiging in de TestFlight-app.
6. **Externe testers** (optioneel, na een korte beta-review van Apple): maak
   een externe groep of deel een publieke link.

## Testinformatie (tabblad TestFlight, eenmalig)

| Veld | Waarde |
|---|---|
| Beta-appbeschrijving | Raak! is een zeeslagspel voor kinderen en het gezin: verstop je vloot en schiet om de beurt, aan één toestel of solo tegen de computer. Geen reclame, geen accounts, alles blijft op het toestel. |
| Feedback-e-mail | jelle@pivo7.be |
| Contactgegevens beta-review | Jelle Wauters · jelle@pivo7.be |
| Aanmelden vereist? | Nee |

## "Wat te testen" (per build in te vullen)

> Eerste build van Raak! Alles mag stuk, maar kijk vooral naar:
>
> - **Een heel potje** tegen elkaar aan één toestel: houdt het
>   doorgeefscherm de zeeën echt geheim, en klopt raak/mis/zinken?
> - **Solo tegen alle drie de tegenstanders**: voelt Dommel makkelijk en
>   Professor Punt moeilijk-maar-eerlijk?
> - **De Gezinsversie kopen** (gratis in TestFlight): lukt de ouder-poort, en
>   ontgrendelen thema's, statistieken en de extra tegenstanders meteen?
> - **Taal**: zet het toestel eens op Engels of Frans — is álles vertaald?
> - **Onderbreken**: sluit de app midden in een potje af (ook tijdens het
>   vloot leggen) en open opnieuw — gaat het spel verder waar het was?
> - **De drie bordgroottes**, husselen, en de trofeeënkast na een paar potjes.
>
> Feedback graag via de TestFlight-app (schermafbeelding + opmerking) of
> naar jelle@pivo7.be.

## Goed om te weten tijdens het testen

- **Aankopen in TestFlight zijn gratis** en gebruiken de sandbox; "Eerder
  gekocht? Zet terug" werkt daar ook. Het product moet wél eerst in App Store
  Connect bestaan (stap 2), anders blijft de prijs op "…" staan.
- **Volgende build uploaden**: verhoog `CURRENT_PROJECT_VERSION` in
  project.yml (1 → 2), draai `xcodegen generate`, archiveer en upload
  opnieuw.
  Testers krijgen de update automatisch.
- De **privacyverklaring-URL** is voor TestFlight nog niet verplicht, wel voor
  de echte review — regel die dus ergens tijdens de testronde
  (inhoud: [privacyverklaring.md](privacyverklaring.md)).
