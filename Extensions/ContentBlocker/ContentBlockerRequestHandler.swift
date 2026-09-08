import Foundation

/// Feed Quarantine, layer 3 — the same rules, in Safari (`docs/05-SHORTS-REELS.md`).
///
/// Clean Feed removes Reels and Shorts inside our own web view. This removes them
/// everywhere the person browses in Safari, which is where most browsing actually
/// happens. It is the second-cheapest of the four layers: no entitlement, no Family
/// Controls, and — unlike a full Safari Web Extension — no JavaScript at all.
///
/// **A content blocker is a JSON file and a function that hands it over.** That is the
/// entire extension. The interesting work already happened in `FeedRuleSet`, and
/// `blockerList.json` is that rule set serialised: `safariRulesMatchTheApp` fails the
/// build if the two ever drift, because two copies of a rule list is how Safari ends up
/// blocking last month's Instagram.
///
/// The system reads this once when the extension is enabled and again on
/// `SFContentBlockerManager.reloadContentBlocker`. It does not run continuously and it
/// cannot see what the user browses — a content blocker is a set of rules handed to
/// WebKit, not a program watching traffic. That is worth saying in the UI when this ships.
final class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {
    enum Failure: Error {
        /// The bundle has no rule list, which means the resource build phase dropped it.
        /// Safari's own failure message for this is silence, so name it here.
        case missingRuleList
    }

    func beginRequest(with context: NSExtensionContext) {
        guard
            let url = Bundle.main.url(forResource: "blockerList", withExtension: "json"),
            let attachment = NSItemProvider(contentsOf: url)
        else {
            context.cancelRequest(withError: Failure.missingRuleList)
            return
        }

        let item = NSExtensionItem()
        item.attachments = [attachment]
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }
}
