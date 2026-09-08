import SwiftUI
import MushKit

/// The Receipt. The screen that makes the number believable.
///
/// Every committed day shows its arithmetic by name and value. This is deliberately a
/// first-class screen rather than a debug view: a health score with no visible
/// derivation is the thing this category consistently gets wrong.
struct BrainView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let entry = model.lastEntry {
                    receipt(entry)
                } else {
                    Panel {
                        InstrumentLabel(title: "Receipt")
                        Text("Nothing committed yet. Days settle at midnight.")
                            .font(.system(size: 13))
                            .foregroundStyle(Token.Color.inkDim)
                            .padding(.top, 10)
                    }
                }
                Panel {
                    GemShelf(unlocked: model.gems.unlocked, tint: model.stage.tint)
                }
                stages
                howItWorks
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Token.Color.ground)
    }

    private func receipt(_ entry: HealthEntry) -> some View {
        Panel {
            VStack(spacing: 12) {
                InstrumentLabel(
                    title: "Why it moved",
                    value: String(format: "%+.0f", entry.delta),
                    valueColor: entry.delta >= 0 ? Token.Color.good : Token.Color.bad
                )

                if entry.hadSignal {
                    VStack(spacing: 0) {
                        ForEach(entry.contributions) { contribution in
                            ReceiptRow(reason: contribution.reason, value: contribution.value)
                            if contribution.id != entry.contributions.last?.id {
                                Rectangle()
                                    .fill(Token.Color.line)
                                    .frame(height: 1)
                            }
                        }
                    }

                    if entry.wasClamped {
                        HStack(spacing: 6) {
                            Text("Capped.")
                                .font(.system(size: 12, weight: .semibold))
                            Text("The day added up to \(String(format: "%+.0f", entry.rawDelta)); no single day may move more than 20 points down or 15 up.")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(Token.Color.inkDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                    }

                    HStack {
                        Text("\(Int(entry.healthBefore.rounded()))")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                        Text("\(Int(entry.healthAfter.rounded()))")
                    }
                    .font(.mushData(16))
                    .foregroundStyle(Token.Color.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                } else {
                    Text("No signal that day, so nothing moved. A day we could not measure is never scored as a good one.")
                        .font(.system(size: 13))
                        .foregroundStyle(Token.Color.inkDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
            }
        }
    }

    /// The ladder, drawn.
    ///
    /// It used to be a coloured dot and a word per row, and the creature — the entire
    /// product — appeared nowhere on the screen named after it. The drawn gallery existed
    /// but was reachable only through the launch argument CI uses, so no user could ever
    /// have seen it.
    ///
    /// Each row now draws its own stage at 96x72, which is above the level-of-detail line
    /// so the folds are there: fold density is what separates rot from healing, and a
    /// thumbnail without them shows five identical lumps in five colours.
    private var stages: some View {
        Panel {
            VStack(spacing: 10) {
                InstrumentLabel(title: "Stages", value: model.stage.title)

                ForEach(BrainStage.allCases.reversed(), id: \.self) { stage in
                    HStack(spacing: 10) {
                        BlobView(stage: stage, isStatic: true)
                            .frame(width: 96, height: 72)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(stage.title)
                                .font(.system(size: 15, weight: stage == model.stage ? .bold : .regular))
                                .foregroundStyle(stage == model.stage ? Token.Color.ink : Token.Color.inkDim)
                            Text(stage.mood)
                                .font(.system(size: 11))
                                .foregroundStyle(Token.Color.inkDim.opacity(0.85))
                        }

                        Spacer(minLength: 8)

                        if stage == model.stage {
                            Pill(text: "Now", tint: stage.tint, filled: true)
                        } else {
                            Text("\(Int(stage.lowerBound))+")
                                .font(.mushData(13))
                                .foregroundStyle(Token.Color.inkDim)
                        }
                    }
                    // The current stage is the one row that gets a surface of its own.
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(
                        stage == model.stage ? Token.Color.panelRaised : Color.clear,
                        in: RoundedRectangle(cornerRadius: Token.Radius.panel, style: .continuous)
                    )
                }
            }
        }
    }

    private var howItWorks: some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                InstrumentLabel(title: "The model")
                Text("Health starts at 70 and changes once a day. Staying under budget is worth up to +10; going twice over costs 25. Focus sessions add, overrides subtract, and a streak compounds slowly.")
                    .font(.system(size: 13))
                    .foregroundStyle(Token.Color.inkDim)
                Text("It falls faster than it climbs — five bad days to the floor, seven good ones back to the top. Nothing here is hidden or learned; the same inputs always produce the same number.")
                    .font(.system(size: 13))
                    .foregroundStyle(Token.Color.inkDim)
            }
        }
    }
}
