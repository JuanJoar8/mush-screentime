import SwiftUI
import WebKit
import MushKit

/// Clean Feed — layer 2 of Feed Quarantine (`docs/05-SHORTS-REELS.md`).
///
/// Instagram and YouTube in our own `WKWebView`, with a compiled `WKContentRuleList` that
/// removes the short-form surfaces. DMs, subscriptions, search, profiles and posting all
/// work; Reels and Shorts are not reachable. It is the only one of the four layers that
/// needs no entitlement, which makes it the only one that can run on this phone today.
///
/// **If the rules do not compile, nothing loads.** That is the whole design of this
/// screen. A Clean Feed that fails open is Instagram with extra steps, and it would fail
/// open silently — the page would render perfectly and the user would believe the product
/// was working. So the failure is a dead end with the error printed on it.
@Observable
@MainActor
final class CleanFeedModel {
    enum Compilation {
        case compiling
        case ready(WKContentRuleList)
        case failed(String)
    }

    private(set) var compilation: Compilation = .compiling
    var site: Site = .instagram

    enum Site: String, CaseIterable, Identifiable {
        case instagram, youtube
        var id: String { rawValue }
        var title: String { self == .instagram ? "Instagram" : "YouTube" }
        var url: URL {
            switch self {
            case .instagram: URL(string: "https://www.instagram.com/")!
            case .youtube: URL(string: "https://m.youtube.com/feed/subscriptions")!
            }
        }
    }

    func compile() {
        guard case .compiling = compilation else { return }
        guard let store = WKContentRuleListStore.default() else {
            compilation = .failed("This device has no content-rule store.")
            return
        }

        let json: String
        do {
            json = try FeedRuleSet.json()
        } catch {
            compilation = .failed("The rule list could not be encoded.")
            return
        }

        // Compile every launch rather than looking up a cached list. Compilation of ten
        // rules is cheap, and a cache lookup that silently returns a stale list is the
        // exact failure mode `FeedRuleSet.identifier` is versioned to avoid — belt and
        // braces, because a stale rule list looks identical to a working one.
        store.compileContentRuleList(
            forIdentifier: FeedRuleSet.identifier,
            encodedContentRuleList: json
        ) { list, error in
            MainActor.assumeIsolated {
                if let list {
                    self.compilation = .ready(list)
                } else {
                    self.compilation = .failed(
                        error?.localizedDescription ?? "The rules would not compile."
                    )
                }
            }
        }
    }
}

struct CleanFeedView: View {
    @State private var model = CleanFeedModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header

            switch model.compilation {
            case .compiling:
                placeholder("Compiling the rules…", detail: nil)
            case .failed(let reason):
                placeholder(
                    "Clean Feed is not available",
                    detail: """
                    The content rules did not compile, so nothing was loaded. \
                    Opening the site without them would be the ordinary app with an \
                    extra step, which is not what this screen is for.

                    \(reason)
                    """
                )
            case .ready(let rules):
                CleanFeedWebView(url: model.site.url, rules: rules)
                    .id(model.site)
            }
        }
        .background(Token.Color.ground)
        .onAppear { model.compile() }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Text("CLEAN FEED")
                    .font(.mushLabel())
                    .tracking(1.4)
                    .foregroundStyle(Token.Color.inkDim)
                Spacer()
                Button("Done") { dismiss() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Token.Color.ink)
            }

            HStack(spacing: 8) {
                ForEach(CleanFeedModel.Site.allCases) { site in
                    Button {
                        model.site = site
                    } label: {
                        Pill(
                            text: site.title,
                            tint: Token.Color.accent,
                            filled: site == model.site
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text("Reels and Shorts removed")
                    .font(.system(size: 11))
                    .foregroundStyle(Token.Color.inkDim)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Token.Color.panel)
    }

    private func placeholder(_ title: String, detail: String?) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Token.Color.ink)
            if let detail {
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Token.Color.inkDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The web view itself.
private struct CleanFeedWebView: UIViewRepresentable {
    let url: URL
    let rules: WKContentRuleList

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(rules)
        configuration.userContentController.addUserScript(Self.navigationGuard)
        // Persistent, deliberately. A non-persistent store would be tidier, and it would
        // also make the user sign in to Instagram every single time they opened this — at
        // which point they would stop opening it and go back to the app with the Reels in
        // it. The clean route has to be the path of least resistance or it is not a route.
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Refuses any navigation off the two sites Clean Feed has rules for.
    ///
    /// An in-app browser that will load anything is a general browser with no content
    /// rules — worse than no in-app browser, because it looks like one.
    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let target = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(FeedRuleSet.isSupported(target) ? .allow : .cancel)
        }
    }

    /// Closes the hole the content rules cannot reach.
    ///
    /// A `block` rule fires on a document navigation. Instagram and YouTube are
    /// single-page apps: tapping Reels pushes a history entry and swaps the view without
    /// ever loading a document, so the rule never sees it. This wraps `pushState` and
    /// `replaceState` and steps back out of a short-form path when one appears.
    ///
    /// It deliberately does **not** run on first load. A guard that fires on the entry
    /// URL can bounce against an empty history, and a redirect loop inside a web view is
    /// far worse than a reel getting through — the content rule catches that case anyway,
    /// because entering by URL *is* a document navigation.
    static let navigationGuard = WKUserScript(
        source: """
        (function () {
          var SHORT_FORM = /^\\/(reels|reel\\/|shorts)/;
          function stepBack() {
            if (SHORT_FORM.test(location.pathname) && history.length > 1) {
              history.back();
            }
          }
          ['pushState', 'replaceState'].forEach(function (name) {
            var original = history[name];
            history[name] = function () {
              var result = original.apply(this, arguments);
              stepBack();
              return result;
            };
          });
          window.addEventListener('popstate', stepBack);
        })();
        """,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
    )
}
