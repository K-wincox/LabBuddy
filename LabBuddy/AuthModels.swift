import Foundation

struct AuthUser: Codable, Equatable {
    var id: String
    var email: String
    var emailVerified: Bool
    var displayName: String
    var labName: String
}

struct AuthResponse: Codable {
    var user: AuthUser
    var accessToken: String
    var refreshToken: String
    var expiresIn: Int
}

struct AccessTokenResponse: Codable {
    var accessToken: String
    var expiresIn: Int
}

struct AuthStatusResponse: Codable {
    var status: String
}

struct AuthMeResponse: Codable {
    var user: AuthUser
}

struct AuthErrorResponse: Codable {
    var error: String
}

enum AuthError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(String)
    case transport(String)
    case missingToken

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "服务器地址无效"
        case .invalidResponse:
            return "服务器响应无法解析"
        case .server(let message):
            return AuthError.userFacingMessage(for: message)
        case .transport(let message):
            return message
        case .missingToken:
            return "登录状态已失效，请重新登录"
        }
    }

    private static func userFacingMessage(for code: String) -> String {
        switch code {
        case "invalid_email": return "邮箱格式不正确"
        case "password_too_short": return "密码至少需要 8 位"
        case "email_already_registered": return "这个邮箱已经注册，请直接登录"
        case "send_code_failed": return "验证码发送失败，请稍后重试"
        case "invalid_request": return "请求内容不完整"
        case "code_not_found": return "请先获取验证码"
        case "code_expired": return "验证码已过期，请重新获取"
        case "invalid_code": return "验证码不正确"
        case "too_many_attempts": return "验证码尝试次数过多，请重新获取"
        case "invalid_credentials": return "邮箱或密码不正确"
        case "email_not_verified": return "邮箱还未完成验证"
        case "email_not_registered": return "这个邮箱还没有注册"
        default: return code
        }
    }
}
