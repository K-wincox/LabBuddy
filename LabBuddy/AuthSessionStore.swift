import Foundation

@MainActor
final class AuthSessionStore: ObservableObject {
    @Published private(set) var user: AuthUser?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service: AuthService
    private let accessAccount = "accessToken"
    private let refreshAccount = "refreshToken"
    private let userDefaultsKey = "authUser"

    var isAuthenticated: Bool { user != nil }

    init(service: AuthService = .shared) {
        self.service = service
        restoreCachedUser()
    }

    func bootstrap() {
        Task { await loadCurrentUser() }
    }

    func registerStart(email: String, password: String) async -> Bool {
        await perform {
            try await service.registerStart(email: email, password: password)
        }
    }

    func registerVerify(email: String, code: String) async -> Bool {
        await perform {
            let response = try await service.registerVerify(email: email, code: code)
            try save(response)
        }
    }

    func loginPassword(email: String, password: String) async -> Bool {
        await perform {
            let response: AuthResponse
            if let localResponse = LocalTestAccount.response(identifier: email, password: password) {
                LocalTestAccount.prepareWorkspace(for: localResponse.user)
                response = localResponse
            } else {
                response = try await service.loginPassword(email: email, password: password)
            }
            try save(response)
        }
    }

    func loginCodeStart(email: String) async -> Bool {
        await perform {
            try await service.loginCodeStart(email: email)
        }
    }

    func loginCodeVerify(email: String, code: String) async -> Bool {
        await perform {
            let response = try await service.loginCodeVerify(email: email, code: code)
            try save(response)
        }
    }

    func loadCurrentUser() async {
        guard !isLoading else { return }
        guard let access = try? KeychainStore.read(account: accessAccount) else { return }
        if LocalTestAccount.isLocalAccessToken(access) {
            restoreCachedUser()
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await service.me(accessToken: access)
            user = response.user
            cache(user: response.user)
        } catch {
            await refreshAndLoad()
        }
    }

    func signOut() {
        let refresh = try? KeychainStore.read(account: refreshAccount)
        KeychainStore.delete(account: accessAccount)
        KeychainStore.delete(account: refreshAccount)
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        user = nil
        guard refresh.map({ !LocalTestAccount.isLocalRefreshToken($0) }) ?? false else { return }
        Task { await service.logout(refreshToken: refresh) }
    }

    private func refreshAndLoad() async {
        guard let refresh = try? KeychainStore.read(account: refreshAccount) else {
            signOut()
            return
        }
        guard !LocalTestAccount.isLocalRefreshToken(refresh) else {
            restoreCachedUser()
            return
        }
        do {
            let response = try await service.refresh(refreshToken: refresh)
            try KeychainStore.save(response.accessToken, account: accessAccount)
            let me = try await service.me(accessToken: response.accessToken)
            user = me.user
            cache(user: me.user)
        } catch {
            signOut()
        }
    }

    private func perform(_ operation: () async throws -> Void) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await operation()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func save(_ response: AuthResponse) throws {
        try KeychainStore.save(response.accessToken, account: accessAccount)
        try KeychainStore.save(response.refreshToken, account: refreshAccount)
        user = response.user
        cache(user: response.user)
    }

    private func restoreCachedUser() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let cached = try? JSONDecoder().decode(AuthUser.self, from: data) else { return }
        user = cached
    }

    private func cache(user: AuthUser) {
        guard let data = try? JSONEncoder().encode(user) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}

private enum LocalTestAccount {
    private static let password = "123456"
    private static let kwkIdentifier = "kwk"
    private static let rootIdentifier = "root"
    private static let accessPrefix = "local-test-access:"
    private static let refreshPrefix = "local-test-refresh:"
    private static let rootEmail = "root@labbuddy.local"
    private static let demoSeedPrefix = "demoSeeded.\(SampleData.demoUserEmail)"

    static func response(identifier: String, password: String) -> AuthResponse? {
        guard password == Self.password else { return nil }

        switch normalized(identifier) {
        case kwkIdentifier:
            return makeResponse(
                user: AuthUser(
                    id: "local-test-kwk",
                    email: SampleData.demoUserEmail,
                    emailVerified: true,
                    displayName: "KWK 测试账号",
                    labName: "个人工作区"
                )
            )
        case rootIdentifier:
            return makeResponse(
                user: AuthUser(
                    id: "local-test-root",
                    email: rootEmail,
                    emailVerified: true,
                    displayName: "root",
                    labName: "个人工作区"
                )
            )
        default:
            return nil
        }
    }

    static func prepareWorkspace(for user: AuthUser) {
        if user.email.lowercased() == SampleData.demoUserEmail {
            removeDemoSeedFlags()
        } else if user.email.lowercased() == rootEmail {
            resetRootWorkspace()
        }
    }

    static func isLocalAccessToken(_ token: String) -> Bool {
        token.hasPrefix(accessPrefix)
    }

    static func isLocalRefreshToken(_ token: String) -> Bool {
        token.hasPrefix(refreshPrefix)
    }

    private static func makeResponse(user: AuthUser) -> AuthResponse {
        AuthResponse(
            user: user,
            accessToken: "\(accessPrefix)\(user.id)",
            refreshToken: "\(refreshPrefix)\(user.id)",
            expiresIn: 31_536_000
        )
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func resetRootWorkspace() {
        let defaults = UserDefaults.standard
        [
            "importedLabRuns",
            "tomorrowLabRuns",
            "pastExperimentDays",
            "inventoryItems",
            "userProjects",
            "savedProtocols",
            "customBufferTemplates",
            "calculationHistory",
            "savedCustomFormulas",
            "inventoryTransactions",
            "completedStepIDs",
            "activeLabTimers",
            "lastLabBuddyOpenDate",
            "profileDisplayName",
            "profileLabName",
            "profileAvatarData",
            "isProUser",
            "customWorkflowAreas",
            "eventColorPaletteHexes",
            "eventColorAssignments",
            "protocolFavoriteIDs",
            "protocolRecentIDs"
        ].forEach(defaults.removeObject)
        removeDemoSeedFlags()
    }

    private static func removeDemoSeedFlags() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(demoSeedPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}
