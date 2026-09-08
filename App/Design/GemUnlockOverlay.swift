import SwiftUI
import MushKit

/// The unlock moment.
///
/// A gem that appears silently on a shelf nobody opened is not a reward — it is a row in
/// a database. This is the one place in the app with a real animation budget, and it is
/// justified by frequency: there are twelve gems, most people will see this fewer than a
/// dozen times ever. That is the "rare / first-time" tier, where delight belongs.
///
/// Everything else in the product gets `instant` or `fast` and no flourish.
struct GemUnlockOverlay: View {
    let gems: [Gem]
    let tint: Color
    let onDismiss: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var gem: Gem? { gems.first }

    var body: some View {
        ZStack {
            // Scrim. Tapping anywhere dismisses — this is a notice, not a decision.
            Token.Color.groundDeep
                .opacity(appeared ? 0.72 : 0)
                .ignoresSafeArea()
                .onTapGesture { close() }

            if let gem {
                VStack(spacing: 18) {
                    GemBadge(gem: gem, isUnlocked: true, tint: tint)
                        .frame(width: 120, height: 120)
                        // Never from scale(0): nothing in the real world appears out of
                        // nothing. It arrives already present, and settles.
                        .scaleEffect(appeared || reduceMotion ? 1 : 0.86)
                        .rotationEffect(.degrees(appeared || reduceMotion ? 0 : -8))

                    VStack(spacing: 6) {
                        Text("EARNED")
                            .font(.mushLabel())
                            .tracking(2)
                            .foregroundStyle(tint)

                        Text(gem.title)
                            .font(.mushDisplay(34))
                            .foregroundStyle(Token.Color.ink)
                            .multilineTextAlignment(.center)

                        Text(gem.requirement)
                            .font(.system(size: 14))
                            .foregroundStyle(Token.Color.inkDim)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 260)
                    }

                    if gems.count > 1 {
                        Text("and \(gems.count - 1) more")
                            .font(.mushData(12))
                            .foregroundStyle(Token.Color.inkDim)
                    }

                    Button(action: close) {
                        Text("Good")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Token.Color.groundDeep)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(tint, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                    .frame(maxWidth: 220)
                }
                .padding(30)
                .background(Token.Color.panel, in: RoundedRectangle(cornerRadius: Token.Radius.viewport))
                .overlay(
                    RoundedRectangle(cornerRadius: Token.Radius.viewport)
                        .strokeBorder(Token.Color.line, lineWidth: 1)
                )
                .padding(.horizontal, 32)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.94)
            }
        }
        .onAppear {
            // Strong ease-out. It should land, not drift in.
            withAnimation(.easeOut(duration: Token.Duration.slow)) { appeared = true }
        }
        .accessibilityAddTraits(.isModal)
    }

    private func close() {
        withAnimation(.easeOut(duration: Token.Duration.fast)) { appeared = false }
        // Let the exit play before the state clears, so it leaves the way it arrived.
        DispatchQueue.main.asyncAfter(deadline: .now() + Token.Duration.fast) { onDismiss() }
    }
}

#Preview("Unlock") {
    ZStack {
        Token.Color.ground.ignoresSafeArea()
        GemUnlockOverlay(
            gems: [GemCatalog.all[3]],
            tint: Token.Color.stageCrisp
        ) {}
    }
}
