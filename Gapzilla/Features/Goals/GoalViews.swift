import SwiftUI

struct GoalToolbarMenu: View {
    @EnvironmentObject private var store: AppStore
    @Binding var presentsManager: Bool

    var body: some View {
        Menu {
            Section(store.text("当前目标", "Current goal")) {
                ForEach(store.goals) { goal in
                    Button {
                        Task { await store.selectGoal(goal.id) }
                    } label: {
                        Label(goal.name, systemImage: goal.id == store.selectedGoalID ? "checkmark.circle.fill" : "circle")
                    }
                }
            }
            Button {
                presentsManager = true
            } label: {
                Label(store.text("管理目标", "Manage goals"), systemImage: "slider.horizontal.3")
            }
        } label: {
            HStack(spacing: 5) {
                Text(store.selectedGoal?.name ?? "Gapzilla")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(GapStyle.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(GapStyle.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(GapStyle.line, lineWidth: 1)
            }
        }
    }
}

struct GoalManagerSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var editingGoal: Goal?
    @State private var editedName = ""
    @State private var deletingGoal: Goal?

    var body: some View {
        NavigationStack {
            goalList
            .navigationTitle(store.text("目标", "Goals"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.text("完成", "Done")) { dismiss() }
                }
            }
            .alert(store.text("重命名目标", "Rename goal"), isPresented: renamePresented) {
                TextField(store.text("目标名称", "Goal name"), text: $editedName)
                Button(store.text("取消", "Cancel"), role: .cancel) { editingGoal = nil }
                Button(store.text("保存", "Save")) {
                    guard let goal = editingGoal else { return }
                    Task { _ = await store.renameGoal(goal, name: editedName) }
                    editingGoal = nil
                }
            }
            .confirmationDialog(
                store.text("确定删除这个目标？", "Delete this goal?"),
                isPresented: deletePresented,
                titleVisibility: .visible
            ) {
                Button(store.text("删除目标及全部记录", "Delete goal and all records"), role: .destructive) {
                    guard let goal = deletingGoal else { return }
                    Task { _ = await store.deleteGoal(goal) }
                    deletingGoal = nil
                }
                Button(store.text("取消", "Cancel"), role: .cancel) { deletingGoal = nil }
            }
        }
    }

    private var goalList: some View {
        List {
            newGoalSection
            goalsSection
        }
        .scrollContentBackground(.hidden)
        .background(PageBackground())
    }

    private var newGoalSection: some View {
        Section(store.text("新增目标", "New goal")) {
            HStack {
                TextField(store.text("目标名称", "Goal name"), text: $newName)
                Button(action: createGoal) {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
                .disabled(trimmedNewName.isEmpty)
            }
        }
    }

    private var goalsSection: some View {
        Section {
            ForEach(store.goals) { goal in
                goalRow(goal)
            }
        } header: {
            Text(store.text("我的目标", "My goals"))
        } footer: {
            Text(store.text("左滑可重命名或删除。删除目标会同时删除其中的事件。", "Swipe left to rename or delete. Deleting a goal also deletes its events."))
        }
    }

    private func goalRow(_ goal: Goal) -> some View {
        Button {
            Task { await store.selectGoal(goal.id) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.name).foregroundStyle(GapStyle.ink)
                    if goal.id == store.selectedGoalID {
                        Text(store.text("当前目标", "Current"))
                            .font(.caption)
                            .foregroundStyle(GapStyle.info)
                    }
                }
                Spacer()
                if goal.id == store.selectedGoalID {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(GapStyle.info)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { deletingGoal = goal } label: {
                Label(store.text("删除", "Delete"), systemImage: "trash")
            }
            Button {
                editedName = goal.name
                editingGoal = goal
            } label: {
                Label(store.text("重命名", "Rename"), systemImage: "pencil")
            }
            .tint(GapStyle.info)
        }
    }

    private var trimmedNewName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var renamePresented: Binding<Bool> {
        Binding(get: { editingGoal != nil }, set: { if !$0 { editingGoal = nil } })
    }

    private var deletePresented: Binding<Bool> {
        Binding(get: { deletingGoal != nil }, set: { if !$0 { deletingGoal = nil } })
    }

    private func createGoal() {
        let value = trimmedNewName
        Task {
            if await store.createGoal(name: value) { newName = "" }
        }
    }
}

struct AccountSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var presentsDeleteAccount = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        LogoMark(size: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.user?.nickname ?? "Gapzilla").font(.headline)
                            if let username = store.user?.username, !username.isEmpty {
                                Text("@\(username)")
                                    .font(.subheadline)
                                    .foregroundStyle(GapStyle.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 5)
                }

                Section(store.text("语言", "Language")) {
                    Picker(store.text("语言", "Language"), selection: $store.language) {
                        Text("中文").tag(AppLanguage.chinese)
                        Text("English").tag(AppLanguage.english)
                    }
                    .pickerStyle(.segmented)
                }

