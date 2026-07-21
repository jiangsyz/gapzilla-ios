import SwiftUI
import UIKit

enum AppPhase: Equatable {
    case launching
    case signedOut
    case signedIn
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }
}

@MainActor
final class AppStore: ObservableObject {
    @Published var phase: AppPhase = .launching
    @Published var user: User?
    @Published var goals: [Goal] = []
    @Published var selectedGoalID: String?
    @Published var events: [GoalEvent] = []
    @Published var isBusy = false
    @Published var errorMessage: String?
    @Published var appleAccountChoice: AppleAccountChoice?
    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Keys.language) }
    }

    private let api: APIClient
    private var accessToken: String?
    private var refreshToken: String?

    private enum Keys {
        static let accessToken = "access_token"
        static let refreshToken = "refresh_token"
        static let selectedGoal = "selected_goal_id"
        static let language = "language"
    }

    init(api: APIClient = .app) {
        self.api = api
        accessToken = KeychainStore.read(account: Keys.accessToken)
        refreshToken = KeychainStore.read(account: Keys.refreshToken)
        selectedGoalID = UserDefaults.standard.string(forKey: Keys.selectedGoal)
        if let stored = UserDefaults.standard.string(forKey: Keys.language),
           let value = AppLanguage(rawValue: stored) {
            language = value
        } else {
            language = Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .chinese : .english
        }
#if DEBUG
        applyDebugPreviewIfNeeded()
#endif
    }

    var selectedGoal: Goal? {
        goals.first(where: { $0.id == selectedGoalID })
    }

    var metrics: GoalMetrics { GoalMetrics(events: events, today: Date()) }
    var isChinese: Bool { language == .chinese }

    func text(_ chinese: String, _ english: String) -> String {
        isChinese ? chinese : english
    }

    func bootstrap() async {
        guard phase == .launching else { return }
        if let accessToken {
            await api.setAccessToken(accessToken)
        }
        guard refreshToken != nil else {
            phase = .signedOut
            return
        }

        do {
            try await refreshSession()
            try await loadAccountAndContent()
            phase = .signedIn
        } catch {
            clearSession()
            phase = .signedOut
        }
    }

    func login(username: String, password: String) async -> Bool {
        await authenticate {
            try await api.post(
                "/api/v1/auth/login",
                body: LoginPayload(
                    username: username,
                    password: password,
                    device: DevicePayload(deviceName: UIDevice.current.model)
                )
            )
        }
    }

    func register(username: String, password: String, nickname: String) async -> Bool {
        await authenticate {
            try await api.post(
                "/api/v1/auth/register",
                body: RegisterPayload(
                    username: username,
                    password: password,
                    nickname: nickname,
                    device: DevicePayload(deviceName: UIDevice.current.model)
                )
            )
        }
    }

    func loginWithApple(credential: AppleCredential) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let data: AppleLoginData = try await api.post(
                "/api/v1/auth/apple/login",
                body: AppleLoginPayload(
                    credential: credential,
                    device: DevicePayload(deviceName: UIDevice.current.model)
                )
            )
            switch data.status {
            case .authenticated:
                try await finishAuthentication(AuthData(user: data.user, tokens: data.tokens))
            case .accountChoiceRequired:
                appleAccountChoice = AppleAccountChoice(
                    pendingToken: data.pendingToken,
                    suggestedNickname: data.suggestedNickname,
                    credential: credential
                )
            }
        } catch {
            handle(error)
        }
    }

    func beginAppleLoginCompletion() {
        errorMessage = nil
        isBusy = true
    }

    func linkAppleToExistingAccount(
        choice: AppleAccountChoice,
        username: String,
        password: String
    ) async -> Bool {
        await completeAppleAccountChoice {
            try await api.post(
                "/api/v1/auth/apple/link-existing",
                body: AppleLinkExistingPayload(
                    pendingToken: choice.pendingToken,
                    credential: choice.credential,
                    username: username,
                    password: password,
                    device: DevicePayload(deviceName: UIDevice.current.model)
                )
            )
        }
    }

    func createAppleAccount(choice: AppleAccountChoice, nickname: String) async -> Bool {
        await completeAppleAccountChoice {
            try await api.post(
                "/api/v1/auth/apple/create-account",
                body: AppleCreateAccountPayload(
                    pendingToken: choice.pendingToken,
                    credential: choice.credential,
                    nickname: nickname,
                    device: DevicePayload(deviceName: UIDevice.current.model)
                )
            )
        }
    }

    func bindApple(credential: AppleCredential) async -> Bool {
        await performMutation {
            let data: UserData = try await authenticated {
                try await api.post(
                    "/api/v1/users/me/auth-identities/apple",
                    body: AppleBindPayload(credential: credential)
                )
            }
            user = data.user
        }
    }

    func cancelAppleAccountChoice() {
        appleAccountChoice = nil
    }

    func reportAppleAuthorizationFailure(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    func logout() async {
        if let refreshToken {
            let _: LogoutData? = try? await api.post(
                "/api/v1/auth/logout",
                body: RefreshPayload(refreshToken: refreshToken)
            )
        }
        appleAccountChoice = nil
        clearSession()
        phase = .signedOut
    }

    func deleteAccount(credential: AppleCredential?) async -> Bool {
        await performMutation {
            let data: DeleteAccountData = try await authenticated {
                try await api.delete(
                    "/api/v1/users/me",
                    body: DeleteAccountPayload(credential: credential)
                )
            }
            guard data.deleted else {
                throw APIClientError.invalidResponse
            }
            appleAccountChoice = nil
            clearSession()
            phase = .signedOut
        }
    }

    func refreshAll() async {
        guard phase == .signedIn else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await loadGoals()
            try await loadEvents()
        } catch {
            handle(error)
        }
    }

    func selectGoal(_ id: String) async {
        guard id != selectedGoalID else { return }
        selectedGoalID = id
        UserDefaults.standard.set(id, forKey: Keys.selectedGoal)
        events = []
        await refreshAll()
    }

    func createGoal(name: String) async -> Bool {
        await performMutation {
            let data: GoalData = try await authenticated {
                try await api.post("/api/v1/goals", body: NamePayload(name: name))
            }
            goals.append(data.goal)
            await selectGoal(data.goal.id)
        }
    }

    func renameGoal(_ goal: Goal, name: String) async -> Bool {
        await performMutation {
            let data: GoalData = try await authenticated {
                try await api.patch("/api/v1/goals/\(goal.id)", body: NamePayload(name: name))
            }
            if let index = goals.firstIndex(where: { $0.id == goal.id }) {
                goals[index] = data.goal
            }
        }
    }

    func deleteGoal(_ goal: Goal) async -> Bool {
        await performMutation {
            let _: DeletedGoalData = try await authenticated {
                try await api.delete("/api/v1/goals/\(goal.id)")
            }
            goals.removeAll { $0.id == goal.id }
            if selectedGoalID == goal.id {
                selectedGoalID = goals.first?.id
                UserDefaults.standard.set(selectedGoalID, forKey: Keys.selectedGoal)
                try await loadEvents()
            }
        }
    }

    func record(kind: EventKind, date: Date, note: String) async -> Bool {
        guard let selectedGoalID else { return false }
        return await performMutation {
            let payload = EventPayload(
                eventType: kind.rawValue,
                occurredOn: AppDate.api.string(from: date),
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            let _: EventData = try await authenticated {
                try await api.post("/api/v1/goals/\(selectedGoalID)/events", body: payload)
            }
            try await loadEvents()
        }
    }

    private func authenticate(operation: () async throws -> AuthData) async -> Bool {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let auth = try await operation()
            try await finishAuthentication(auth)
            return true
        } catch {
            handle(error)
            return false
        }
    }

    private func completeAppleAccountChoice(operation: () async throws -> AuthData) async -> Bool {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let auth = try await operation()
            try await finishAuthentication(auth)
            appleAccountChoice = nil
            return true
        } catch {
            handle(error)
            return false
        }
    }

    private func finishAuthentication(_ auth: AuthData) async throws {
        user = auth.user
        await store(tokens: auth.tokens)
        try await loadGoals()
        try await loadEvents()
        phase = .signedIn
    }

    private func performMutation(operation: () async throws -> Void) async -> Bool {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await operation()
            return true
        } catch {
            handle(error)
            return false
        }
    }

    private func loadAccountAndContent() async throws {
        let me: UserData = try await authenticated { try await api.get("/api/v1/users/me") }
        user = me.user
        try await loadGoals()
        try await loadEvents()
    }

    private func loadGoals() async throws {
        let data: GoalsData = try await authenticated { try await api.get("/api/v1/goals") }
        goals = data.goals
        if let selectedGoalID, goals.contains(where: { $0.id == selectedGoalID }) {
            return
        }
        selectedGoalID = goals.first?.id
        UserDefaults.standard.set(selectedGoalID, forKey: Keys.selectedGoal)
    }

    private func loadEvents() async throws {
        guard let selectedGoalID else {
            events = []
            return
        }
        var page = 1
        var allEvents: [GoalEvent] = []
        while true {
            let data: EventsData = try await authenticated {
                try await api.get(
                    "/api/v1/goals/\(selectedGoalID)/events",
                    query: [
                        URLQueryItem(name: "page", value: String(page)),
                        URLQueryItem(name: "page_size", value: "500")
                    ]
                )
            }
            allEvents.append(contentsOf: data.events)
            guard data.pagination.hasMore else { break }
            page += 1
        }
        events = allEvents.sorted {
            if $0.date == $1.date { return $0.id > $1.id }
            return $0.date > $1.date
        }
    }

    private func authenticated<Value>(_ operation: () async throws -> Value) async throws -> Value {
        do {
            return try await operation()
        } catch APIClientError.unauthorized {
            try await refreshSession()
            return try await operation()
        }
    }

    private func refreshSession() async throws {
        guard let refreshToken else { throw APIClientError.unauthorized }
        let data: TokensData = try await api.post(
            "/api/v1/auth/refresh",
            body: RefreshPayload(refreshToken: refreshToken)
        )
        await store(tokens: data.tokens)
    }

    private func store(tokens: Tokens) async {
        accessToken = tokens.accessToken
        refreshToken = tokens.refreshToken
        KeychainStore.save(tokens.accessToken, account: Keys.accessToken)
        KeychainStore.save(tokens.refreshToken, account: Keys.refreshToken)
        await api.setAccessToken(tokens.accessToken)
    }

    private func clearSession() {
        accessToken = nil
        refreshToken = nil
        user = nil
        goals = []
        events = []
        selectedGoalID = nil
        KeychainStore.delete(account: Keys.accessToken)
        KeychainStore.delete(account: Keys.refreshToken)
        UserDefaults.standard.removeObject(forKey: Keys.selectedGoal)
        Task { await api.setAccessToken(nil) }
    }

    private func handle(_ error: Error) {
        if case APIClientError.unauthorized = error {
            clearSession()
            phase = .signedOut
        }
        errorMessage = error.localizedDescription
    }
}

