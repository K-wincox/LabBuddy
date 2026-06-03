import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authStore: AuthSessionStore
    @Environment(\.dismiss) private var dismiss
    var isGate = false

    @State private var step: AuthStep = .login
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.labBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            brandBlock
                                .padding(.top, 44)

                            formBlock

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
                                .padding(.top, 4)
                        }
                        .padding(.horizontal, 28)
                    }

                    bottomActions
                }
            }
            .navigationTitle("")
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
        }
    }

    private var brandBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.teal.opacity(0.12))
                Image(systemName: "flask.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.teal)
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 8) {
                Text("LabBuddy")
                    .font(.system(size: 36, weight: .bold, design: .default))
                    .tracking(0)
                Text(step.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var formBlock: some View {
        VStack(spacing: 12) {
            TextField("邮箱", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.username)
                .authFieldStyle()

            if step.requiresPassword {
                SecureField("密码", text: $password)
                    .textContentType(step == .login ? .password : .newPassword)
                    .authFieldStyle()
            }

            if step == .registerCode {
                TextField("验证码", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .authFieldStyle()
            }
        }
    }

    private var bottomActions: some View {
        VStack(spacing: 14) {
            Button {
                Task { await submit() }
            } label: {
                HStack(spacing: 8) {
                    if authStore.isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(step.primaryTitle)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(canSubmit ? Color.teal : Color.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(canSubmit ? Color.white : Color.teal.opacity(0.65))
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || authStore.isLoading)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    secondaryAction()
                }
            } label: {
                Text(step.secondaryTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.teal)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(.regularMaterial)
    }

    private var canSubmit: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        switch step {
        case .login:
            return !trimmedEmail.isEmpty && !password.isEmpty
        case .registerForm:
            return !trimmedEmail.isEmpty && password.count >= 8
        case .registerCode:
            return !trimmedEmail.isEmpty && code.count == 6
        }
    }

    private func submit() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        switch step {
        case .login:
            _ = await authStore.loginPassword(email: trimmedEmail, password: password)
        case .registerForm:
            if await authStore.registerStart(email: trimmedEmail, password: password) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    code = ""
                    step = .registerCode
                }
            }
        case .registerCode:
            _ = await authStore.registerVerify(email: trimmedEmail, code: code)
        }
    }

    private func secondaryAction() {
        authStore.errorMessage = nil
        switch step {
        case .login:
            step = .registerForm
        case .registerForm, .registerCode:
            step = .login
            code = ""
        }
    }
}

private enum AuthStep {
    case login
    case registerForm
    case registerCode

    var subtitle: String {
        switch self {
        case .login:
            return "登录后进入你的实验台。今日排程、Protocol 与本地记录会保持在这台设备上。"
        case .registerForm:
            return "创建账号后可用于 Pro 权益、设备备份和后续同步。"
        case .registerCode:
            return "输入邮箱收到的 6 位验证码，完成注册。"
        }
    }

    var primaryTitle: String {
        switch self {
        case .login: return "登录"
        case .registerForm: return "获取验证码"
        case .registerCode: return "完成注册"
        }
    }

    var secondaryTitle: String {
        switch self {
        case .login: return "创建新账号"
        case .registerForm, .registerCode: return "返回登录"
        }
    }

    var requiresPassword: Bool {
        self != .registerCode
    }
}

private extension View {
    func authFieldStyle() -> some View {
        self
            .font(.body)
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
    }
}
