import SwiftUI

/// Het aankoopscherm van de Gezinsversie: wat je krijgt, één prijs — en de
/// ouder-poort vóór het hele scherm, niet alleen vóór de kassa.
struct PaywallView: View {
    let entitlements: EntitlementStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.metrics) private var m

    @State private var gateQuestion: ParentalGateQuestion?
    /// De poort staat vóór het hele scherm: ook de prijzen en de koopknoppen
    /// zijn oudergebied (kindercategorie).
    @State private var gatePassed = false
    @State private var isBusy = false
    /// Uitleg wanneer kopen of terugzetten niet doorging; annuleren blijft
    /// stil.
    @State private var purchaseNotice: String?

    private var priceText: String {
        entitlements.familyProduct?.displayPrice ?? "…"
    }

    var body: some View {
        ZStack {
            ThemedBackground()

            if gatePassed || entitlements.isFamilyUnlocked {
                paywallContent
            }

            // De sluitknop hoort in de hoek van het vénster, niet in de hoek
            // van de smallere tekstkolom — en blijft ook mét dichte poort
            // bereikbaar, zodat een kind gewoon weg kan.
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Label("Sluiten", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                            .font(.system(size: m.captionSize + 2, weight: .black))
                            .foregroundStyle(AppTheme.ink)
                            .frame(width: m.tapTarget, height: m.tapTarget)
                    }
                    .buttonStyle(ToyButtonStyle(fill: AppTheme.card, radius: m.cellCorner, depth: m.shallowDepth, border: m.thinBorder))
                }
                Spacer()
            }
            // Ruimer dan de standaardmarge: de ronde hoek van het sheet
            // liep anders dwars achter de knop door en knipte zijn schaduw.
            .padding(m.gutter * 1.4)

            // De ouder-poort: verplicht voor de kindercategorie, en eerlijk
            // gezegd gewoon verstandig.
            if let question = gateQuestion {
                gateOverlay(question)
            }

            if let purchaseNotice {
                ToyDialog(
                    title: String(localized: "Dat lukte niet"),
                    message: purchaseNotice,
                    confirmTitle: String(localized: "Oké"),
                    onConfirm: dismissNotice,
                    onCancel: dismissNotice
                )
            }
        }
        .interactiveDismissDisabled(isBusy)
        .onAppear {
            // De vraag komt meteen bij het openen; wie de winkel al heeft,
            // hoeft niets meer te rekenen.
            if !entitlements.isFamilyUnlocked && !gatePassed {
                gateQuestion = .make()
            }
        }
        // De prijs kan bij het openen nog ontbreken (geen netwerk bij de
        // start); hier krijgt hij een tweede kans.
        .task {
            if entitlements.familyProduct == nil {
                await entitlements.load()
            }
        }
    }

    private var paywallContent: some View {
        ScrollView {
            VStack(spacing: m.gutter) {
                // Dezelfde speelgoedtegels als het startscherm: de paywall
                // hoort bij de familie, niet bij een winkel.
                HStack(spacing: -m.discSize * 0.15) {
                    TileBadge(symbol: "sailboat.fill", colorIndex: 1, size: m.discSize * 0.95)
                        .rotationEffect(.degrees(-8))
                        .zIndex(1)
                    TileBadge(symbol: "figure.2.and.child.holdinghands", colorIndex: 0, size: m.discSize * 1.1)
                        .zIndex(2)
                    TileBadge(symbol: "burst.fill", colorIndex: 2, size: m.discSize * 0.95)
                        .rotationEffect(.degrees(8))
                        .offset(y: m.discSize * 0.1)
                }
                .accessibilityHidden(true)
                .padding(.top, m.gutter)

                Text("Gezinsversie")
                    .font(AppTheme.rounded(m.titleSize * 0.7))
                    .foregroundStyle(AppTheme.headline)

                Text("Eén keer kopen, voor het hele gezin — ook via Delen met gezin.")
                    .font(AppTheme.rounded(m.captionSize + 2, .bold))
                    .foregroundStyle(AppTheme.soft)
                    .multilineTextAlignment(.center)

                VStack(spacing: m.gutter * 0.7) {
                    feature("graduationcap.fill", tint: AppTheme.tintSky, symbolColorIndex: 1,
                            "Alle drie de tegenstanders: Dommel, Robbie en Professor Punt")
                    feature("paintpalette.fill", tint: AppTheme.tintCoral, symbolColorIndex: 0,
                            "Alle kleurenthema's: Snoep, Oceaan en Nacht")
                    feature("trophy.fill", tint: AppTheme.tintAmber, symbolColorIndex: 2,
                            "Statistieken per speler, met trofeeën en gezinsrecords")
                }

                if entitlements.isFamilyUnlocked {
                    Label("Ontgrendeld — veel plezier!", systemImage: "checkmark.seal.fill")
                        .font(AppTheme.rounded(m.bodySize))
                        .foregroundStyle(AppTheme.mint)
                        .padding(.top, m.gutter)
                } else {
                    Button(action: startPurchase) {
                        Text("Ontgrendel voor \(priceText)")
                            .font(AppTheme.rounded(m.defaultButton.textSize))
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: m.defaultButton.height)
                    }
                    .buttonStyle(ToyButtonStyle(
                        fill: AppTheme.mint,
                        radius: m.buttonCorner,
                        depth: m.depth,
                        border: m.border
                    ))
                    .disabled(isBusy)

                    Button(action: startRestore) {
                        Text("Eerder gekocht? Zet terug")
                            .font(AppTheme.rounded(m.captionSize, .bold))
                            .foregroundStyle(AppTheme.soft)
                            .frame(minHeight: m.tapTarget)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .disabled(isBusy)
                }
            }
            .padding(.horizontal, m.gutter * 1.4)
            .padding(.top, m.gutter)
            .padding(.bottom, m.gutter * 2)
            .frame(maxWidth: m.overlayMaxWidth)
            .frame(maxWidth: .infinity)
        }
    }

    /// Eén feature op een eigen kaart, met het icoon op een gekleurd
    /// tegeltje — dezelfde taal als de menutegels op het startscherm.
    private func feature(_ icon: String, tint: Color, symbolColorIndex: Int, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: m.gutter * 0.8) {
            TileBadge(symbol: icon, colorIndex: symbolColorIndex, size: m.avatarSize * 0.6)
                .frame(width: m.avatarSize * 0.9, height: m.avatarSize * 0.9)
                .toyBlock(fill: tint, radius: m.cellCorner, depth: 0, border: m.thinBorder + 0.5)

            Text(text)
                .font(AppTheme.rounded(m.captionSize + 2, .bold))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(m.gutter * 0.8)
        .toyBlock(fill: AppTheme.card, radius: m.cardCorner, depth: m.shallowDepth, border: m.thinBorder + 0.5)
        .accessibilityElement(children: .combine)
    }

    private func gateOverlay(_ question: ParentalGateQuestion) -> some View {
        ZStack {
            // Tikken naast de kaart sluit het hele scherm; VoiceOver krijgt
            // de opties op de kaart, niet dit vlak.
            AppTheme.ink.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
                .accessibilityHidden(true)

            VStack(spacing: m.gutter * 0.8) {
                Text("Vraag even aan papa of mama")
                    .font(AppTheme.rounded(m.bodySize + 2))
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.center)

                Text(question.text)
                    .font(AppTheme.rounded(m.titleSize * 0.6))
                    .foregroundStyle(AppTheme.coral)

                HStack(spacing: m.gutter * 0.7) {
                    ForEach(question.options, id: \.self) { option in
                        Button {
                            answerGate(with: option, question: question)
                        } label: {
                            Text("\(option)")
                                .font(AppTheme.rounded(m.bodySize + 2))
                                .foregroundStyle(AppTheme.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: m.tapTarget)
                        }
                        .buttonStyle(ToyButtonStyle(fill: AppTheme.card, radius: m.cellCorner, depth: m.shallowDepth, border: m.thinBorder))
                    }
                }
            }
            .padding(m.gutter * 1.4)
            .toyBlock(fill: AppTheme.card, radius: m.dialogCorner, depth: m.heroDepth, border: m.border)
            .frame(maxWidth: m.overlayMaxWidth * 0.82)
            .padding(m.gutter * 2)
            .accessibilityAddTraits(.isModal)
        }
        .transition(.opacity)
    }

    private func answerGate(with option: Int, question: ParentalGateQuestion) {
        guard option == question.answer else {
            // Fout: nieuwe vraag, zodat gokken niet loont.
            gateQuestion = .make()
            return
        }
        withAnimation(.easeOut(duration: 0.15)) {
            gateQuestion = nil
            gatePassed = true
        }
    }

    // MARK: - Kassa

    private func startPurchase() {
        isBusy = true
        Task {
            await purchase()
            isBusy = false
        }
    }

    private func startRestore() {
        isBusy = true
        Task {
            await restore()
            isBusy = false
        }
    }

    /// Annuleren is een keuze en blijft stil; mislukken en wachten-op-ouder
    /// verdienen uitleg — anders lijkt de knop gewoon kapot.
    private func purchase() async {
        switch await entitlements.purchaseFamily() {
        case .success, .cancelled:
            break
        case .pending:
            showNotice(String(localized: "De aankoop wacht nog op goedkeuring van een ouder."))
        case .failed:
            showNotice(String(localized: "Kopen is niet gelukt. Controleer de internetverbinding en probeer het straks nog eens."))
        }
    }

    /// Terugzetten dat stilletjes niets doet lijkt kapot; hier hoort een
    /// antwoord bij, ook als dat "niets gevonden" is.
    private func restore() async {
        let synced = await entitlements.restorePurchases()
        if !synced {
            showNotice(String(localized: "Terugzetten is niet gelukt. Controleer de internetverbinding en probeer het straks nog eens."))
        } else if !entitlements.isFamilyUnlocked {
            showNotice(String(localized: "Er is geen eerdere aankoop gevonden voor dit Apple-account."))
        }
    }

    private func showNotice(_ text: String) {
        withAnimation(.easeOut(duration: 0.15)) {
            purchaseNotice = text
        }
    }

    private func dismissNotice() {
        withAnimation(.easeOut(duration: 0.15)) {
            purchaseNotice = nil
        }
    }
}

#Preview {
    PaywallView(entitlements: EntitlementStore(previewUnlocked: false))
        .appMetrics()
}
