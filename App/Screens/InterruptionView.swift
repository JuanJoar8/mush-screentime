import SwiftUI
import MushKit

/// The pause. Path B's entire intervention, and the only thing standing between the tap
/// and the feed.
///
/// It cannot block. A Shortcuts automation foregrounded us the instant the app opened;
/// the app is still there, one swipe away, and the copy says so. What this buys is the
/// two seconds in which the decision stops being automatic.
///
/// Deliberately **not** a breathing exercise or a game. It is a hold: finger down, a ring
/// fills, nothing to look at. Lift early and it resets. The cost is patience, which is
/// the one thing a compulsive open has none of.
struct InterruptionView: View {
    let interruption: PendingInterruption
    let stage: BrainStage
    let costPerOpen: Double
    let onDecision: (InterruptionOutcome) -> Void

    @State private var holdStarted: Date?
    @State private var progress: Double = 0
    @State private var isReleased = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let hold = Intervention(seconds: 6, prompt: "Hold.")

    var body: some View {
        ZStack {
            Token.Color.groundDeep.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Text(interruption.appName.uppercased())
                    .font(.mushLabel())
                    .tracking(2)
                    .foregroundStyle(Token.Color.inkDim)

                Text(isReleased ? "Go on, then." : "You opened it.")
                    .font(.mushDisplay(34))
                    .foregroundStyle(Token.Color.ink)
                    .padding(.top, 6)
                    .animation(.easeOut(duration: Token.Duration.base), value: isReleased)

                ZStack {
                    Circle()
                        .stroke(Token.Color.line, lineWidth: 3)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            stage.tint,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    BlobView(stage: stage)
                        .padding(26)
                }
                .frame(width: 230, height: 230)
                .padding(.top, 28)
                // Scale, not size: a transform costs nothing to animate, a frame change
                // relays out the whole stack every frame.
                .scaleEffect(holdStarted != nil && !reduceMotion ? 0.97 : 1)
                .animation(.easeOut(duration: Token.Duration.fast), value: holdStarted != nil)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in if holdStarted == nil { holdStarted = Date() } }
                        .onEnded { _ in
                            if !isReleased { holdStarted = nil; progress = 0 }
                        }
                )

                Text(promptText)
                    .font(.system(size: 14))
                    .foregroundStyle(Token.Color.inkDim)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .padding(.top, 26)

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    PrimaryAction(title: "Not now", tint: Token.Color.ink) {
                        onDecision(.turnedBack)
                    }

                    if isReleased {
                        Button {
                            onDecision(.continued)
                        } label: {
                            Text("Open \(interruption.appName) anyway")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Token.Color.inkDim)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }

                    // The honest footnote. Nothing here is a lock, and pretending
                    // otherwise is the pattern this project refuses (02-PRODUCT.md).
                    Text("This does not block anything. \(interruption.appName) is still open behind this screen.")
                        .font(.system(size: 11))
                        .foregroundStyle(Token.Color.inkDim)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 30)
            }
        }
        .animation(.easeOut(duration: Token.Duration.base), value: isReleased)
        .task(id: holdStarted) { await runHold() }
    }

    private var promptText: String {
        if isReleased {
            return "It costs \(Int(costPerOpen)) point\(costPerOpen == 1 ? "" : "s") either way. It is still your call."
        }
        return holdStarted == nil
            ? "Hold the brain for six seconds to unlock the way through."
            : "Keep holding."
    }

    /// Ticks the ring while the finger is down. Resets the moment it lifts, which is
    /// enforced by `.task(id:)` cancelling and restarting on every state change.
    private func runHold() async {
        guard holdStarted != nil, !isReleased else { return }
        let tick = UInt64(1_000_000_000 / 30)
        while let started = holdStarted, !isReleased {
            let elapsed = Date().timeIntervalSince(started)
            progress = hold.progress(heldFor: elapsed)
            if hold.isSatisfied(heldFor: elapsed) {
                isReleased = true
                progress = 1
                return
            }
            try? await Task.sleep(nanoseconds: tick)
            if Task.isCancelled { return }
        }
    }
}

#Preview("Interruption") {
    InterruptionView(
        interruption: PendingInterruption(appKey: "instagram", appName: "Instagram"),
        stage: .buzzed,
        costPerOpen: 2
    ) { _ in }
}
