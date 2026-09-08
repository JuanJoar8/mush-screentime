import SwiftUI
import MushKit

// The component vocabulary. Four shapes, three radii, one lit surface.
// Rules live in brand/brand.json under `component_rules`.

// MARK: - Viewport

/// The one lit window. It is the only light surface in the app and it is reserved for
/// the creature. Nothing else goes in here.
///
/// `glow` is the `hero-glow` signature that `brand.json` has declared since the first
/// commit and that nothing ever drew: a halo in the creature's own stage tint, behind it,
/// so the light in the viewport comes *from* the character rather than from a flat fill.
/// It is the one soft edge in a drawing that is otherwise entirely hard — which is what
/// makes it read as ambient light instead of as a blurred object.
struct Viewport<Content: View>: View {
    /// Halo colour. `nil` for a viewport with nothing lit in it.
    var glow: Color?
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .background {
                ZStack {
                    Token.Color.viewport
                    if let glow {
                        GeometryReader { geo in
                            RadialGradient(
                                gradient: Gradient(stops: [
                                    .init(color: glow.opacity(0.30), location: 0),
                                    .init(color: glow.opacity(0.09), location: 0.48),
                                    .init(color: glow.opacity(0), location: 1)
                                ]),
                                center: UnitPoint(x: 0.5, y: 0.34),
                                startRadius: 0,
                                endRadius: max(geo.size.width, geo.size.height) * 0.66
                            )
                        }
                        .animation(.easeInOut(duration: Token.Duration.slow), value: glow)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Token.Radius.viewport, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Token.Radius.viewport, style: .continuous)
                    .strokeBorder(Token.Color.inkOnViewport.opacity(0.12), lineWidth: 1)
            )
    }
}

// MARK: - Panel

/// Matte grouping surface. No shadow: it separates by colour and hairline only.
struct Panel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Token.Color.panel)
            .clipShape(RoundedRectangle(cornerRadius: Token.Radius.panel, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Token.Radius.panel, style: .continuous)
                    .strokeBorder(Token.Color.line, lineWidth: 1)
            )
    }
}

// MARK: - Instrument label

/// Tiny tracked uppercase label over a hairline, with its value right-aligned in mono.
/// This is the section device for the whole app: it encodes "reading off an instrument",
/// which is what the product actually does.
struct InstrumentLabel: View {
    let title: String
    var value: String?
    var valueColor: Color = Token.Color.ink

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(.mushLabel())
                    .tracking(0.9)
                    .foregroundStyle(Token.Color.inkDim)
                Spacer(minLength: 12)
                if let value {
                    Text(value)
                        .font(.mushData())
                        .foregroundStyle(valueColor)
                }
            }
            Rectangle()
                .fill(Token.Color.line)
                .frame(height: 1)
        }
    }
}

// MARK: - Pill

/// Radius 999. Only for what is switched on right now: state, streak, active window.
struct Pill: View {
    let text: String
    var tint: Color = Token.Color.inkDim
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(.mushLabel())
            .tracking(0.6)
            .foregroundStyle(filled ? Token.Color.ground : tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(filled ? tint : Color.clear)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(filled ? 0 : 0.5), lineWidth: 1))
    }
}

// MARK: - Provenance chip

/// Mandatory on anything sourced from Apple's report extension. Those are the only
/// numbers in the app whose derivation we cannot show, so they get marked
/// (docs/01-FEASIBILITY.md section 3).
struct ProvenanceChip: View {
    var body: some View {
        Text("FROM IOS")
            .font(.system(size: 9, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(Token.Color.ground)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Token.Color.inkDim)
            .clipShape(Capsule())
    }
}

// MARK: - Receipt row

/// One line of the "why it moved" receipt: reason left, signed value right in mono.
/// This is a first-class screen, not a debug view — it is what makes the score
/// trustworthy, and it is the thing the reference products get wrong.
struct ReceiptRow: View {
    let reason: String
    let value: Double

    private var sign: String { value >= 0 ? "+" : "−" }
    private var tint: Color { value >= 0 ? Token.Color.good : Token.Color.bad }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(reason)
                .font(.system(size: 15))
                .foregroundStyle(Token.Color.ink)
            Spacer(minLength: 8)
            Text("\(sign)\(String(format: "%.0f", abs(value)))")
                .font(.mushData(15))
                .foregroundStyle(tint)
        }
        .padding(.vertical, 7)
    }
}

// MARK: - Primary action

/// One contextual action, always the same shape. Press feedback uses `instant`/`fast`,
/// never the surface durations.
struct PrimaryAction: View {
    let title: String
    var tint: Color
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Token.Color.ground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: Token.Radius.panel, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.985 : 1)
        .animation(.easeOut(duration: Token.Duration.instant), value: pressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
    }
}

// MARK: - Settle

/// The discrete-change language: a value that updates lands rather than cross-fades.
/// Only transform and opacity, both compositor-friendly.
struct Settle: ViewModifier {
    let trigger: AnyHashable
    @State private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: trigger) {
                withAnimation(.easeOut(duration: Token.Duration.instant)) { scale = 1.04 }
                withAnimation(.easeOut(duration: Token.Duration.base).delay(Token.Duration.instant)) {
                    scale = 1
                }
            }
    }
}

extension View {
    func settle(on trigger: some Hashable) -> some View {
        modifier(Settle(trigger: AnyHashable(trigger)))
    }
}
