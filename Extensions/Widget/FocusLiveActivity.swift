import ActivityKit
import SwiftUI
import WidgetKit
import MushKit

/// The focus session on the Lock Screen and in the Dynamic Island.
///
/// Every countdown here is `Text(timerInterval:)`, which the system ticks on its own.
/// Nothing in this file asks to be updated, because nothing can update it once the app
/// leaves the foreground — see `Shared/FocusActivityAttributes.swift` for why that is a
/// framework constraint rather than a shortcut.
struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Token.Color.groundDeep)
                .activitySystemActionForegroundColor(Token.Color.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    BlobView(stage: context.state.stage, isStatic: true)
                        .frame(width: 44, height: 44)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context, size: 30)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(subtitle(context))
                        .font(.mushData(12))
                        .foregroundStyle(Token.Color.inkDim)
                }
            } compactLeading: {
                BlobView(stage: context.state.stage, isStatic: true)
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                countdown(context, size: 13)
            } minimal: {
                BlobView(stage: context.state.stage, isStatic: true)
            }
            .keylineTint(context.state.stage.tint)
        }
    }

    private func lockScreen(
        _ context: ActivityViewContext<FocusActivityAttributes>
    ) -> some View {
        HStack(spacing: 14) {
            BlobView(stage: context.state.stage, isStatic: true)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.title.uppercased())
                    .font(.mushLabel())
                    .tracking(1.4)
                    .foregroundStyle(context.state.stage.tint)
                countdown(context, size: 34)
                Text(subtitle(context))
                    .font(.mushData(12))
                    .foregroundStyle(Token.Color.inkDim)
            }
            Spacer()
        }
        .padding(16)
    }

    @ViewBuilder
    private func countdown(
        _ context: ActivityViewContext<FocusActivityAttributes>,
        size: CGFloat
    ) -> some View {
        if context.state.endedEarly {
            Text("ended")
                .font(.mushData(size))
                .foregroundStyle(Token.Color.inkDim)
        } else {
            // System-driven. No update is sent for each tick, and none is needed.
            //
            // The range is clamped because `ClosedRange` traps when its lower bound is
            // above its upper one — and a session whose end date has passed while the
            // app had no chance to close the activity is the *expected* case here, not
            // an edge case. An unclamped range would crash the Lock Screen exactly then.
            Text(timerInterval: Date()...max(context.state.endsAt, Date()), countsDown: true)
                .font(.mushDisplay(size))
                .monospacedDigit()
                .foregroundStyle(Token.Color.ink)
        }
    }

    private func subtitle(_ context: ActivityViewContext<FocusActivityAttributes>) -> String {
        context.state.endedEarly
            ? "Ended early. It counts as abandoned."
            : "\(context.attributes.plannedMinutes) min · blocks lift when it ends"
    }
}
