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

    private var stages: some View {
        Panel {
            VStack(spacing: 14) {
                InstrumentLabel(title: "Stages", value: model.stage.title)
                ForEach(BrainStage.allCases.reversed(), id: \.self) { stage in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(stage.tint)
                            .frame(width: 12, height: 12)
                        Text(stage.title)
                            .font(.system(size: 15, weight: stage == model.stage ? .semibold : .regular))
                            .foregroundStyle(stage == model.stage ? Token.Color.ink : Token.Color.inkDim)
                        Spacer()
                        Text("\(Int(stage.lowerBound))+")
                            .font(.mushData(13))
                            .foregroundStyle(Token.Color.inkDim)
                    }
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