                Section(store.text("登录方式", "Sign-in methods")) {
                    loginMethodRow(
                        store.text("用户名和密码", "Username and password"),
                        systemImage: "key.fill",
                        isLinked: hasPasswordLogin
                    )
                    loginMethodRow(
                        store.text("Apple 登录", "Sign in with Apple"),
                        systemImage: "apple.logo",
                        isLinked: hasAppleLogin
                    )
                    if !hasAppleLogin {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(store.text("绑定后，你可以用 Apple 进入当前账号和原有数据。", "Link Apple to enter this account and its existing data."))
                                .font(.caption)
                                .foregroundStyle(GapStyle.secondary)
                            AppleAuthorizationButton(purpose: .bind)
                                .frame(height: 46)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Link(destination: URL(string: "https://gapzilla.quietbase.online/privacy")!) {
                        Label(store.text("隐私政策", "Privacy Policy"), systemImage: "hand.raised.fill")
                    }
                    Link(destination: URL(string: "https://gapzilla.quietbase.online/support")!) {
                        Label(store.text("支持与帮助", "Support"), systemImage: "questionmark.circle.fill")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            dismiss()
                            await store.logout()
                        }
                    } label: {
                        Label(store.text("退出登录", "Log out"), systemImage: "rectangle.portrait.and.arrow.right")
                    }

                    Button(role: .destructive) {
                        presentsDeleteAccount = true
                    } label: {
                        Label(store.text("注销账号", "Delete Account"), systemImage: "person.crop.circle.badge.minus")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PageBackground())
            .navigationTitle(store.text("账号", "Account"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.text("完成", "Done")) { dismiss() }
                }
            }
            .sheet(isPresented: $presentsDeleteAccount) {
                DeleteAccountSheet(requiresAppleAuthorization: hasAppleLogin)
            }
        }
    }

    private var hasPasswordLogin: Bool {
        store.user?.loginProviders.contains("password") == true || !(store.user?.username ?? "").isEmpty
    }

    private var hasAppleLogin: Bool {
        store.user?.loginProviders.contains("apple") == true
    }

    private func loginMethodRow(_ title: String, systemImage: String, isLinked: Bool) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(isLinked ? store.text("已绑定", "Linked") : store.text("未绑定", "Not linked"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(isLinked ? GapStyle.info : GapStyle.secondary)
        }
    }
}

private struct DeleteAccountSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let requiresAppleAuthorization: Bool
    @State private var showsConfirmation = false
    @State private var awaitsAppleAuthorization = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(GapStyle.danger)
                        Text(store.text("注销后无法恢复", "Deletion cannot be undone"))
                            .font(.title3.bold())
                            .foregroundStyle(GapStyle.ink)
                        Text(store.text(
                            "你的账号、全部目标、破例和冲动记录以及登录会话都会被永久删除。",
                            "Your account, goals, slip and urge records, and sign-in sessions will be permanently deleted."
                        ))
                        .font(.body)
                        .foregroundStyle(GapStyle.secondary)
                    }
                    .padding(.vertical, 8)
                }

                if awaitsAppleAuthorization {
                    Section {
                        Text(store.text(
                            "请使用 Apple 再验证一次。验证成功后，账号会立即永久删除。",
                            "Authenticate with Apple once more. Your account will be permanently deleted immediately after verification."
                        ))
                        .font(.subheadline)
                        .foregroundStyle(GapStyle.secondary)

                        AppleAuthorizationButton(purpose: .deleteAccount)
                            .frame(height: 50)
                    } header: {
                        Text(store.text("最后一步", "Final step"))
                    }
                } else {
                    Section {
                        Button(role: .destructive) {
                            showsConfirmation = true
                        } label: {
                            Text(store.text("继续注销账号", "Continue to delete account"))
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(store.isBusy)
                    }
                }

                Section {
                    Text(store.text(
                        "如果你只是暂时不想使用 Gapzilla，可以返回账号页选择退出登录。",
                        "If you only want to stop using Gapzilla for now, return to the account page and log out instead."
                    ))
                    .font(.footnote)
                    .foregroundStyle(GapStyle.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PageBackground())
            .navigationTitle(store.text("注销账号", "Delete Account"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.text("取消", "Cancel")) { dismiss() }
                }
            }
            .confirmationDialog(
                store.text("永久删除账号和全部数据？", "Permanently delete your account and all data?"),
                isPresented: $showsConfirmation,
                titleVisibility: .visible
            ) {
                Button(store.text("永久删除", "Delete Permanently"), role: .destructive) {
                    if requiresAppleAuthorization {
                        awaitsAppleAuthorization = true
                    } else {
                        Task { _ = await store.deleteAccount(credential: nil) }
                    }
                }
                Button(store.text("取消", "Cancel"), role: .cancel) {}
            } message: {
                Text(store.text("这个操作不能撤销。", "This action cannot be undone."))
            }
            .overlay {
                if store.isBusy {
                    Color.white.opacity(0.72).ignoresSafeArea()
                    ProgressView()
                        .controlSize(.large)
                        .tint(GapStyle.info)
                }
            }
            .onChange(of: store.phase) { _, phase in
                if phase == .signedOut { dismiss() }
            }
        }
    }
}
