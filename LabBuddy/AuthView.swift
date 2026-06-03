import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authStore: AuthSessionStore
    @Environment(\.dismiss) private var dismiss
    var isGate = false
    @State private var mode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var waitingForRegisterCode = false
    @State private var waitingForLoginCode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.teal.opacity(0.14))
                            Image(systemName: "flask.fill")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(.teal)
                        }
                        .frame(width: 64, height: 64)

                        Text("LabBuddy")
                            .font(.largeTitle.weight(.bold))
                        Text("登录后进入你的实验台。Protocol、今日排程、计时器和本地记录会保持在这台设备上。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 28)

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
                .padding(14)
                .background(Color.labPanel, in: RoundedRectangle(cornerRadius: 8))

                if let message = authStore.errorMessage {
                    Text(message)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                    Text("开发测试 API：\(AuthService.shared.baseURL.absoluteString)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
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
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(.regularMaterial)
            }
            .background(Color.labBackground.ignoresSafeArea())
            .navigationTitle(isGate ? "" : "LabBuddy 账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isGate {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") { dismiss() }
                    }
                }
            }
            .onChange(of: authStore.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated && !isGate { dismiss() }
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
        .opacity(authStore.isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
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
