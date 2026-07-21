import SwiftUI
import UIKit

struct RecordEventSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var kind: EventKind
    @State private var date = Date()
    @State private var note = ""
    @State private var saved = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case note
    }

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
                    .focused($focusedField, equals: .note)
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
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(GlowBackground())
            .background {
                KeyboardDismissalInstaller(action: dismissKeyboard)
            }
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
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(store.text("完成", "Done")) {
                        dismissKeyboard()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sensoryFeedback(.success, trigger: saved)
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
    }
}

private struct KeyboardDismissalInstaller: UIViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.action = action
        DispatchQueue.main.async {
            guard let window = uiView.window else { return }
            context.coordinator.installIfNeeded(in: window)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var action: () -> Void
        private weak var installedView: UIView?
        private lazy var tapGesture: UITapGestureRecognizer = {
            let gesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            gesture.cancelsTouchesInView = false
            gesture.delegate = self
            return gesture
        }()

        init(action: @escaping () -> Void) {
            self.action = action
        }

        func installIfNeeded(in view: UIView) {
            guard installedView !== view else { return }
            uninstall()
            view.addGestureRecognizer(tapGesture)
            installedView = view
        }

        func uninstall() {
            installedView?.removeGestureRecognizer(tapGesture)
            installedView = nil
        }

        @objc private func handleTap() {
            action()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var touchedView = touch.view
            while let view = touchedView {
                if view is UITextField || view is UITextView {
                    return false
                }
                touchedView = view.superview
            }
            return true
        }
    }
}
