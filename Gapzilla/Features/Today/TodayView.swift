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
                GlowBackground()
                ScrollView {
                    LazyVStack(spacing: 18) {
                        CurrentGapCard()
                        QuickRecordCard(recordKind: $recordKind)
                        ProgressSummaryCard()
                        RecentEventsCard()
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
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
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(GapStyle.coral.opacity(0.14))
                .frame(width: 170, height: 170)
                .blur(radius: 18)
                .offset(x: 55, y: -70)

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
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .tracking(-3)
                    Text(store.text("天", "days"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(GapStyle.coral)
                }
                .foregroundStyle(GapStyle.ink)

                Text(encouragement)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(GapStyle.ink)

                Text(store.text("数字只描述时间，不评价你。", "This number describes time. It does not judge you."))
                    .font(.caption)
                    .foregroundStyle(GapStyle.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .softCard(padding: 20)
        .clipped()
    }

    private var encouragement: String {
        switch store.metrics.currentGap {
        case 0: store.text("从今天开始，给变化留下证据。", "Start today and leave evidence of change.")
        case 1...6: store.text("新的间隔正在形成。", "A new gap is taking shape.")
        default: store.text("你已经让这段间隔持续了 \(store.metrics.currentGap) 天。", "You have kept this gap growing for \(store.metrics.currentGap) days.")
        }
    }
}

private struct QuickRecordCard: View {
    @EnvironmentObject private var store: AppStore
    @Binding var recordKind: EventKind?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(
                store.text("今天发生了什么？", "What happened today?"),
                subtitle: store.text("两种事实都值得被留下。", "Both kinds of facts deserve to be kept.")
            )
            HStack(spacing: 12) {
                QuickRecordButton(
                    title: store.text("记录破例", "Record slip"),
                    subtitle: store.text("开启新间隔", "Starts a new gap"),
                    icon: "arrow.counterclockwise",
                    color: GapStyle.coral
                ) { recordKind = .slip }
                QuickRecordButton(
                    title: store.text("控制住冲动", "Urge controlled"),
                    subtitle: store.text("保留正向证据", "Keeps positive proof"),
                    icon: "hand.raised.fill",
                    color: GapStyle.plum
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
                Image(systemName: icon).font(.title3.weight(.bold))
                Text(title).font(.subheadline.weight(.bold)).lineLimit(2)
                Text(subtitle).font(.caption).opacity(0.82).lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            .padding(14)
            .foregroundStyle(.white)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                MetricTile(value: store.metrics.bestGap, label: store.text("最长", "Best"), color: GapStyle.coral)
                MetricTile(value: store.metrics.averageGap, label: store.text("平均", "Average"), color: GapStyle.plum)
                MetricTile(value: store.metrics.urgesLastSevenDays, label: store.text("近7天冲动", "7d urges"), color: GapStyle.ink)
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
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .foregroundStyle(event.kind == .slip ? GapStyle.coral : GapStyle.plum)
                .frame(width: 38, height: 38)
                .background(
                    (event.kind == .slip ? GapStyle.coralSoft : GapStyle.plumSoft),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(event.kind == .slip ? store.text("破例", "Slip") : store.text("控制住冲动", "Urge controlled"))
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
