import SwiftUI

/// De golven van het startscherm: vier vloeiende heuvels over de volle
/// breedte, om en om omhoog en omlaag. Kubische bogen met controlepunten op
/// een derde en twee derde van elke heuvel, zodat de lijn nergens knikt.
struct WaveLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        Self.addWave(to: &path, across: rect, midY: rect.midY, amplitude: rect.height / 2)
        return path
    }

    /// Tekent de golf verder vanaf het huidige punt; met `reversed` van
    /// rechts naar links, voor de onderrand van een gesloten vlak.
    static func addWave(to path: inout Path, across rect: CGRect, midY: CGFloat, amplitude: CGFloat, reversed: Bool = false) {
        let humps = 4
        let step = rect.width / CGFloat(humps) * (reversed ? -1 : 1)
        let startX = reversed ? rect.maxX : rect.minX
        for hump in 0..<humps {
            let from = startX + CGFloat(hump) * step
            let crest = midY + (hump.isMultiple(of: 2) ? -amplitude : amplitude)
            path.addCurve(
                to: CGPoint(x: from + step, y: midY),
                control1: CGPoint(x: from + step / 3, y: crest),
                control2: CGPoint(x: from + step * 2 / 3, y: crest)
            )
        }
    }
}

/// Een gevuld vlak met een golvende boven- en (optioneel) onderrand. De
/// golf slingert `amplitude` punten rond de randlijn; de inktlijn zelf komt
/// er als overlay bovenop, want een vlak en zijn rand vullen anders elkaars
/// halve lijndikte weg.
struct WavyBandShape: Shape {
    var amplitude: CGFloat
    var wavyBottom = true

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + amplitude))
        WaveLine.addWave(to: &path, across: rect, midY: rect.minY + amplitude, amplitude: amplitude)
        if wavyBottom {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - amplitude))
            WaveLine.addWave(to: &path, across: rect, midY: rect.maxY - amplitude, amplitude: amplitude, reversed: true)
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

/// De lichtblauwe band waarin de titel drijft: golvend boven en onder, met
/// een inktlijn op beide randen.
struct WavyBandView<Content: View>: View {
    var amplitude: CGFloat = 11
    var lineWidth: CGFloat = 3
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(.vertical, amplitude * 2 + 12)
            .background(WavyBandShape(amplitude: amplitude).fill(AppTheme.tintSky))
            .overlay(alignment: .top) {
                WaveLine()
                    .stroke(AppTheme.ink, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(height: amplitude * 2)
            }
            .overlay(alignment: .bottom) {
                WaveLine()
                    .stroke(AppTheme.ink, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(height: amplitude * 2)
            }
    }
}

/// De zee onder aan het scherm: golfrand bovenaan, gevuld tot de schermrand.
/// Puur decor — ligt achter de inhoud en vangt geen aanrakingen.
struct SeaBandView: View {
    var amplitude: CGFloat = 9
    var lineWidth: CGFloat = 3
    var height: CGFloat = 84

    var body: some View {
        WavyBandShape(amplitude: amplitude, wavyBottom: false)
            .fill(AppTheme.tintSky)
            .overlay(alignment: .top) {
                WaveLine()
                    .stroke(AppTheme.ink, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(height: amplitude * 2)
            }
            .frame(height: height)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

#Preview {
    VStack(spacing: 40) {
        WavyBandView {
            Text(verbatim: "Raak!")
                .font(AppTheme.rounded(42))
                .foregroundStyle(AppTheme.ink)
        }
        Spacer()
        SeaBandView()
    }
    .background(AppTheme.cream)
    .ignoresSafeArea(edges: .bottom)
}
