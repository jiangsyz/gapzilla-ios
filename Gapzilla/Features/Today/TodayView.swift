import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @State private var recordKind: EventKind?
    @State private var presentsGoals = false
    @State private var presentsAccount = false

    init() {
#if DEBUG
        let kind: EventKind? = ProcessInfo.processInfo.arguments.contains("--ui-preview-record") ? .slip : nil
        _recordKind = State(initialValue: kind)
#else
        _recordKind = State(initialValue: nil)
#endif
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackground()
                ScrollView {
                    LazyVStack(spacing: 14) {
                        CurrentGapCard()
                        QuickRecordCard(recordKind: $recordKind)
                        ProgressSummaryCard()
                        RecentEventsCard()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .refreshable { await store.refreshAll() }
            }
            .navigationTitle(store.text("今天", "Today"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GoalToolbarMenu(presentsManager: $presentsGoals)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { recordKind = .slip } label: {
                        Image(systemName: "plus").fontWeight(.bold)
                    }
                    Button { presentsAccount = true } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
            }
        }
        .sheet(item: $recordKind) { RecordEventSheet(kind: $0) }
        .sheet(isPresented: $presentsGoals) { GoalManagerSheet() }
        .sheet(isPresented: $presentsAccount) { AccountSheet() }
    }
}

private struct CurrentGapCard: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label(store.text("当前间隔", "Current gap"), systemImage: "arrow.up.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GapStyle.secondary)
                Spacer()
                Text(AppDate.api.string(from: Date()))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(GapStyle.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(store.metrics.currentGap)")
                    .font(.system(size: 64, weight: .bold, design: .default))
                    .tracking(-2)
                Text(store.text("天", "days"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(GapStyle.secondary)
            }
            .foregroundStyle(GapStyle.ink)

            Text(store.text("当前间隔按最近一次破例日期计算。", "The current gap is calculated from the most recent slip date."))
                .font(.caption)
                .foregroundStyle(GapStyle.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(padding: 20)
    }

}

private struct QuickRecordCard: View {
    @EnvironmentObject private var store: AppStore
    @Binding var recordKind: EventKind?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(
                store.text("今天发生了什么？", "What happened today?"),
                subtitle: store.text("选择要记录的事件类型。", "Choose the event type to record.")
            )
            HStack(spacing: 12) {
                QuickRecordButton(
                    title: store.text("记录破例", "Record slip"),
                    subtitle: store.text("开启新间隔", "Starts a new gap"),
                    icon: "arrow.counterclockwise",
                    color: GapStyle.slip
                ) { recordKind = .slip }
                QuickRecordButton(
                    title: store.text("记录冲动", "Record urge"),
                    subtitle: store.text("只记录发生的事实", "Record what happened"),
                    icon: "hand.raised.fill",
                    color: GapStyle.urge
                ) { recordKind = .urge }
            }
        }
        .softCard()
    }
}

private struct QuickRecordButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(GapStyle.ink)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(GapStyle.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .padding(14)
            .background(GapStyle.surface, in: RoundedRectangle(cornerRadius: GapStyle.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GapStyle.radius, style: .continuous)
                    .stroke(GapStyle.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: false)
    }
}

private struct ProgressSummaryCard: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionTitle(store.text("变化概览", "Progress at a glance"))
            HStack(spacing: 10) {
                MetricTile(value: store.metrics.bestGap, label: store.text("最长", "Best"), color: GapStyle.warning)
                MetricTile(value: store.metrics.averageGap, label: store.text("平均", "Average"), color: GapStyle.info)
                MetricTile(value: store.metrics.urgesLastSevenDays, label: store.text("近7天控制住", "Controlled in 7d"), color: GapStyle.ink)
            }
        }
        .softCard()
    }
}

struct MetricTile: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(GapStyle.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(12)
        .background(GapStyle.surfaceSoft, in: RoundedRectangle(cornerRadius: GapStyle.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GapStyle.radius, style: .continuous)
                .stroke(GapStyle.line.opacity(0.7), lineWidth: 1)
        }
    }
}

private struct RecentEventsCard: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(store.text("最近记录", "Recent events"))
            if store.events.isEmpty {
                ContentUnavailableView(
                    store.text("还没有记录", "No events yet"),
                    systemImage: "tray",
                    description: Text(store.text("第一条事实会从这里开始。", "Your first fact will appear here."))
                )
                .frame(minHeight: 150)
            } else {
                ForEach(store.events.prefix(3)) { event in
                    EventCompactRow(event: event)
                    if event.id != store.events.prefix(3).last?.id { Divider() }
                }
            }
        }
        .softCard()
    }
}

struct EventCompactRow: View {
    @EnvironmentObject private var store: AppStore
    let event: GoalEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.kind == .slip ? "arrow.counterclockwise" : "hand.raised.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(event.kind == .slip ? GapStyle.slip : GapStyle.urge)
                .frame(width: 38, height: 38)
                .background(
                    (event.kind == .slip ? GapStyle.slipSoft : GapStyle.urgeSoft),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(event.kind == .slip ? store.text("破例", "Slip") : store.text("冲动", "Urge"))
                    .font(.subheadline.weight(.semibold))
                Text(event.note.isEmpty ? store.text("没有备注", "No note") : event.note)
                    .font(.caption)
                    .foregroundStyle(GapStyle.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(event.date, format: .dateTime.month(.abbreviated).day())
                .font(.caption.weight(.semibold))
                .foregroundStyle(GapStyle.secondary)
        }
        .padding(.vertical, 5)
    }
}
