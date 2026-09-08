import Foundation
import Testing
@testable import MushKit

// Clean Feed's rules — layer 2 of Feed Quarantine (docs/05-SHORTS-REELS.md).
//
// Both directions matter, and the second one matters more. A rule list that blocks Reels
// is easy; a rule list that blocks Reels *and* leaves DMs, search, subscriptions and
// posting working is the whole product. A regex that quietly takes half of Instagram with
// it would look, from inside the app, exactly like Instagram being broken — and the user
// would blame Instagram, not us.

@Test("Every short-form surface is refused")
func feedRulesBlockShortForm() {
    let blocked = [
        "https://www.instagram.com/reels/",
        "https://m.instagram.com/reels/audio/12345/",
        "https://www.instagram.com/reel/CxYz123/",
        "https://instagram.com/explore/",
        "https://www.instagram.com/explore",
        "https://www.instagram.com/explore?next=1",
        "https://www.youtube.com/shorts/dQw4w9WgXcQ",
        "https://m.youtube.com/shorts/abc"
    ]
    for url in blocked {
        #expect(FeedRuleSet.blocks(url), "should be refused: \(url)")
    }
}

@Test("Everything a person actually goes there for still loads")
func feedRulesLeaveTheRestAlone() {
    let allowed = [
        // Instagram: messages, a post, a profile, the home feed, posting, and search —
        // which lives *under* /explore, and is why the explore rule is anchored to the
        // bare path instead of the subtree.
        "https://www.instagram.com/direct/inbox/",
        "https://www.instagram.com/p/CxYz123/",
        "https://www.instagram.com/someuser/",
        "https://www.instagram.com/",
        "https://www.instagram.com/create/style/",
        "https://www.instagram.com/explore/search/keyword/?q=coffee",
        "https://www.instagram.com/explore/tags/coffee/",
        // YouTube: a video, subscriptions, a channel, search, the watch-later list.
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        "https://www.youtube.com/feed/subscriptions",
        "https://www.youtube.com/@someone",
        "https://www.youtube.com/results?search_query=coffee",
        "https://m.youtube.com/playlist?list=WL"
    ]
    for url in allowed {
        #expect(!FeedRuleSet.blocks(url), "should still load: \(url)")
    }
}

@Test("A reel-shaped path on another host is not our business")
func feedRulesAreHostScoped() {
    // The url-filter is anchored to the two domains. Without that anchor, "/reels" would
    // match any site with that word in a path.
    #expect(!FeedRuleSet.blocks("https://example.com/reels/"))
    #expect(!FeedRuleSet.blocks("https://news.site/shorts/story"))
    // And a lookalike domain does not get our rules applied by accident either way.
    #expect(!FeedRuleSet.blocks("https://not-instagram.example/reels/"))
}

@Test("Blocking applies to navigations, not to every subresource")
func blockRulesAreDocumentScoped() {
    // Without `resource-type: ["document"]` the same pattern also kills the XHR the page
    // makes to that path, and the site breaks in ways that look like our bug.
    for rule in FeedRuleSet.all where rule.action == .block {
        let trigger = rule.jsonObject["trigger"] as? [String: Any]
        let types = trigger?["resource-type"] as? [String]
        #expect(types == ["document"], "\(rule.urlFilter) is not document-scoped")
    }
}

@Test("Patterns stay inside the regex subset WebKit implements")
func feedRulesUseWebKitRegexOnly() {
    // NSRegularExpression is a superset of WebKit's url-filter grammar, so the matching
    // tests above would pass on a pattern the browser then refuses to compile — and a
    // rule list that fails to compile filters nothing at all, silently.
    for rule in FeedRuleSet.all {
        #expect(
            rule.usesOnlyWebKitRegexSubset,
            "\(rule.urlFilter) uses a construct WebKit does not implement"
        )
        #expect(
            (try? NSRegularExpression(pattern: rule.urlFilter)) != nil,
            "\(rule.urlFilter) is not a valid regular expression"
        )
    }
}

@Test("The rule list serialises to the shape WKContentRuleList expects")
func feedRulesSerialise() throws {
    let text = try FeedRuleSet.json()
    let parsed = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [[String: Any]]
    let rules = try #require(parsed)
    #expect(rules.count == FeedRuleSet.all.count)

    for rule in rules {
        let trigger = try #require(rule["trigger"] as? [String: Any])
        let action = try #require(rule["action"] as? [String: Any])
        #expect(trigger["url-filter"] is String)

        let type = try #require(action["type"] as? String)
        #expect(["block", "css-display-none"].contains(type))
        if type == "css-display-none" {
            let selector = try #require(action["selector"] as? String)
            #expect(!selector.isEmpty)
        }
        // `note` is documentation for us. WebKit rejects a rule object carrying keys it
        // does not know, so it must never reach the JSON.
        #expect(rule["note"] == nil)
        #expect(trigger["note"] == nil)
    }
}

@Test("Clean Feed opens only the two sites it has rules for")
func cleanFeedRefusesUnknownHosts() {
    // An in-app browser that will load anything is a general browser with no content
    // rules, which is worse than no in-app browser.
    #expect(FeedRuleSet.isSupported(URL(string: "https://www.instagram.com/")!))
    #expect(FeedRuleSet.isSupported(URL(string: "https://m.youtube.com/feed/subscriptions")!))
    #expect(FeedRuleSet.isSupported(URL(string: "https://youtube.com")!))
    #expect(!FeedRuleSet.isSupported(URL(string: "https://tiktok.com/")!))
    #expect(!FeedRuleSet.isSupported(URL(string: "https://example.com/")!))
    // A host that merely ends in the same letters is not the same host.
    #expect(!FeedRuleSet.isSupported(URL(string: "https://notinstagram.com/")!))
}

@Test("The compiled list identifier carries the version")
func feedRuleIdentifierIsVersioned() {
    // WebKit caches a compiled list by identifier. Without the version in it, editing a
    // rule and shipping the update would keep serving last month's rules from the cache.
    #expect(FeedRuleSet.identifier.contains("\(FeedRuleSet.version)"))
}

@Test("Deep links back into the native apps are hidden, not just refused")
func feedRulesHideAppDeepLinks() {
    // The logged-out Instagram page leads with an "Open Instagram" button. Tapping it
    // would leave Clean Feed for the app with the Reels in it, which is the single most
    // counterproductive control that could appear on this screen. The navigation delegate
    // refuses the tap; this makes sure the button is not there to tap.
    let selectors = FeedRuleSet.leaveTheWeb.compactMap { rule -> String? in
        if case .hide(let selector) = rule.action { return selector }
        return nil
    }
    let joined = selectors.joined()
    for scheme in ["instagram:", "youtube:", "intent:"] {
        #expect(joined.contains(scheme), "no rule hides \(scheme) links")
    }
    // Scheme-matched, not class-matched: it depends on what the link does rather than on
    // what the markup calls it, which is the only kind of selector here that will not rot.
    #expect(!joined.contains("class"))
}
