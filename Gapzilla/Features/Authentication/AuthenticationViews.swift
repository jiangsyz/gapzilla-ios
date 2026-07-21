import AuthenticationServices
import CryptoKit
import SwiftUI

enum AuthenticationMode: String, CaseIterable, Identifiable {
    case login
    case register

    var id: String { rawValue }
}

struct WelcomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var authMode: AuthenticationMode?

    init() {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-preview-login") {
            _authMode = State(initialValue: .login)
        } else if ProcessInfo.processInfo.arguments.contains("--ui-preview-register") {
            _authMode = State(initialValue: .register)
        } else {
            _authMode = State(initialValue: nil)
        }
#else
        _authMode = State(initialValue: nil)
#endif
    }

    var body: some View {
        ZStack {
            GlowBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        BrandLockup(compact: true)
                        Spacer()
                        Menu {
                            Button("中文") { store.language = .chinese }
                            Button("English") { store.language = .english }
                        } label: {
                            Image(systemName: "globe")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(GapStyle.ink)
                                .frame(width: 42, height: 42)
                                .background(.white, in: Circle())
                                .overlay { Circle().stroke(GapStyle.line) }
                        }
                    }
                    .padding(.bottom, 48)

                    Text(store.text("记录事实，不做审判", "FACTS, NOT JUDGMENT"))
                        .font(.caption.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(GapStyle.coral)

                    Text(store.text("别追求从不破例，\n只看间隔是否正在变长", "Stop chasing perfection\nWatch the gaps grow"))
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .tracking(-1.4)
                        .foregroundStyle(GapStyle.ink)
                        .padding(.top, 10)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(store.text(
                        "Gapzilla 记录破例和冲动，再根据当天结果呈现改变。一次困难，不会抹掉周围的进步。",
                        "Gapzilla records slips and urges, then interprets each day from those facts. One hard day never erases the progress around it."
                    ))
                    .font(.body.weight(.medium))
                    .foregroundStyle(GapStyle.secondary)
                    .lineSpacing(5)
                    .padding(.top, 18)

                    CurrentGapPreview()
                        .padding(.vertical, 28)

                    AppleAuthorizationButton(purpose: .login)

                    Button {
                        authMode = .login
                    } label: {
                        Text(store.text("使用 Gapzilla 账号登录", "Use a Gapzilla account"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .foregroundStyle(.white)
                            .background(GapStyle.coral, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.top, 10)

                    Button {
                        authMode = .register
                    } label: {
                        Text(store.text("注册用户名密码账号", "Create a username account"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(GapStyle.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }

                    Label(
                        store.text("一次破例是一条数据，不是一次判决。", "A slip is a data point, not a verdict."),
                        systemImage: "circle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GapStyle.secondary)
                    .symbolRenderingMode(.monochrome)
                    .tint(GapStyle.coral)
                    .padding(.top, 18)

                    Link(
                        store.text("隐私政策", "Privacy Policy"),
                        destination: URL(string: "https://gapzilla.quietbase.online/privacy")!
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GapStyle.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
            }

            if store.isBusy {
                Color.white.opacity(0.72)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(GapStyle.coral)
                    Text(store.text("正在登录…", "Signing in…"))
                        .font(.headline)
                        .foregroundStyle(GapStyle.ink)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(GapStyle.line, lineWidth: 1)
                }
                .shadow(color: GapStyle.ink.opacity(0.08), radius: 22, y: 10)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.16), value: store.isBusy)
        .sheet(item: $authMode) { mode in
            AuthenticationView(mode: mode)
        }
        .sheet(item: $store.appleAccountChoice) { choice in
            AppleAccountChoiceView(choice: choice)
        }
    }
}

enum AppleAuthorizationPurpose {
    case login
    case bind
    case deleteAccount
}

struct AppleAuthorizationButton: View {
    @EnvironmentObject private var store: AppStore
    let purpose: AppleAuthorizationPurpose
    @State private var rawNonce = ""

    var body: some View {
        SignInWithAppleButton(.continue) { request in
            let nonce = AppleNonce.make()
            rawNonce = nonce
            request.requestedScopes = purpose == .login ? [.fullName, .email] : []
            request.nonce = AppleNonce.sha256(nonce)
        } onCompletion: { result in
            switch result {
            case let .success(authorization):
                complete(authorization)
            case let .failure(error):
                guard !isCancellation(error) else { return }
                store.reportAppleAuthorizationFailure(error)
            }
        }
        .signInWithAppleButtonStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GapStyle.line, lineWidth: 1)
        }
        .disabled(store.isBusy)
    }

    private func complete(_ authorization: ASAuthorization) {
        guard let appleID = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityData = appleID.identityToken,
              let identityToken = String(data: identityData, encoding: .utf8),
              let codeData = appleID.authorizationCode,
              let authorizationCode = String(data: codeData, encoding: .utf8),
              !rawNonce.isEmpty else {
            store.reportAppleAuthorizationFailure(AppleAuthorizationError.invalidCredential)
            return
        }
        let formatter = PersonNameComponentsFormatter()
        let fullName = appleID.fullName.map { formatter.string(from: $0) } ?? ""
        let credential = AppleCredential(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            nonce: rawNonce,
            fullName: fullName
        )
        switch purpose {
        case .login:
            store.beginAppleLoginCompletion()
            Task {
                await store.loginWithApple(credential: credential)
            }
        case .bind:
            Task {
                _ = await store.bindApple(credential: credential)
            }
        case .deleteAccount:
            Task {
                _ = await store.deleteAccount(credential: credential)
            }
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        guard let authorizationError = error as? ASAuthorizationError else { return false }
        return authorizationError.code == .canceled
    }
}

private enum AppleNonce {
    static func make() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "")
            + UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

private enum AppleAuthorizationError: LocalizedError {
    case invalidCredential

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            "Apple 没有返回完整的登录凭证，请重试。"
        }
    }
}

private enum AppleAccountChoiceStep {
    case prompt
    case existing
    case newAccount
}

struct AppleAccountChoiceView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let choice: AppleAccountChoice
    @State private var step: AppleAccountChoiceStep = .prompt
    @State private var username = ""
    @State private var password = ""
    @State private var nickname: String

    init(choice: AppleAccountChoice) {
        self.choice = choice
        _nickname = State(initialValue: choice.suggestedNickname)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GlowBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(GapStyle.ink)
                        content
                    }
                    .padding(24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.text("取消", "Cancel")) {
                        store.cancelAppleAccountChoice()
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(store.isBusy)
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .prompt:
            prompt
        case .existing:
            existingAccount
        case .newAccount:
            newAccount
        }
    }

    private var prompt: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionTitle(
                store.text("第一次使用 Apple 登录", "First time signing in with Apple"),
                subtitle: store.text(
                    "你已经有 Gapzilla 账号吗？选择后我们才会继续，不会自动创建或合并账号。",
                    "Do you already have a Gapzilla account? We will continue only after you choose—no account is created or merged automatically."
                )
            )
            choiceButton(
                title: store.text("绑定已有账号", "Link an existing account"),
                subtitle: store.text("保留原来的目标、记录和统计", "Keep your existing goals, records, and insights"),
                icon: "person.crop.circle.badge.checkmark"
            ) { step = .existing }
            choiceButton(
                title: store.text("创建新账号", "Create a new account"),
                subtitle: store.text("这是第一次使用 Gapzilla", "This is my first time using Gapzilla"),
                icon: "person.crop.circle.badge.plus"
            ) { step = .newAccount }
        }
    }

    private var existingAccount: some View {
        VStack(alignment: .leading, spacing: 18) {
            backButton
            SectionTitle(
                store.text("绑定已有账号", "Link your existing account"),
                subtitle: store.text("验证用户名和密码后，Apple 会成为同一账号的新登录方式。", "After your password is verified, Apple becomes another way to enter the same account.")
            )
            InputField(title: store.text("用户名", "Username"), icon: "person", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureInputField(title: store.text("密码", "Password"), text: $password)
            primaryButton(store.text("验证并绑定", "Verify and link"), disabled: username.isEmpty || password.isEmpty) {
                Task {
                    _ = await store.linkAppleToExistingAccount(
                        choice: choice,
                        username: username,
                        password: password
                    )
                }
            }
        }
    }

    private var newAccount: some View {
        VStack(alignment: .leading, spacing: 18) {
            backButton
            SectionTitle(
                store.text("创建新账号", "Create a new account"),
                subtitle: store.text("只需要一个显示昵称，不会强迫你再设置用户名和密码。", "Choose a display name. You do not need to create a username and password.")
            )
            InputField(title: store.text("昵称", "Nickname"), icon: "face.smiling", text: $nickname)
            primaryButton(store.text("创建并继续", "Create and continue"), disabled: nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                Task { _ = await store.createAppleAccount(choice: choice, nickname: nickname) }
            }
        }
    }

    private var backButton: some View {
        Button {
            step = .prompt
        } label: {
            Label(store.text("返回选择", "Back to choices"), systemImage: "chevron.left")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(GapStyle.secondary)
        }
    }

    private func choiceButton(
        title: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(GapStyle.coral)
                    .frame(width: 44, height: 44)
                    .background(GapStyle.coralSoft, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(GapStyle.ink)
                    Text(subtitle).font(.subheadline).foregroundStyle(GapStyle.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(GapStyle.secondary)
            }
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(GapStyle.line) }
        }
        .buttonStyle(.plain)
    }

    private func primaryButton(_ title: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if store.isBusy { ProgressView().tint(.white) }
                Text(title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundStyle(.white)
            .background(GapStyle.coral, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(disabled || store.isBusy)
    }
}

private struct CurrentGapPreview: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(store.text("你的改变会这样呈现", "A sample of your progress"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GapStyle.secondary)
                Spacer()
                Text("Gapzilla")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(GapStyle.plum, in: Capsule())
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("23")
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .foregroundStyle(GapStyle.ink)
                Text(store.text("天", "days"))
                    .font(.headline)
                    .foregroundStyle(GapStyle.coral)
            }
            VStack(spacing: 8) {
                PreviewBar(label: "7", fraction: 0.38)
                PreviewBar(label: "14", fraction: 0.68)
                PreviewBar(label: "23", fraction: 1)
            }
        }
        .softCard()
    }
}

