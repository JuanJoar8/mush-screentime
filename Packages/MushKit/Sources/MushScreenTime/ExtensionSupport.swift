#if os(iOS)
import Foundation
import ManagedSettings
import MushKit

/// Shared by the monitor and shield-action extensions.
///
/// Kept synchronous and actor-free on purpose: extensions are woken cold and measured in
/// milliseconds, so they must not pay for an actor hop or an async runtime.

// MARK: - Applying blocks

public enum BlockApplier {
    public static func apply(storeName: String) {
        let selection = SelectionStore().load()
        guard !selection.applicationTokens.isEmpty
                || !selection.categoryTokens.isEmpty
                || !selection.webDomainTokens.isEmpty else { return }

        let store = ManagedSettingsStore(named: .init(storeName))
        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
    }

    /// Clears the entire named store rather than nilling individual properties. Tokens
    /// left behind in a store are the reported cause of stale shield UI (FB14237883).
    public static func clear(storeName: String) {
        ManagedSettingsStore(named: .init(storeName)).clearAllSettings()
    }

    /// Removes one application from a store's shield, for a temporary-access grant.
    public static func unshield(token: ApplicationToken, storeName: String) {
        let store = ManagedSettingsStore(named: .init(storeName))
        var current = store.shield.applications ?? []
        current.remove(token)
        store.shield.applications = current.isEmpty ? nil : current
    }
}

// MARK: - Small App Group stores

/// Hot, tiny state read on a cold extension wake, where opening and decoding the JSON
/// ledger would be wasteful.

public struct BudgetStore: Sendable {
    private let key = "mush.budgetMinutes"
    private var defaults: UserDefaults? { UserDefaults(suiteName: MushIdentifiers.appGroup) }

    public init() {}

    public var budgetMinutes: Int {
        get { defaults?.object(forKey: key) as? Int ?? 60 }
        nonmutating set { defaults?.set(newValue, forKey: key) }
    }
}

public struct StrictnessStore: Sendable {
    private let key = "mush.strictness"
    private var defaults: UserDefaults? { UserDefaults(suiteName: MushIdentifiers.appGroup) }

    public init() {}

    public var strictness: Strictness {
        get {
            guard let raw = defaults?.string(forKey: key) else { return .standard }
            return Strictness(rawValue: raw) ?? .standard
        }
        nonmutating set { defaults?.set(newValue.rawValue, forKey: key) }
    }
}

/// Maps a `DeviceActivityName` back to the store it should shield, so the monitor
/// extension can act without loading the ledger.
public struct WindowPlanStore: Sendable {
    public struct Plan: Codable, Sendable {
        public var storeName: String
        public var windowID: UUID
        public init(storeName: String, windowID: UUID) {
            self.storeName = storeName
            self.windowID = windowID
        }
    }

    private let key = "mush.windowPlans"
    private var defaults: UserDefaults? { UserDefaults(suiteName: MushIdentifiers.appGroup) }

    public init() {}

    private func map() -> [String: Plan] {
        guard let data = defaults?.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Plan].self, from: data)
        else { return [:] }
        return decoded
    }

    public func plan(forActivity activity: String) -> Plan? { map()[activity] }

    public func register(_ plan: Plan, forActivity activity: String) {
        var current = map()
        current[activity] = plan
        if let data = try? JSONEncoder().encode(current) { defaults?.set(data, forKey: key) }
    }

    public func unregister(activity: String) {
        var current = map()
        current[activity] = nil
        if let data = try? JSONEncoder().encode(current) { defaults?.set(data, forKey: key) }
    }
}

/// Active temporary-access grants: written by the shield-action extension, cleared by
/// the monitor extension when the usage threshold expires them.
public struct GrantStore: Sendable {
    private let key = "mush.grants"
    private var defaults: UserDefaults? { UserDefaults(suiteName: MushIdentifiers.appGroup) }

    public init() {}

    public func all() -> [Grant] {
        guard let data = defaults?.data(forKey: key),
              let grants = try? JSONDecoder.mushShared.decode([Grant].self, from: data)
        else { return [] }
        return grants
    }

    public func add(_ grant: Grant) {
        var grants = all().filter { $0.storeName != grant.storeName }
        grants.append(grant)
        write(grants)
    }

    public func clear(storeName: String) {
        write(all().filter { $0.storeName != storeName })
    }

    private func write(_ grants: [Grant]) {
        if let data = try? JSONEncoder.mushShared.encode(grants) { defaults?.set(data, forKey: key) }
    }
}

// MARK: - Event names

/// Grant-expiry events, distinguished from ladder rungs by prefix. The extension is
/// woken cold with nothing but the event name, so the name has to carry the meaning.
public enum GrantEventName {
    private static let prefix = "mush.grant."
    public static func encode(storeName: String) -> String { "\(prefix)\(storeName)" }
    public static func decode(_ name: String) -> String? {
        guard name.hasPrefix(prefix) else { return nil }
        return String(name.dropFirst(prefix.count))
    }
}

extension JSONEncoder {
    static var mushShared: JSONEncoder {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }
}

extension JSONDecoder {
    static var mushShared: JSONDecoder {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }
}
#endif