#if DEBUG
private extension AppStore {
    func applyDebugPreviewIfNeeded() {
        if ProcessInfo.processInfo.arguments.contains("--ui-preview-apple-loading") {
            phase = .signedOut
            isBusy = true
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-preview-apple-choice") {
            phase = .signedOut
            appleAccountChoice = AppleAccountChoice(
                pendingToken: "preview-pending-token",
                suggestedNickname: "Apple User",
                credential: AppleCredential(
                    identityToken: "preview-identity-token",
                    authorizationCode: "preview-authorization-code",
                    nonce: "preview-nonce",
                    fullName: "Apple User"
                )
            )
            return
        }
        guard ProcessInfo.processInfo.arguments.contains("--ui-preview-signed-in") else { return }

        let now = Date()
        let calendar = Calendar.current
        func event(_ id: String, _ daysAgo: Int, _ kind: EventKind, _ note: String) -> GoalEvent {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            return GoalEvent(
                id: id,
                goalId: "preview-goal",
                eventType: kind.rawValue,
                occurredOn: AppDate.api.string(from: date),
                note: note,
                createdAt: ""
            )
        }

        user = User(
            id: "preview-user",
            userNo: "u_preview",
            username: "preview",
            nickname: "示例用户",
            avatarUrl: ""
        )
        goals = [
            Goal(
                id: "preview-goal",
                name: "减少深夜刷短视频",
                sortOrder: 10,
                createdAt: "",
                updatedAt: ""
            ),
            Goal(
                id: "preview-goal-2",
                name: "减少无意识零食",
                sortOrder: 20,
                createdAt: "",
                updatedAt: ""
            )
        ]
        selectedGoalID = "preview-goal"
        events = [
            event("event-1", 1, .urge, "停下来走了十分钟。"),
            event("event-2", 5, .urge, "冲动出现，但没有继续。"),
            event("event-3", 23, .slip, "雨天有些烦躁，但我只记录发生的事实。"),
            event("event-4", 28, .urge, "把注意力转移到了阅读。"),
            event("event-5", 45, .slip, "这次间隔已经明显变长。"),
            event("event-6", 50, .urge, "出现一次冲动。"),
            event("event-7", 63, .slip, "没有预想中的难受。"),
            event("event-8", 76, .slip, "晚饭后的惯性动作。"),
            event("event-9", 84, .slip, "开始认真记录。")
        ]
        phase = .signedIn
    }
}
#endif
