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
            .background(.white, in: Capsule())
            .overlay { Capsule().stroke(GapStyle.line) }
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
                            .foregroundStyle(GapStyle.coral)
                    }
                }
                Spacer()
                if goal.id == store.selectedGoalID {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(GapStyle.coral)
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
            .tint(GapStyle.plum)
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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        LogoMark(size: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.user?.nickname ?? "Gapzilla").font(.headline)
                            Text("@\(store.user?.username ?? "")")
                                .font(.subheadline)
                                .foregroundStyle(GapStyle.secondary)
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

                Section {
                    Button(role: .destructive) {
                        Task {
                            dismiss()
                            await store.logout()
                        }
                    } label: {
                        Label(store.text("退出登录", "Log out"), systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle(store.text("账号", "Account"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.text("完成", "Done")) { dismiss() }
                }
            }
        }
    }
}
