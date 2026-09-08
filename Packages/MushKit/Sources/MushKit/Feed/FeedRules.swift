import Foundation

/// Content rules for Clean Feed — layer 2 of Feed Quarantine (`docs/05-SHORTS-REELS.md`).
///
/// Instagram and YouTube in a `WKWebView` with the short-form surfaces genuinely absent:
/// DMs, subscriptions, search, profiles and posting all still work, Reels and Shorts do
/// not exist. It is the one layer of the four that needs no entitlement, so it is the one
/// that can ship today.
///
/// **The rules live here, in the domain package, because they are the fragile part.**
/// `docs/05-SHORTS-REELS.md` section 5 says it plainly: these selectors depend on someone
/// else's markup and will break when that markup changes. Permanently. A thing that is
/// expected to break should be the thing that is tested, and it cannot be tested from
/// inside a view.
///
/// **What a test here can and cannot prove.** WebKit's `url-filter` accepts a documented
/// *subset* of regular expressions. `NSRegularExpression` is a superset of it, so the
/// matching tests prove the patterns mean what we intend; they do not prove WebKit will
/// compile them. `usesOnlyWebKitRegexSubset` covers the second half by rejecting the
/// constructs WebKit does not implement. Neither substitutes for compiling the list on a
/// device, which is open question Q10.
public struct FeedRule: Sendable, Equatable {
    public enum Action: Sendable, Equatable {
        /// Refuse the navigation outright. Used only on top-level documents.
        case block
        /// Leave the page loading but hide the element. Used for shelves and tabs that
        /// live inside a page we want to keep.
        case hide(selector: String)
    }

    /// WebKit `url-filter`: a regex, matched against the whole URL.
    public let urlFilter: String
    public let action: Action
    /// Why this rule exists, in one line. Never serialised — WebKit would reject the key
    /// — but it is the difference between a maintainable rule list and forty regexes.
    public let note: String

    public init(urlFilter: String, action: Action, note: String) {
        self.urlFilter = urlFilter
        self.action = action
        self.note = note
    }

    /// The `WKContentRuleList` JSON object for this rule.
    public var jsonObject: [String: Any] {
        var trigger: [String: Any] = ["url-filter": urlFilter]
        var actionObject: [String: Any]

        switch action {
        case .block:
            // Top-level documents only. Without this a blocked pattern also kills the
            // XHR the app makes to the same path, and Instagram's own navigation breaks
            // in ways that look like our bug rather than our rule.
            trigger["resource-type"] = ["document"]
            actionObject = ["type": "block"]
        case .hide(let selector):
            actionObject = ["type": "css-display-none", "selector": selector]
        }

        return ["trigger": trigger, "action": actionObject]
    }
}

/// The rule list, versioned.
///
/// `version` is bumped whenever a rule changes. It ships in the compiled list's identifier
/// so a stale compiled list is replaced rather than reused — WebKit caches by identifier,
/// and a cache hit on last month's rules is exactly the failure this project cannot
/// tolerate quietly.
public enum FeedRuleSet {
    public static let version = 1
    public static var identifier: String { "mush-clean-feed-v\(version)" }

    // MARK: Instagram

    public static let instagram: [FeedRule] = [
        FeedRule(
            urlFilter: "^https?://[^/]*instagram\\.com/reels",
            action: .block,
            note: "The Reels tab and every reel permalink under it."
        ),
        FeedRule(
            urlFilter: "^https?://[^/]*instagram\\.com/reel/",
            action: .block,
            note: "A single reel, which is a different path from the tab."
        ),
        // Explore is the discovery grid *and* the parent of search. Blocking the whole
        // subtree would take search with it, and the promise of Clean Feed is real
        // Instagram minus the short-form surface — not Instagram minus half its
        // navigation. So this matches the bare page and its query string, nothing deeper.
        FeedRule(
            urlFilter: "^https?://[^/]*instagram\\.com/explore/?(\\?.*)?$",
            action: .block,
            note: "The Explore grid itself. /explore/search/... stays reachable."
        ),
        FeedRule(
            urlFilter: ".*",
            action: .hide(selector: "a[href^=\"/reels\"], a[href*=\"/reels/\"]"),
            note: "The Reels entry in the tab bar and any inline link to it."
        ),
        FeedRule(
            urlFilter: ".*",
            action: .hide(selector: "a[href^=\"/explore\"]"),
            note: "The Explore entry in the tab bar."
        )
    ]

    // MARK: YouTube

    public static let youtube: [FeedRule] = [
        FeedRule(
            urlFilter: "^https?://[^/]*youtube\\.com/shorts",
            action: .block,
            note: "Every Shorts permalink and the Shorts surface."
        ),
        FeedRule(
            urlFilter: ".*",
            action: .hide(selector: "a[href^=\"/shorts\"], a[href*=\"/shorts/\"]"),
            note: "Links into Shorts from anywhere: the shelf, the sidebar, end cards."
        ),
        FeedRule(
            urlFilter: ".*",
            action: .hide(selector: "ytd-reel-shelf-renderer, ytm-reel-shelf-renderer"),
            note: "The Shorts shelf on desktop and mobile web."
        ),
        FeedRule(
            urlFilter: ".*",
            action: .hide(selector: "ytd-rich-section-renderer:has(a[href^=\"/shorts\"])"),
            note: "The home-feed row that wraps the shelf, so it leaves no empty band."
        )
    ]

    public static var all: [FeedRule] { instagram + youtube }

    /// The compiled-list source. Throws only if `JSONSerialization` refuses, which would
    /// mean a rule was built with something that is not JSON.
    public static func json(_ rules: [FeedRule] = all) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: rules.map(\.jsonObject))
        guard let text = String(data: data, encoding: .utf8) else {
            throw FeedRuleError.notUTF8
        }
        return text
    }

    /// Sites Clean Feed knows how to serve. Anything else opens in Safari: an in-app
    /// browser that quietly becomes a general one is a browser with no content rules.
    public static let supportedHosts = ["instagram.com", "youtube.com", "m.youtube.com"]

    public static func isSupported(_ url: URL) -> Bool {
        guard let host = url.host()?.lowercased() else { return false }
        return supportedHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}

public enum FeedRuleError: Error, Equatable {
    case notUTF8
}

// MARK: - Matching, for tests

public extension FeedRule {
    /// Whether this rule's `url-filter` matches a URL.
    ///
    /// `NSRegularExpression`, not WebKit. See the note on `FeedRule`: this proves intent,
    /// not compilability.
    func matches(_ url: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: urlFilter) else { return false }
        let range = NSRange(url.startIndex..<url.endIndex, in: url)
        return regex.firstMatch(in: url, range: range) != nil
    }

    /// Constructs WebKit's `url-filter` does not implement. A pattern using one of these
    /// compiles under `NSRegularExpression` — so the matching tests would pass — and then
    /// fails to compile in the browser, where nothing would be filtered at all.
    static let unsupportedRegexConstructs = [
        "(?=", "(?!", "(?<=", "(?<!",   // look-around
        "\\1", "\\2", "\\3",            // back-references
        "{",                            // bounded repetition
        "\\b"                           // word boundary
    ]

    var usesOnlyWebKitRegexSubset: Bool {
        !Self.unsupportedRegexConstructs.contains { urlFilter.contains($0) }
    }
}

public extension FeedRuleSet {
    /// Whether any `block` rule would refuse this URL.
    static func blocks(_ url: String, in rules: [FeedRule] = all) -> Bool {
        rules.contains { $0.action == .block && $0.matches(url) }
    }
}
