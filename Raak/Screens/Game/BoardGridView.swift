import SwiftUI

/// Eén zee als raster op een blauw tafelblad. Dezelfde view tekent beide
/// borden: de vijandelijke zee (boten verstopt, tikken om te schieten) en
/// de eigen zee (boten zichtbaar, alleen kijken). De maat van de vakjes
/// volgt uit de beschikbare ruimte.
struct BoardGridView: View {
    let board: PlayerBoard
    /// Eigen zee toont de vloot; op de vijandelijke zee blijft alleen een
    /// gezonken boot zichtbaar.
    let showsShips: Bool
    let isEnabled: Bool
    /// Het laatste schot krijgt een randje, zodat je ziet wat er net viel.
    var lastShot: Coord?
    var onFire: ((Coord) -> Void)?

    @Environment(\.metrics) private var m

    var body: some View {
        GeometryReader { proxy in
            let count = board.gridSize
            let gap = m.boardGap * 0.55
            let padding = m.boardPadding * 0.75
            let width = (proxy.size.width - padding * 2 - gap * CGFloat(count - 1)) / CGFloat(count)
            let height = (proxy.size.height - padding * 2 - gap * CGFloat(count - 1)) / CGFloat(count)
            let side = max(min(width, height), 8)
            let gridWidth = side * CGFloat(count) + gap * CGFloat(count - 1) + padding * 2

            Grid(horizontalSpacing: gap, verticalSpacing: gap) {
                ForEach(0..<count, id: \.self) { row in
                    GridRow {
                        ForEach(0..<count, id: \.self) { col in
                            cell(at: Coord(row: row, col: col), side: side)
                        }
                    }
                }
            }
            .padding(padding)
            .toyBlock(fill: AppTheme.sky, radius: m.cardCorner, depth: m.depth, border: m.border)
            .frame(width: gridWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private func cell(at coord: Coord, side: CGFloat) -> some View {
        let ship = board.ship(at: coord)
        let isShot = board.isShot(coord)
        let isHit = isShot && ship != nil
        let revealShip = ship.map { showsShips || $0.isSunk } ?? false

        let content = SeaCellView(
            side: side,
            shipKind: revealShip ? ship?.kind : nil,
            isShot: isShot,
            isHit: isHit,
            isSunk: ship?.isSunk ?? false,
            isLastShot: lastShot == coord
        )

        if let onFire {
            Button {
                onFire(coord)
            } label: {
                content
            }
            .buttonStyle(CellButtonStyle())
            .disabled(!isEnabled || isShot)
            .accessibilityLabel(accessibilityLabel(for: coord, ship: ship, isShot: isShot, isHit: isHit))
            // Geen hint op vakjes die toch niet reageren; dat scheelt
            // VoiceOver een hoop geruis.
            .accessibilityHint(isEnabled && !isShot ? Text("Schiet") : Text(verbatim: ""))
        } else {
            content
                .accessibilityLabel(accessibilityLabel(for: coord, ship: ship, isShot: isShot, isHit: isHit))
        }
    }

    /// Zonder de automatische dim van de systeemknop: een beschoten vakje
    /// is "uitgeschakeld" maar toont zijn staat zelf al.
    private struct CellButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.88 : 1)
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
        }
    }

    private func accessibilityLabel(for coord: Coord, ship: Ship?, isShot: Bool, isHit: Bool) -> String {
        let place = String(localized: "Rij \(coord.row + 1), kolom \(coord.col + 1)")
        if let ship, ship.isSunk {
            return String(localized: "\(place), \(ship.kind.title) gezonken")
        }
        if isHit {
            return String(localized: "\(place), raak")
        }
        if isShot {
            return String(localized: "\(place), mis")
        }
        if let ship, showsShips {
            return String(localized: "\(place), jouw \(ship.kind.title)")
        }
        return String(localized: "\(place), open zee")
    }
}

