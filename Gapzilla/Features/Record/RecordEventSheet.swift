import SwiftUI

struct RecordEventSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var kind: EventKind
    @State private var date = Date()
    @State private var note = ""
    @State private var saved = false

    init(kind: EventKind = .slip) {
        _kind = State(initialValue: kind)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(store.text("类型", "Type"), selection: $kind) {
                        Label(store.text("破例", "Slip"), systemImage: "arrow.counterclockwise")
                            .tag(EventKind.slip)
                        Label(store.text("冲动", "Urge"), systemImage: "hand.raised.fill")
                            .tag(EventKind.urge)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(kind == .slip
                         ? store.text("破例会开启一个新的间隔。", "A slip starts a new gap.")
                         : store.text("只记录冲动事实；同日没有破例时，系统才会将它视为控制住。", "Record the urge itself. It counts as controlled only if no slip occurs that day."))
                }

                Section(store.text("发生日期", "Date")) {
                    DatePicker(
                        store.text("日期", "Date"),
                        selection: $date,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                }

                Section {
                    TextField(
                        store.text("记录当时发生了什么（可选）", "What happened? (optional)"),
                        text: $note,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .onChange(of: note) { _, value in
                        if value.count > 50 { note = String(value.prefix(50)) }
                    }
                } header: {
                    HStack {
                        Text(store.text("备注", "Note"))
                        Spacer()
                        Text("\(note.count)/50")
                    }
                }

                Section {
                    Text(store.text("记录的是事实，不是对自己的判决。", "You are recording a fact, not passing a verdict."))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(GapStyle.secondary)
                }
                .listRowBackground(GapStyle.coralSoft.opacity(0.7))
            }
            .scrollContentBackground(.hidden)
            .background(GlowBackground())
            .navigationTitle(store.text("记录一次事件", "Record an event"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.text("取消", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.text("保存", "Save")) {
                        Task {
                            if await store.record(kind: kind, date: date, note: note) {
                                saved.toggle()
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(store.isBusy)
                }
            }
            .sensoryFeedback(.success, trigger: saved)
        }
    }
}
