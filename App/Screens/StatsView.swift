import SwiftUI
import MushKit

/// Statistics, split by provenance.
///
/// The two planes never merge (docs/03-ARCHITECTURE.md section 2). Everything on this
/// screen is from **our** ledger and is fully derivable. Apple's figures render inside
/// the report extension, are marked with a provenance chip, and cannot be computed on.
struct StatsView: View {
    @Environment(AppModel.self) private var model

    private var visible: [DayRecord] { Array(model.history.suffix(14)) }
    private var maxMinutes: Int {
        max(visible.map(\.distractingMinutes).max() ?? 60, 60)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                trend
                counters
                appleplane
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Token.Color.ground)
    }

    private var trend: some View {
        Panel {
            VStack(spacing: 16) {
                InstrumentLabel(
                    title: "Last 14 days",
                    value: model.improvement.map { String(format: "%+.0f%%", $0 * 100) } ?? "—",
                    valueColor: (model.improvement ?? 0) <= 0 ? Token.Color.good : Token.Color.warn
                )

                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(visible) { day in
                        DayBar(day: day, maxMinutes: maxMinutes)
                    }
                }
                .frame(height: 110)

                HStack(spacing: 14) {
                    legend(Token.Color.good, "under budget")
                    legend(Token.Color.bad, "over")
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(Token.Color.inkDim, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                            .frame(width: 10, height: 10)
                        Text("no signal")
                            .font(.system(size: 11))
                            .foregroundStyle(Token.Color.inkDim)
                    }
                    Spacer()
                }
            }
        }
    }

    private func legend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label).font(.system(size: 11)).foregroundStyle(Token.Color.inkDim)
        }
    }

    private var counters: some View {
        Panel {
            VStack(spacing: 12) {
                InstrumentLabel(title: "Our ledger")
                row("Interventions shown", model.totals.shields)
                row("Overrides taken", model.totals.overrides)
                row("Focus sessions", model.totals.focusSessions)
                row("Focus minutes", model.totals.focusMinutes)
                row("Days measured", model.totals.measuredDays)
                row("Days we could not see", model.totals.blindDays)
            }
        }
    }

    private func row(_ title: String, _ value: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(Token.Color.ink)
            Spacer()
            Text("\(value)")
                .font(.mushData())
                .foregroundStyle(Token.Color.inkDim)
        }
    }

    private var appleplane: some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    InstrumentLabel(title: "Total screen time")
                    ProvenanceChip()
                }
                Text("iOS reports total and per-app screen time inside a sealed view. We can show you those numbers but we cannot read them — so they never feed brain health.")
                    .font(.system(size: 13))
                    .foregroundStyle(Token.Color.inkDim)
                if model.isMocked {
                    Text("Unavailable in the Simulator.")
                        .font(.system(size: 12))
                        .foregroundStyle(Token.Color.warn)
                }
            }
        }
    }
}

private struct DayBar: View {
    let day: DayRecord
    let maxMinutes: Int

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let fraction = Double(day.distractingMinutes) / Double(maxMinutes)
                VStack {
                    Spacer(minLength: 0)
                    if day.hasSignal {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(day.isGreen ? Token.Color.good : Token.Color.bad)
                            .frame(height: max(3, geo.size.height * fraction))
                    } else {
                        // A blind day is drawn hollow. It is never drawn as zero.
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(
                                Token.Color.inkDim.opacity(0.7),
                                style: StrokeStyle(lineWidth: 1, dash: [2, 2])
                            )
                            .frame(height: geo.size.height * 0.25)
                    }
                }
            }
            Text(day.date.formatted(.dateTime.day()))
                .font(.system(size: 9))
                .foregroundStyle(Token.Color.inkDim)
        }
    }
}