/// Eén vakje zee: licht zolang er niets gebeurde, donker water met een
/// kruis bij een misser, een ster bij een voltreffer en de bootkleur zodra
/// die te zien mag zijn.
private struct SeaCellView: View {
    let side: CGFloat
    let shipKind: ShipKind?
    let isShot: Bool
    let isHit: Bool
    let isSunk: Bool
    let isLastShot: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var corner: CGFloat { side * 0.24 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(fillColor)

            if isHit {
                // De voltreffer: een amberkleurige knal, het hart van de app.
                Image(systemName: "burst.fill")
                    .font(.system(size: side * 0.62, weight: .black))
                    .foregroundStyle(AppTheme.amber)
            } else if isShot {
                // De misser: het vakje kleurt donker water en krijgt een dik
                // wit kruis — "hier zit niets, al geprobeerd" leest zo ook op
                // het kleine bord in één oogopslag.
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: side * 0.5, weight: .black))
                    .foregroundStyle(.white)
            }

            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(
                    isLastShot ? AppTheme.coral : AppTheme.ink.opacity(0.55),
                    lineWidth: isLastShot ? max(side * 0.09, 2) : max(side * 0.045, 1)
                )
        }
        // Een gezonken boot treedt terug, net als een gevonden paar in Memo.
        .opacity(isSunk ? 0.55 : 1)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.35, dampingFraction: 0.7), value: isShot)
        .animation(.easeOut(duration: 0.3), value: isSunk)
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }

    private var fillColor: Color {
        if let shipKind {
            return AvatarBadge.palette[shipKind.colorIndex % AvatarBadge.palette.count]
        }
        // Beschoten leeg water wordt donker: het contrast tussen "nog open"
        // (licht) en "al geprobeerd" (donker) draagt de leesbaarheid, het
        // kruis bevestigt alleen nog.
        if isShot && !isHit {
            return AppTheme.sky
        }
        return AppTheme.tintSky
    }
}

/// De vloot als legenda onder een bord: per boot zijn naam-loze silhouet
/// van blokjes, doorgestreept zodra hij gezonken is. Zo ziet een kind in
/// één oogopslag wat er nog vaart.
struct FleetLegendView: View {
    let ships: [Ship]

    @Environment(\.metrics) private var m

    var body: some View {
        HStack(spacing: m.gutter * 0.8) {
            ForEach(ships) { ship in
                HStack(spacing: 2) {
                    ForEach(0..<ship.kind.length, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(ship.isSunk ? AppTheme.offFill : AvatarBadge.palette[ship.kind.colorIndex % AvatarBadge.palette.count])
                            .overlay {
                                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                    .strokeBorder(ship.isSunk ? AppTheme.offInk : AppTheme.ink, lineWidth: 1)
                            }
                            .frame(width: m.captionSize * 0.8, height: m.captionSize * 0.8)
                    }
                }
                .overlay {
                    if ship.isSunk {
                        Rectangle()
                            .fill(AppTheme.ink.opacity(0.7))
                            .frame(height: 2)
                            .rotationEffect(.degrees(-8))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    ship.isSunk
                        ? String(localized: "\(ship.kind.title), gezonken")
                        : String(localized: "\(ship.kind.title), vaart nog")
                )
            }
        }
    }
}

#Preview {
    var rng = SplitMix64(seed: 7)
    var board = BoardSize.medium.placeFleet(using: &rng)
    let _ = board.receiveShot(at: Coord(row: 0, col: 0))
    let _ = board.ships.first.map { ship in
        for cell in ship.cells { _ = board.receiveShot(at: cell) }
    }

    return VStack(spacing: 20) {
        BoardGridView(board: board, showsShips: false, isEnabled: true, lastShot: Coord(row: 0, col: 0), onFire: { _ in })
            .frame(height: 360)
        FleetLegendView(ships: board.ships)
        BoardGridView(board: board, showsShips: true, isEnabled: false)
            .frame(height: 200)
    }
    .padding()
    .background(AppTheme.cream)
    .appMetrics()
}
