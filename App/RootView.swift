import SwiftUI
import MushKit

/// PHASE 1 DIAGNOSTIC UI — intentionally plain.
///
/// This exists to prove the domain works end to end and to give CI something to
/// screenshot. It is not the product's design. The real interface is Phase 7, and it
/// starts from an aesthetic direction committed to `brand/brand.json`, not from here.
/// Do not polish this file; replace it.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                if model.isMocked {
                    Section {
                        Label(
                            "Running on synthetic data. Family Controls cannot work in the "
                            + "Simulator, so nothing here came from real usage.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.footnote)
                    }
                }

                stateSection
                todaySection
                receiptSection
                historySection

                if let error = model.loadError {
                    Section("Error") {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Mush")
            .refreshable { await model.refresh() }
        }
    }

    private var stateSection: some View {
        Section("Brain") {
            LabeledContent("Health", value: String(format: "%.1f", model.health))
            LabeledContent("Stage", value: "\(model.stage.title) — \(model.stage.mood)")
            LabeledContent("Streak", value: "\(model.streak) day\(model.streak == 1 ? "" : "s")")
            LabeledContent("Screen Time access", value: model.authorization.rawValue)
            if model.authorization != .approved {
                Button("Request access") {
                    Task { await model.requestAuthorization() }
                }
            }
        }
    }

    @ViewBuilder
    private var todaySection: some View {
        Section("Today") {
            if let today = model.today, today.hasSignal {
                LabeledContent("Distracting", value: "\(today.distractingMinutes) min")
                LabeledContent("Budget", value: "\(today.budgetMinutes) min")
                LabeledContent(
                    "Provisional",
                    value: String(format: "%+.1f", model.provisionalDelta)
                )
            } else {
                // A day with no signal must read as "we could not see", never as zero.
                Text("No signal yet today.")
                    .foregroundStyle(.secondary)
            }
            if let improvement = model.improvement {
                LabeledContent(
                    "vs. previous week",
                    value: String(format: "%+.0f%%", improvement * 100)
                )
            }
        }
    }

    @ViewBuilder
    private var receiptSection: some View {
        if let entry = model.lastEntry {
            Section("Why it moved, last committed day") {
                ForEach(entry.contributions) { contribution in
                    LabeledContent(
                        contribution.reason,
                        value: String(format: "%+.1f", contribution.value)
                    )
                }
                LabeledContent("Total", value: String(format: "%+.1f", entry.delta))
                    .fontWeight(.semibold)
                if entry.wasClamped {
                    Text("Clamped from \(String(format: "%+.1f", entry.rawDelta)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var historySection: some View {
        Section("Ledger") {
            ForEach(model.history.reversed()) { day in
                HStack {
                    Text(day.date, format: .dateTime.month(.abbreviated).day())
                        .frame(width: 60, alignment: .leading)
                    if day.hasSignal {
                        Text("\(day.distractingMinutes) min")
                        Spacer()
                        Text(day.isGreen ? "green" : "red")
                            .foregroundStyle(day.isGreen ? .green : .red)
                    } else {
                        Text("no signal")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .font(.callout.monospacedDigit())
            }
        }
    }
}
