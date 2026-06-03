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
            let response = try await service.loginPassword(email: email, password: password)
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
        Task { await service.logout(refreshToken: refresh) }
    }

    private func refreshAndLoad() async {
        guard let refresh = try? KeychainStore.read(account: refreshAccount) else {
            signOut()
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