private struct PreviewBar: View {
    let label: String
    let fraction: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(GapStyle.secondary)
                .frame(width: 24, alignment: .leading)
            GeometryReader { proxy in
                Capsule()
                    .fill(GapStyle.line.opacity(0.65))
                    .overlay(alignment: .leading) {
                        Capsule().fill(GapStyle.coral.gradient).frame(width: proxy.size.width * fraction)
                    }
            }
            .frame(height: 7)
        }
    }
}

struct AuthenticationView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var mode: AuthenticationMode
    @State private var username = ""
    @State private var password = ""
    @State private var nickname = ""
    @FocusState private var focusedField: Field?

    private enum Field { case username, nickname, password }

    var body: some View {
        NavigationStack {
            ZStack {
                GlowBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        LogoMark(size: 54)
                        SectionTitle(
                            mode == .login ? store.text("欢迎回来", "Welcome back") : store.text("创建账号", "Create your account"),
                            subtitle: mode == .login
                                ? store.text("继续看见间隔的变化。", "Keep watching your gaps change.")
                                : store.text("从一个想改变的目标开始。", "Start with one thing you want to change.")
                        )

                        Picker("", selection: $mode) {
                            Text(store.text("登录", "Log in")).tag(AuthenticationMode.login)
                            Text(store.text("注册", "Register")).tag(AuthenticationMode.register)
                        }
                        .pickerStyle(.segmented)

                        VStack(spacing: 14) {
                            InputField(
                                title: store.text("用户名", "Username"),
                                icon: "person",
                                text: $username
                            )
                            .focused($focusedField, equals: .username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                            if mode == .register {
                                InputField(
                                    title: store.text("昵称", "Nickname"),
                                    icon: "face.smiling",
                                    text: $nickname
                                )
                                .focused($focusedField, equals: .nickname)
                            }

                            SecureInputField(
                                title: store.text("密码", "Password"),
                                text: $password
                            )
                            .focused($focusedField, equals: .password)
                        }

                        Button {
                            Task {
                                let succeeded = mode == .login
                                    ? await store.login(username: username, password: password)
                                    : await store.register(username: username, password: password, nickname: nickname)
                                if succeeded { dismiss() }
                            }
                        } label: {
                            HStack {
                                if store.isBusy { ProgressView().tint(.white) }
                                Text(mode == .login ? store.text("登录", "Log in") : store.text("创建账号", "Create account"))
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .foregroundStyle(.white)
                            .background(GapStyle.coral, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .disabled(store.isBusy || username.isEmpty || password.isEmpty || (mode == .register && nickname.isEmpty))
                        .opacity(username.isEmpty || password.isEmpty ? 0.55 : 1)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(store.text("关闭", "Close")) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct InputField: View {
    let title: String
    let icon: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(GapStyle.secondary)
            TextField(title, text: $text)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(GapStyle.line) }
    }
}

private struct SecureInputField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock").foregroundStyle(GapStyle.secondary)
            SecureField(title, text: $text)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(GapStyle.line) }
    }
}

struct GoalSetupView: View {
    @EnvironmentObject private var store: AppStore
    @State private var name = ""

    var body: some View {
        ZStack {
            GlowBackground()
            VStack(alignment: .leading, spacing: 24) {
                BrandLockup()
                Spacer()
                Image(systemName: "scope")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(GapStyle.coral)
                SectionTitle(
                    store.text("你想让什么间隔变长？", "Which gap do you want to grow?"),
                    subtitle: store.text("目标只是一个观察范围，不是对自己的评判。", "A goal is an observation boundary, not a judgment.")
                )
                InputField(title: store.text("例如：减少深夜刷短视频", "Example: Less late-night scrolling"), icon: "pencil", text: $name)
                Button {
                    Task { _ = await store.createGoal(name: name) }
                } label: {
                    Text(store.text("创建第一个目标", "Create first goal"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .foregroundStyle(.white)
                        .background(GapStyle.coral, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isBusy)
                Spacer()
                Button(store.text("退出登录", "Log out")) { Task { await store.logout() } }
                    .foregroundStyle(GapStyle.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
    }
}
