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

                    Text(store.text("别追求从不破例，\n只看间隔是否正在变长。", "Stop chasing perfection.\nWatch the gaps grow."))
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .tracking(-1.4)
                        .foregroundStyle(GapStyle.ink)
                        .padding(.top, 10)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(store.text(
                        "Gapzilla 记录破例，也记录被你控制住的冲动。一次困难，不会抹掉周围的进步。",
                        "Gapzilla records slips and the urges you controlled, so one hard day never erases the progress around it."
                    ))
                    .font(.body.weight(.medium))
                    .foregroundStyle(GapStyle.secondary)
                    .lineSpacing(5)
                    .padding(.top, 18)

                    CurrentGapPreview()
                        .padding(.vertical, 28)

                    Button {
                        authMode = .register
                    } label: {
                        Text(store.text("开始记录", "Start tracking"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .foregroundStyle(.white)
                            .background(GapStyle.coral, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Button {
                        authMode = .login
                    } label: {
                        Text(store.text("已有账号，去登录", "I already have an account"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(GapStyle.ink)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay { RoundedRectangle(cornerRadius: 16).stroke(GapStyle.line) }
                    }
                    .padding(.top, 10)

                    Label(
                        store.text("一次破例是一条数据，不是一次判决。", "A slip is a data point, not a verdict."),
                        systemImage: "circle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GapStyle.secondary)
                    .symbolRenderingMode(.monochrome)
                    .tint(GapStyle.coral)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
            }
        }
        .sheet(item: $authMode) { mode in
            AuthenticationView(mode: mode)
        }
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
