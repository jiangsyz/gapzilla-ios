import AuthenticationServices
import CryptoKit
import SwiftUI
import zxcvbn

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
            PageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BrandLockup(compact: true)
                    .padding(.bottom, 48)

                    Text(store.text("目标间隔记录工具", "Goal interval tracker"))
                        .font(.caption.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(GapStyle.info)

                    Text(store.text("目标与事件记录", "Goals and event records"))
                        .font(.system(size: 38, weight: .bold, design: .default))
                        .tracking(-1)
                        .foregroundStyle(GapStyle.ink)
                        .padding(.top, 10)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(store.text(
                        "支持创建目标、记录破例与冲动，并根据历史数据计算当前、最长和平均间隔。",
                        "Create goals, record slips and urges, and calculate current, longest, and average gaps from historical data."
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
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
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
                        store.text("登录后可创建目标并记录事件。", "Sign in to create goals and record events."),
                        systemImage: "circle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GapStyle.secondary)
                    .symbolRenderingMode(.monochrome)
                    .tint(GapStyle.slip)
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
                        .tint(GapStyle.info)
                    Text(store.text("正在登录…", "Signing in…"))
                        .font(.headline)
                        .foregroundStyle(GapStyle.ink)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
                .background(GapStyle.surface, in: RoundedRectangle(cornerRadius: GapStyle.cardRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: GapStyle.cardRadius, style: .continuous)
                        .stroke(GapStyle.line, lineWidth: 1)
                }
                .shadow(color: GapStyle.ink.opacity(0.06), radius: 12, y: 4)
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
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: GapStyle.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GapStyle.radius, style: .continuous)
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

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackground()
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
                "创建新账号",
                subtitle: "将使用 Apple 账号创建 Gapzilla 账号，无需填写昵称、用户名或密码。"
            )
            primaryButton("创建并继续", disabled: false) {
                Task { _ = await store.createAppleAccount(choice: choice) }
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
                    .foregroundStyle(GapStyle.info)
                    .frame(width: 44, height: 44)
                    .background(GapStyle.infoSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(GapStyle.ink)
                    Text(subtitle).font(.subheadline).foregroundStyle(GapStyle.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(GapStyle.secondary)
            }
            .padding(16)
            .background(GapStyle.surface, in: RoundedRectangle(cornerRadius: GapStyle.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GapStyle.radius, style: .continuous)
                    .stroke(GapStyle.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func primaryButton(_ title: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if store.isBusy { ProgressView().tint(.white) }
                Text(title)
            }
        }
        .buttonStyle(PrimaryActionButtonStyle())
        .disabled(disabled || store.isBusy)
    }
}

private struct CurrentGapPreview: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(store.text("数据示例", "Sample data"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GapStyle.secondary)
                Spacer()
                Text(store.text("当前间隔", "Current gap"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(GapStyle.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(GapStyle.surfaceSoft, in: Capsule())
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("23")
                    .font(.system(size: 58, weight: .bold, design: .default))
                    .foregroundStyle(GapStyle.ink)
                Text(store.text("天", "days"))
                    .font(.headline)
                    .foregroundStyle(GapStyle.info)
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
                        Capsule().fill(GapStyle.info).frame(width: proxy.size.width * fraction)
                    }
            }
            .frame(height: 7)
        }
    }
}

enum RegistrationPasswordStrength: Int, CaseIterable {
    case empty
    case weak
    case usable
    case good
    case strong

    var filledSegments: Int {
        max(0, rawValue)
    }
}

enum RegistrationPasswordIssue: Equatable {
    case tooShort(remaining: Int)
    case tooLong
    case unsupportedCharacters
}

enum RegistrationInputRules {
    static let usernameRange = 3...20
    static let passwordRange = 8...20

    static func isUsernameValid(_ username: String) -> Bool {
        guard usernameRange.contains(username.count) else { return false }
        return username.unicodeScalars.allSatisfy { scalar in
            let value = scalar.value
            return (97...122).contains(value)
                || (48...57).contains(value)
                || value == 95
        }
    }

    static func hasSupportedPasswordCharacters(_ password: String) -> Bool {
        !password.isEmpty && password.unicodeScalars.allSatisfy { scalar in
            (33...126).contains(scalar.value)
        }
    }

    static func isPasswordValid(_ password: String) -> Bool {
        passwordRange.contains(password.count)
            && hasSupportedPasswordCharacters(password)
    }

    static func passwordIssue(_ password: String) -> RegistrationPasswordIssue? {
        guard !password.isEmpty else { return nil }
        guard hasSupportedPasswordCharacters(password) else { return .unsupportedCharacters }
        if password.count < passwordRange.lowerBound {
            return .tooShort(remaining: passwordRange.lowerBound - password.count)
        }
        if password.count > passwordRange.upperBound { return .tooLong }
        return nil
    }

    static func passwordStrength(
        _ password: String,
        username: String = ""
    ) -> RegistrationPasswordStrength {
        guard !password.isEmpty else { return .empty }
        guard isPasswordValid(password) else { return .weak }

        let userInputs = [username.lowercased(), "gapzilla", "quietbase"]
            .filter { !$0.isEmpty }
        switch zxcvbn(password, userInputs: userInputs).score ?? 0 {
        case 0...1: return .weak
        case 2: return .usable
        case 3: return .good
        default: return .strong
        }
    }
}

struct AuthenticationView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var mode: AuthenticationMode
    @State private var username = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field { case username, password }

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackground()
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

                        VStack(spacing: mode == .register ? 18 : 14) {
                            if mode == .register {
                                RegistrationUsernameField(text: $username)
                                    .focused($focusedField, equals: .username)

                                RegistrationPasswordField(text: $password, username: username)
                                    .focused($focusedField, equals: .password)
                            } else {
                                InputField(
                                    title: store.text("用户名", "Username"),
                                    icon: "person",
                                    text: $username
                                )
                                .focused($focusedField, equals: .username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                                SecureInputField(
                                    title: store.text("密码", "Password"),
                                    text: $password
                                )
                                .focused($focusedField, equals: .password)
                            }
                        }

                        Button {
                            Task {
                                let succeeded = mode == .login
                                    ? await store.login(username: username, password: password)
                                    : await store.register(username: username, password: password)
                                if succeeded { dismiss() }
                            }
                        } label: {
                            HStack {
                                if store.isBusy { ProgressView().tint(.white) }
                                Text(mode == .login ? store.text("登录", "Log in") : store.text("创建账号", "Create account"))
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .disabled(isPrimaryActionDisabled)
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

    private var isPrimaryActionDisabled: Bool {
        if store.isBusy { return true }
        switch mode {
        case .login:
            return username.isEmpty || password.isEmpty
        case .register:
            return !RegistrationInputRules.isUsernameValid(username)
                || !RegistrationInputRules.isPasswordValid(password)
        }
    }
}

private struct InputField: View {
    let title: String
    let icon: String
    @Binding var text: String
    var borderColor: Color = GapStyle.line

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(GapStyle.secondary)
            TextField(title, text: $text)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(GapStyle.surface, in: RoundedRectangle(cornerRadius: GapStyle.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GapStyle.radius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        }
    }
}

private struct SecureInputField: View {
    let title: String
    @Binding var text: String
    var borderColor: Color = GapStyle.line
    var usesASCIICapableKeyboard = false
    var isNewPassword = false
    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock").foregroundStyle(GapStyle.secondary)
            Group {
                if isRevealed {
                    TextField(title, text: $text)
                } else {
                    SecureField(title, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .keyboardType(usesASCIICapableKeyboard ? .asciiCapable : .default)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(isNewPassword ? .newPassword : .password)

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(GapStyle.secondary)
                    .frame(width: 28, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? "隐藏密码" : "显示密码")
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(GapStyle.surface, in: RoundedRectangle(cornerRadius: GapStyle.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GapStyle.radius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        }
    }
}

private enum RegistrationRuleState {
    case neutral
    case satisfied
    case invalid

    var color: Color {
        switch self {
        case .neutral:
            GapStyle.secondary
        case .satisfied:
            GapStyle.urge
        case .invalid:
            GapStyle.danger
        }
    }

    var symbol: String {
        switch self {
        case .neutral:
            "circle"
        case .satisfied:
            "checkmark.circle.fill"
        case .invalid:
            "xmark.circle.fill"
        }
    }
}

private struct RegistrationFieldHeader: View {
    let title: String
    let count: String
    var countColor: Color = GapStyle.secondary

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(GapStyle.ink)
            Spacer()
            Text(count)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(countColor)
                .contentTransition(.numericText())
        }
    }
}

private struct RegistrationRuleLabel: View {
    let text: String
    let state: RegistrationRuleState

    var body: some View {
        Label(text, systemImage: state.symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(state.color)
            .animation(.easeOut(duration: 0.16), value: state.symbol)
    }
}

private struct RegistrationUsernameField: View {
    @Binding var text: String

    private var lengthIsValid: Bool {
        RegistrationInputRules.usernameRange.contains(text.count)
    }

    private var charactersAreValid: Bool {
        !text.isEmpty && text.unicodeScalars.allSatisfy { scalar in
            let value = scalar.value
            return (97...122).contains(value)
                || (48...57).contains(value)
                || value == 95
        }
    }

    private var isValid: Bool {
        RegistrationInputRules.isUsernameValid(text)
    }

    private func ruleState(_ satisfied: Bool) -> RegistrationRuleState {
        if text.isEmpty { return .neutral }
        return satisfied ? .satisfied : .invalid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RegistrationFieldHeader(
                title: "用户名",
                count: "\(text.count) / 20",
                countColor: text.count > 20 ? GapStyle.danger : GapStyle.secondary
            )
            InputField(
                title: "例如 gapzilla_01",
                icon: "person",
                text: $text,
                borderColor: text.isEmpty || isValid ? GapStyle.line : GapStyle.danger.opacity(0.65)
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    RegistrationRuleLabel(text: "3–20 个字符", state: ruleState(lengthIsValid))
                    RegistrationRuleLabel(text: "小写字母、数字或 _", state: ruleState(charactersAreValid))
                }
                VStack(alignment: .leading, spacing: 5) {
                    RegistrationRuleLabel(text: "3–20 个字符", state: ruleState(lengthIsValid))
                    RegistrationRuleLabel(text: "小写字母、数字或 _", state: ruleState(charactersAreValid))
                }
            }
        }
    }
}

private struct RegistrationPasswordField: View {
    @Binding var text: String
    let username: String

    private var isValid: Bool {
        RegistrationInputRules.isPasswordValid(text)
    }

    private var strength: RegistrationPasswordStrength {
        RegistrationInputRules.passwordStrength(text, username: username)
    }

    private var issue: RegistrationPasswordIssue? {
        RegistrationInputRules.passwordIssue(text)
    }

    private var strengthColor: Color {
        return switch strength {
        case .empty:
            GapStyle.line
        case .weak:
            GapStyle.slip
        case .usable:
            GapStyle.warning
        case .good:
            GapStyle.info
        case .strong:
            GapStyle.urge
        }
    }

    private var strengthText: String {
        return switch strength {
        case .empty:
            "输入后显示强度"
        case .weak:
            "偏弱"
        case .usable:
            "一般"
        case .good:
            "良好"
        case .strong:
            "较强"
        }
    }

    private var lengthRuleState: RegistrationRuleState {
        if text.isEmpty { return .neutral }
        return RegistrationInputRules.passwordRange.contains(text.count) ? .satisfied : .invalid
    }

    private var characterRuleState: RegistrationRuleState {
        if text.isEmpty { return .neutral }
        return RegistrationInputRules.hasSupportedPasswordCharacters(text) ? .satisfied : .invalid
    }

    private var lengthRuleText: String {
        switch issue {
        case let .tooShort(remaining):
            "还需 \(remaining) 个字符"
        case .tooLong:
            "最多 20 个字符"
        default:
            "8–20 个字符"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RegistrationFieldHeader(
                title: "密码",
                count: "\(text.count) / 20",
                countColor: text.count > RegistrationInputRules.passwordRange.upperBound
                    ? GapStyle.danger
                    : GapStyle.secondary
            )
            SecureInputField(
                title: "输入密码",
                text: $text,
                borderColor: text.isEmpty || isValid ? GapStyle.line : GapStyle.danger.opacity(0.65),
                usesASCIICapableKeyboard: true,
                isNewPassword: true
            )

            PasswordStrengthMeter(
                strength: strength,
                color: strengthColor,
                label: strengthText
            )

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    RegistrationRuleLabel(text: lengthRuleText, state: lengthRuleState)
                    RegistrationRuleLabel(
                        text: "英文字母、数字或半角符号",
                        state: characterRuleState
                    )
                }
                VStack(alignment: .leading, spacing: 5) {
                    RegistrationRuleLabel(text: lengthRuleText, state: lengthRuleState)
                    RegistrationRuleLabel(
                        text: issue == .unsupportedCharacters
                            ? "不支持中文、空格或全角字符"
                            : "英文字母、数字或半角符号",
                        state: characterRuleState
                    )
                }
            }

            if isValid {
                Text("强度仅作提示，不限制字符组合")
                    .font(.caption)
                    .foregroundStyle(GapStyle.secondary)
            }
        }
    }
}

private struct PasswordStrengthMeter: View {
    let strength: RegistrationPasswordStrength
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index < filledSegments ? color : GapStyle.line.opacity(0.72))
                        .frame(height: 6)
                }
            }
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(strength == .empty ? GapStyle.secondary : color)
                .frame(minWidth: 72, alignment: .trailing)
        }
        .animation(.easeOut(duration: 0.18), value: strength.rawValue)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("密码强度：\(label)")
    }

    private var filledSegments: Int {
        strength.filledSegments
    }
}

struct GoalSetupView: View {
    @EnvironmentObject private var store: AppStore
    @State private var name = ""

    var body: some View {
        ZStack {
            PageBackground()
            VStack(alignment: .leading, spacing: 24) {
                BrandLockup()
                Spacer()
                Image(systemName: "scope")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(GapStyle.info)
                SectionTitle(
                    store.text("你想让什么间隔变长？", "Which gap do you want to grow?"),
                    subtitle: store.text("目标只是一个观察范围，不是对自己的评判。", "A goal is an observation boundary, not a judgment.")
                )
                InputField(title: store.text("例如：减少深夜刷短视频", "Example: Less late-night scrolling"), icon: "pencil", text: $name)
                Button {
                    Task { _ = await store.createGoal(name: name) }
                } label: {
                    Text(store.text("创建第一个目标", "Create first goal"))
                }
                .buttonStyle(PrimaryActionButtonStyle())
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
