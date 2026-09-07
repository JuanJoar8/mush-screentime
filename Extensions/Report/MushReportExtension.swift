import DeviceActivity
import SwiftUI

/// Apple's ground-truth Screen Time figures.
///
/// This extension is deliberately sandboxed by Apple: it cannot make network requests,
/// and **nothing it computes can be passed back to the app** — not through App Groups,
/// not through shared files, not through CFPreferences. Apple DTS confirmed this is
/// intentional (docs/01-FEASIBILITY.md section 3).
///
/// So it links no shared code and holds no logic worth sharing. It renders, and that is
/// all. Every number here is display-only; brain health is computed elsewhere, from our
/// own ledger.
@main
struct MushReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { total in
            TotalActivityView(summary: total)
        }
        AppBreakdownReport { rows in
            AppBreakdownView(rows: rows)
        }
    }
}

// MARK: - Total

extension DeviceActivityReport.Context {
    static let totalActivity = Self("Total Activity")
    static let appBreakdown = Self("App Breakdown")
}

struct ActivitySummary {
    var totalDuration: TimeInterval = 0
    // Pickups and notification counts are reachable through DeviceActivityData, but the
    // exact property names are unverified until this compiles against the real SDK.
    // Left out rather than guessed — see the housekeeping rule in docs/00-STATUS.md.
}

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (ActivitySummary) -> TotalActivityView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> ActivitySummary {
        var summary = ActivitySummary()
        for await result in data {
            for await segment in result.activitySegments {
                summary.totalDuration += segment.totalActivityDuration
            }
        }
        return summary
    }
}

struct TotalActivityView: View {
    let summary: ActivitySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(format(summary.totalDuration))
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text("Total screen time, reported by iOS")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func format(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}

// MARK: - Per-app breakdown

struct AppRow: Identifiable {
    var id: String
    var name: String
    var duration: TimeInterval
}

struct AppBreakdownReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .appBreakdown
    let content: ([AppRow]) -> AppBreakdownView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> [AppRow] {
        var totals: [String: (name: String, duration: TimeInterval)] = [:]
        for await result in data {
            for await segment in result.activitySegments {
                for await category in segment.categories {
                    for await app in category.applications {
                        let key = app.application.bundleIdentifier ?? UUID().uuidString
                        let name = app.application.localizedDisplayName ?? "Unknown"
                        totals[key, default: (name, 0)].duration += app.totalActivityDuration
                    }
                }
            }
        }
        return totals
            .map { AppRow(id: $0.key, name: $0.value.name, duration: $0.value.duration) }
            .sorted { $0.duration > $1.duration }
    }
}

struct AppBreakdownView: View {
    let rows: [AppRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(rows.prefix(8)) { row in
                HStack {
                    Text(row.name).font(.subheadline)
                    Spacer()
                    Text(format(row.duration))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            if rows.isEmpty {
                Text("No activity reported for this period.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func format(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
