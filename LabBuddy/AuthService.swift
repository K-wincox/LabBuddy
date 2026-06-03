import Foundation
import UIKit

final class AuthService {
    static let shared = AuthService()

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    var baseURL: URL {
        let raw = UserDefaults.standard.string(forKey: "authAPIBaseURL") ?? "http://172.16.14.27:18088"
        return URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)) ?? URL(string: "http://172.16.14.27:18088")!
    }

    func registerStart(email: String, password: String) async throws {
        let _: AuthStatusResponse = try await request(
            path: "/api/v1/auth/register/start",
            method: "POST",
            body: ["email": email, "password": password]
        )
    }

    func registerVerify(email: String, code: String) async throws -> AuthResponse {
        try await request(
            path: "/api/v1/auth/register/verify",
            method: "POST",
            body: ["email": email, "code": code, "deviceName": UIDeviceInfo.name, "deviceId": UIDeviceInfo.id]
        )
    }

    func loginPassword(email: String, password: String) async throws -> AuthResponse {
        try await request(
            path: "/api/v1/auth/login/password",
            method: "POST",
            body: ["email": email, "password": password, "deviceName": UIDeviceInfo.name, "deviceId": UIDeviceInfo.id]
        )
    }

    func loginCodeStart(email: String) async throws {
        let _: AuthStatusResponse = try await request(
            path: "/api/v1/auth/login/code/start",
            method: "POST",
            body: ["email": email]
        )
    }

    func loginCodeVerify(email: String, code: String) async throws -> AuthResponse {
        try await request(
            path: "/api/v1/auth/login/code/verify",
            method: "POST",
            body: ["email": email, "code": code, "deviceName": UIDeviceInfo.name, "deviceId": UIDeviceInfo.id]
        )
    }

    func refresh(refreshToken: String) async throws -> AccessTokenResponse {
        try await request(
            path: "/api/v1/auth/refresh",
            method: "POST",
            body: ["refreshToken": refreshToken]
        )
    }

    func logout(refreshToken: String?) async {
        guard let refreshToken else { return }
        let _: AuthStatusResponse? = try? await request(
            path: "/api/v1/auth/logout",
            method: "POST",
            body: ["refreshToken": refreshToken]
        )
    }

    func me(accessToken: String) async throws -> AuthMeResponse {
        try await request(path: "/api/v1/me", method: "GET", accessToken: accessToken)
    }

    private func request<T: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body? = Optional<Data>.none,
        accessToken: String? = nil
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw AuthError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try encoder.encode(body)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
            if (200..<300).contains(http.statusCode) {
                return try decoder.decode(T.self, from: data)
            }
            if let error = try? decoder.decode(AuthErrorResponse.self, from: data) {
                throw AuthError.server(error.error)
            }
            throw AuthError.invalidResponse
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.transport(error.localizedDescription)
        }
    }
}

private enum UIDeviceInfo {
    static var name: String {
        #if os(iOS)
        return UIDevice.current.name
        #else
        return "LabBuddy"
        #endif
    }

    static var id: String {
        let key = "authDeviceID"
        if let value = UserDefaults.standard.string(forKey: key) { return value }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: key)
        return value
    }
}
