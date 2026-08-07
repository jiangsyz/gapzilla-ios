import Foundation

struct APIEnvelope<Value: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: Value
}

struct User: Codable, Equatable {
    let id: String
    let userNo: String
    let username: String
    let nickname: String
    let avatarUrl: String
    let loginProviders: [String]

    init(
        id: String,
        userNo: String,
        username: String,
        nickname: String,
        avatarUrl: String,
        loginProviders: [String] = []
    ) {
        self.id = id
        self.userNo = userNo
        self.username = username
        self.nickname = nickname
        self.avatarUrl = avatarUrl
        self.loginProviders = loginProviders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userNo = try container.decode(String.self, forKey: .userNo)
        username = try container.decode(String.self, forKey: .username)
        nickname = try container.decode(String.self, forKey: .nickname)
        avatarUrl = try container.decode(String.self, forKey: .avatarUrl)
        loginProviders = try container.decodeIfPresent([String].self, forKey: .loginProviders) ?? []
    }
}

struct Tokens: Codable, Equatable {
    let accessToken: String
    let tokenType: String
    let accessExpiresIn: Int
    let refreshToken: String
    let refreshExpiresIn: Int
    let sessionNo: String
}

struct AuthData: Decodable {
    let user: User
    let tokens: Tokens
}

enum AppleLoginStatus: String, Decodable {
    case authenticated
    case accountChoiceRequired = "account_choice_required"
}

struct AppleCredential: Codable, Equatable {
    let identityToken: String
    let authorizationCode: String
    let nonce: String
    let fullName: String
}

struct AppleLoginData: Decodable {
    let status: AppleLoginStatus
    let pendingToken: String
    let suggestedNickname: String
    let user: User
    let tokens: Tokens
}

struct AppleAccountChoice: Identifiable, Equatable {
    let id = UUID()
    let pendingToken: String
    let suggestedNickname: String
    let credential: AppleCredential
}

struct TokensData: Decodable {
    let tokens: Tokens
}

struct UserData: Decodable {
    let user: User
}

struct Goal: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    let sortOrder: Int
    let createdAt: String
    let updatedAt: String
}

struct GoalsData: Decodable {
    let goals: [Goal]
}

struct GoalData: Decodable {
    let goal: Goal
}

struct DeletedGoalData: Decodable {
    let deletedGoalId: String
    let deletedEventCount: Int
}

enum EventKind: Int, Codable, CaseIterable, Identifiable {
    case slip = 1
    // A raw observation that an urge occurred. This is not a "controlled" outcome.
    case urge = 2

    var id: Int { rawValue }
}

struct GoalEvent: Codable, Identifiable, Equatable {
    let id: String
    let goalId: String
    let eventType: Int
    let occurredOn: String
    let note: String
    let createdAt: String

    var kind: EventKind { EventKind(rawValue: eventType) ?? .slip }
    var date: Date { AppDate.api.date(from: occurredOn) ?? .distantPast }
}

struct EventsData: Decodable {
    let events: [GoalEvent]
    let pagination: Pagination
}

struct EventData: Decodable {
    let event: GoalEvent
}

struct LogoutData: Decodable {
    let sessionNo: String
    let revoked: Bool
}

struct Pagination: Decodable {
    let page: Int
    let pageSize: Int
    let total: Int
    let hasMore: Bool
}

struct EmptyData: Decodable {}

struct DevicePayload: Encodable {
    let deviceType = "ios"
    let deviceName: String
}

struct LoginPayload: Encodable {
    let username: String
    let password: String
    let device: DevicePayload
}

struct RegisterPayload: Encodable {
    let username: String
    let password: String
    let nickname: String
    let device: DevicePayload
}

struct AppleLoginPayload: Encodable {
    let credential: AppleCredential
    let device: DevicePayload
}

struct AppleLinkExistingPayload: Encodable {
    let pendingToken: String
    let credential: AppleCredential
    let username: String
    let password: String
    let device: DevicePayload
}

struct AppleCreateAccountPayload: Encodable {
    let pendingToken: String
    let credential: AppleCredential
    let nickname: String
    let device: DevicePayload
}

struct AppleBindPayload: Encodable {
    let credential: AppleCredential
}

struct DeleteAccountPayload: Encodable {
    let credential: AppleCredential?
}

struct DeleteAccountData: Decodable {
    let deleted: Bool
}

struct RefreshPayload: Encodable { let refreshToken: String }
struct NamePayload: Encodable { let name: String }
struct EventPayload: Encodable {
    let eventType: Int
    let occurredOn: String
    let note: String
}

enum AppDate {
    static let api: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func dayDistance(from start: Date, to end: Date) -> Int {
        let calendar = Calendar.current
        let lhs = calendar.startOfDay(for: start)
        let rhs = calendar.startOfDay(for: end)
        return max(0, calendar.dateComponents([.day], from: lhs, to: rhs).day ?? 0)
    }
}

struct GapPoint: Identifiable {
    let id: String
    let date: Date
    let days: Int
}

struct GoalMetrics {
    let events: [GoalEvent]
    let today: Date

    private var slipDates: Set<String> {
        Set(events.filter { $0.kind == .slip }.map(\.occurredOn))
    }

    private var slipsAscending: [GoalEvent] {
        events.filter { $0.kind == .slip }.sorted { $0.date < $1.date }
    }

    var controlledUrges: [GoalEvent] {
        let startOfToday = Calendar.current.startOfDay(for: today)
        return events.filter {
            $0.kind == .urge
                && $0.date < startOfToday
                && !slipDates.contains($0.occurredOn)
        }
    }

    var currentGap: Int {
        guard let latest = slipsAscending.last else { return 0 }
        return AppDate.dayDistance(from: latest.date, to: today)
    }

    var completedGaps: [Int] {
        zip(slipsAscending, slipsAscending.dropFirst()).map {
            AppDate.dayDistance(from: $0.0.date, to: $0.1.date)
        }
    }

    var bestGap: Int { ([currentGap] + completedGaps).max() ?? 0 }

    var averageGap: Int {
        guard !completedGaps.isEmpty else { return currentGap }
        return Int((Double(completedGaps.reduce(0, +)) / Double(completedGaps.count)).rounded())
    }

    var previousGap: Int? { completedGaps.last }

    var urgesLastSevenDays: Int {
        let end = Calendar.current.startOfDay(for: today)
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        return controlledUrges.filter { $0.date >= start && $0.date < end }.count
    }

    var trend: [GapPoint] {
        let completed = zip(slipsAscending, slipsAscending.dropFirst()).map { first, second in
            GapPoint(id: second.id, date: second.date, days: AppDate.dayDistance(from: first.date, to: second.date))
        }
        guard let latest = slipsAscending.last else { return completed }
        return completed + [GapPoint(id: "current-\(latest.id)", date: today, days: currentGap)]
    }

    func impactDays(for event: GoalEvent) -> Int? {
        guard event.kind == .slip,
              let index = slipsAscending.firstIndex(where: { $0.id == event.id }) else { return nil }
        if index == slipsAscending.count - 1 { return currentGap }
        return AppDate.dayDistance(from: event.date, to: slipsAscending[index + 1].date)
    }

    func dayKind(on date: Date) -> EventKind? {
        let occurredOn = AppDate.api.string(from: date)
        let eventsOnDay = events.filter { $0.occurredOn == occurredOn }
        if eventsOnDay.contains(where: { $0.kind == .slip }) { return .slip }
        if eventsOnDay.contains(where: { $0.kind == .urge }) { return .urge }
        return nil
    }
}
