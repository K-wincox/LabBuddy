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
                AuthBackdrop()

                VStack(spacing: 0) {
                    Spacer(minLength: 154)

                    VStack(alignment: .leading, spacing: 22) {
                        formCard
                    }
                    .padding(.horizontal, 26)

                    Spacer(minLength: 18)

                    footer
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

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(.system(size: 32, weight: .regular))
                    Text(step.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button(step == .login ? "Sign up" : "Sign in") {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        secondaryAction()
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.82))
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(.white.opacity(0.46), in: Capsule())
            }

            VStack(spacing: 12) {
                AuthInputRow(icon: "at", placeholder: "e-mail address", text: $email, kind: .email)

                if step.requiresPassword {
                    AuthInputRow(icon: "key", placeholder: "password", text: $password, kind: .password)
                }

                if step == .registerCode {
                    AuthInputRow(icon: "number", placeholder: "verification code", text: $code, kind: .code)
                }
            }

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    if let message = authStore.errorMessage {
                        Text(message)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(step.helper)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                }

                Spacer()

                Button {
                    Task { await submit() }
                } label: {
                    ZStack {
                        Capsule()
                            .fill(canSubmit ? Color.black.opacity(0.88) : Color.black.opacity(0.12))
                            .frame(width: 64, height: 48)
                        if authStore.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(canSubmit ? .white : .secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit || authStore.isLoading)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.62), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.07), radius: 24, x: 0, y: 18)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Text("实验数据默认保存在本机")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 24)
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
                withAnimation(.easeInOut(duration: 0.22)) {
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

private struct AuthBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.98, blue: 0.98),
                    Color(red: 0.98, green: 0.94, blue: 0.90),
                    Color(red: 0.93, green: 0.97, blue: 0.96),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.36))
                .frame(width: 240, height: 240)
                .offset(x: 120, y: -190)

            Circle()
                .stroke(Color.white.opacity(0.52), lineWidth: 24)
                .frame(width: 235, height: 235)
                .offset(x: 76, y: -60)

            RoundedRectangle(cornerRadius: 8)
                .fill(Color.teal.opacity(0.12))
                .frame(width: 120, height: 300)
                .rotationEffect(.degrees(-12))
                .offset(x: -170, y: 60)

            Circle()
                .fill(Color.orange.opacity(0.18))
                .frame(width: 164, height: 164)
                .offset(x: 150, y: 240)
        }
    }
}

private struct AuthInputRow: View {
    enum Kind {
        case email
        case password
        case code
    }

    let icon: String
    let placeholder: String
    @Binding var text: String
    let kind: Kind

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.72))
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.72))
            }
            .frame(width: 38, height: 38)

            field
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .frame(height: 58)
        .background(.white.opacity(0.66), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.58), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var field: some View {
        switch kind {
        case .email:
            TextField(placeholder, text: $text)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.username)
        case .password:
            SecureField(placeholder, text: $text)
                .textContentType(.password)
        case .code:
            TextField(placeholder, text: $text)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
        }
    }
}

private enum AuthStep {
    case login
    case registerForm
    case registerCode

    var title: String {
        switch self {
        case .login: return "Log in"
        case .registerForm: return "Sign up"
        case .registerCode: return "Verify"
        }
    }

    var subtitle: String {
        switch self {
        case .login:
            return "进入你的实验台，继续今日排程、Protocol 和计时器。"
        case .registerForm:
            return "创建账号，为 Pro 权益和后续云备份预留身份。"
        case .registerCode:
            return "输入邮箱收到的 6 位验证码，完成注册。"
        }
    }

    var helper: String {
        switch self {
        case .login:
            return "使用邮箱和密码登录。"
        case .registerForm:
            return "密码至少 8 位。验证码将发送到邮箱。"
        case .registerCode:
            return "没有收到验证码时，返回登录后重新注册。"
        }
    }

    var requiresPassword: Bool {
        self != .registerCode
    }
}
