import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authStore: AuthSessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var mode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var waitingForRegisterCode = false
    @State private var waitingForLoginCode = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Picker("模式", selection: $mode) {
                    ForEach(AuthMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 12) {
                    TextField("QQ 邮箱 / 邮箱", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    if mode != .codeLogin {
                        SecureField("密码（至少 8 位）", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }

                    if waitingForRegisterCode || waitingForLoginCode {
                        TextField("6 位验证码", text: $code)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                if let message = authStore.errorMessage {
                    Text(message)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 10) {
                    primaryButton
                    if mode == .login {
                        Button("使用邮箱验证码登录") {
                            mode = .codeLogin
                            waitingForLoginCode = false
                            code = ""
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.teal)
                    }
                }

                Spacer()
            }
            .padding(18)
            .navigationTitle("LabBuddy 账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onChange(of: authStore.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated { dismiss() }
            }
            .onChange(of: mode) { _, _ in
                waitingForRegisterCode = false
                waitingForLoginCode = false
                code = ""
            }
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if authStore.isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text(buttonTitle)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.teal)
        .disabled(authStore.isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var buttonTitle: String {
        switch mode {
        case .login:
            return "登录"
        case .register:
            return waitingForRegisterCode ? "完成注册" : "获取注册验证码"
        case .codeLogin:
            return waitingForLoginCode ? "验证码登录" : "获取登录验证码"
        }
    }

    private func submit() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        switch mode {
        case .login:
            _ = await authStore.loginPassword(email: trimmedEmail, password: password)
        case .register:
            if waitingForRegisterCode {
                _ = await authStore.registerVerify(email: trimmedEmail, code: code)
            } else if await authStore.registerStart(email: trimmedEmail, password: password) {
                waitingForRegisterCode = true
            }
        case .codeLogin:
            if waitingForLoginCode {
                _ = await authStore.loginCodeVerify(email: trimmedEmail, code: code)
            } else if await authStore.loginCodeStart(email: trimmedEmail) {
                waitingForLoginCode = true
            }
        }
    }
}

private enum AuthMode: String, CaseIterable, Identifiable {
    case login
    case register
    case codeLogin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .login: return "密码登录"
        case .register: return "注册"
        case .codeLogin: return "验证码"
        }
    }
}
