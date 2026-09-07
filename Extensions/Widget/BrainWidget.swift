import SwiftUI
import WidgetKit
import MushKit

/// The creature on the Home Screen.
///
/// Brainrot's best idea, and the one thing in the category that actually changes
/// behaviour: the score is the first thing you see when you pick the phone up, before
/// you have opened anything. It costs no Family Controls entitlement, so it works on
/// Path B too (docs/09-PATH-B-NO-ENTITLEMENT.md).
struct BrainEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct BrainProvider: TimelineProvider {
    private let store = WidgetSnapshotStore()

    func placeholder(in context: Context) -> BrainEntry {
        BrainEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (BrainEntry) -> Void) {
        completion(BrainEntry(date: Date(), snapshot: store.read()))
    }

    /// Several entries, all from the same snapshot.
    ///
    /// The data does not change without a reload, so the later entries exist only to
    /// re-render the "as of HH:MM" label as the figure ages. `reloadAllTimelines()` from
    /// the monitor extension is budgeted and can be deferred, so a widget that assumed
    /// it was always current would quietly display a stale number as a live one.
    func getTimeline(in context: Context, completion: @escaping (Timeline<BrainEntry>) -> Void) {
        let snapshot = store.read()
        let now = Date()
        let entries = stride(from: 0, through: 60, by: 15).map { minutes in
            BrainEntry(
                date: Calendar.current.date(byAdding: .minute, value: minutes, to: now) ?? now,
                snapshot: snapshot
            )
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Views

private struct BudgetBar: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Token.Color.line)
                if snapshot.hasSignal, let ratio = snapshot.budgetRatio {
                    Capsule()
                        .fill(snapshot.stage.tint)
                        .frame(width: proxy.size.width * min(1, ratio))
                }
            }
        }
        .frame(height: 4)
    }
}

private struct TodayLine: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if snapshot.hasSignal {
            Text(
                "\(snapshot.distractingMinutes)\(snapshot.isPartial ? "+" : "") / \(snapshot.budgetMinutes) min"
            )
            .font(.mushData(11))
            .foregroundStyle(Token.Color.inkDim)
        } else {
            // A day the monitor never woke is not a zero (docs/08-DECISIONS.md D8).
            Text("no reading")
                .font(.mushData(11))
                .foregroundStyle(Token.Color.inkDim)
        }
    }
}

private struct SmallBrain: View {
    let entry: BrainEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            BlobView(stage: entry.snapshot.stage, isStatic: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(entry.snapshot.health.rounded()))")
                    .font(.mushDisplay(30))
                    .foregroundStyle(Token.Color.ink)
                Text(entry.snapshot.stage.title.uppercased())
                    .font(.mushData(9))
                    .tracking(1.2)
                    .foregroundStyle(entry.snapshot.stage.tint)
            }
            TodayLine(snapshot: entry.snapshot)
        }
    }
}

private struct MediumBrain: View {
    let entry: BrainEntry

    var body: some View {
        HStack(spacing: 14) {
            BlobView(stage: entry.snapshot.stage, isStatic: true)
                .frame(width: 84, height: 84)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(Int(entry.snapshot.health.rounded()))")
                        .font(.mushDisplay(40))
                        .foregroundStyle(Token.Color.ink)
                    Text(entry.snapshot.stage.title.uppercased())
                        .font(.mushData(10))
                        .tracking(1.4)
                        .foregroundStyle(entry.snapshot.stage.tint)
                    Spacer()
                }
                BudgetBar(snapshot: entry.snapshot)
                HStack {
                    TodayLine(snapshot: entry.snapshot)
                    Spacer()
                    if entry.snapshot.streak > 0 {
                        Text("\(entry.snapshot.streak) day streak")
                            .font(.mushData(11))
                            .foregroundStyle(Token.Color.inkDim)
                    }
                }
                if let freshness = entry.snapshot.freshness(at: entry.date) {
                    Text(freshness)
                        .font(.mushData(9))
                        .foregroundStyle(Token.Color.inkDim)
                }
            }
        }
    }
}

struct BrainWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BrainEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumBrain(entry: entry)
        case .accessoryCircular:
            Gauge(value: min(1, entry.snapshot.budgetRatio ?? 0)) {
                Text("MUSH")
            } currentValueLabel: {
                Text("\(Int(entry.snapshot.health.rounded()))")
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.snapshot.stage.title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                Text("\(Int(entry.snapshot.health.rounded())) · \(entry.snapshot.minutesLeft) min left")
                    .font(.system(size: 13))
            }
        default:
            SmallBrain(entry: entry)
        }
    }
}

struct BrainWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MushBrainWidget", provider: BrainProvider()) { entry in
            BrainWidgetView(entry: entry)
                .containerBackground(Token.Color.ground, for: .widget)
        }
        .configurationDisplayName("Brain")
        .description("Today's condition, before you open anything.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}
