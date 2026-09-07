import SwiftUI
import MushKit

/// Home. The hierarchy is deliberate and departs from the brief in two ways
/// (docs/08-DECISIONS.md D11):
///
/// 1. The health number lives *inside* the viewport, on the creature. As two separate
///    rows they said the same thing twice and cost the fold.
/// 2. The primary action sits directly under it. In a self-control app the moment of
///    intent is fragile and must not require scrolling.
struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                creature
                action
                today
                if model.streak > 0 || model.provisionalDelta != 0 { progress }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Token.Color.ground)
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("MUSH")
                .font(.mushDisplay(26))
                .foregroundStyle(Token.Color.ink)
            Spacer()
            if model.isMocked {
                Pill(text: "Synthetic data", tint: Token.Color.warn)
            }
        }
        .padding(.top, 8)
    }

    // MARK: The creature and its number, as one object

    private var creature: some View {
        Viewport {
            VStack(spacing: 0) {
                // The creature gets its face to itself. Nothing overlaps it.
                BlobView(stage: model.stage)
                    .frame(height: 210)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(Int(model.health.rounded()))")
                        .font(.mushDisplay(66))
                        .foregroundStyle(Token.Color.inkOnViewport)
                        .settle(on: Int(model.health.rounded()))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.stage.title.uppercased())
                            .font(.mushLabel())
                            .tracking(2.0)
                            .foregroundStyle(Token.Color.inkOnViewport)
                        Text(model.stage.mood)
                            .font(.system(size: 13))
                            .foregroundStyle(Token.Color.inkOnViewport.opacity(0.55))
                    }
                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
            }
            .padding(.top, 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Brain health \(Int(model.health.rounded())) out of 100. \(model.stage.title): \(model.stage.mood)."
        )
    }

    // MARK: Contextual primary action

    private var action: some View {
        PrimaryAction(title: model.primaryAction.title, tint: model.stage.tint) {
            Task { await model.performPrimaryAction() }
        }
    }

    // MARK: Today

    private var today: some View {
        Panel {
            VStack(spacing: 14) {
                if let record = model.today, record.hasSignal {
                    InstrumentLabel(
                        title: "Today",
                        value: "\(record.distractingMinutes) / \(record.budgetMinutes) min",
                        valueColor: record.isGreen ? Token.Color.good : Token.Color.bad
                    )
                    BudgetBar(record: record)
                    if record.isPartial {
                        // Honest about incompleteness rather than quietly rounding up.
                        Text("Some sessions never reported a close. The real number is higher than this.")
                            .font(.system(size: 12))
                            .foregroundStyle(Token.Color.inkDim)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    InstrumentLabel(title: "Today", value: "no signal")
                    Text("Nothing measured yet. This is not a zero — we simply cannot see it.")
                        .font(.system(size: 13))
                        .foregroundStyle(Token.Color.inkDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: Progress

    private var progress: some View {
        Panel {
            VStack(spacing: 14) {
                InstrumentLabel(
                    title: "Provisional",
                    value: String(format: "%+.0f", model.provisionalDelta),
                    valueColor: model.provisionalDelta >= 0 ? Token.Color.good : Token.Color.bad
                )
                HStack(spacing: 8) {
                    if model.streak > 0 {
                        Pill(
                            text: "\(model.streak) day streak",
                            tint: Token.Color.good,
                            filled: true
                        )
                    }
                    if let improvement = model.improvement {
                        Pill(text: String(format: "%+.0f%% vs last week", improvement * 100),
                             tint: improvement <= 0 ? Token.Color.good : Token.Color.warn)
                    }
                    Spacer()
                }
                Text("Nothing is committed until midnight.")
                    .font(.system(size: 12))
                    .foregroundStyle(Token.Color.inkDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Budget as a filled track. Not a ring around the character — the creature is not a
/// progress indicator, and wrapping it in one would turn it into chrome.
private struct BudgetBar: View {
    let record: DayRecord

    var body: some View {
        GeometryReader { geo in
            let ratio = min(record.budgetRatio ?? 0, 2.0) / 2.0
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Token.Color.panelRaised)
                Capsule()
                    .fill(record.isGreen ? Token.Color.good : Token.Color.bad)
                    .frame(width: max(4, geo.size.width * ratio))
                // The budget line sits at the halfway mark, since the track runs to 2x.
                Rectangle()
                    .fill(Token.Color.ink.opacity(0.45))
                    .frame(width: 1)
                    .offset(x: geo.size.width * 0.5)
            }
        }
        .frame(height: 8)
        .animation(.easeOut(duration: Token.Duration.base), value: record.distractingMinutes)
    }
}
