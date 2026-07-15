import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @State private var recordKind: EventKind?
    @State private var presentsGoals = false
    @State private var presentsAccount = false

    var body: some View {
        NavigationStack {
            ZStack {
                GlowBackground()
                ScrollView {
                    LazyVStack(spacing: 18) {
                        CalendarCard(month: $month)
                        EventHistoryCard()
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
                .refreshable { await store.refreshAll() }
            }
            .navigationTitle(store.text("历史", "History"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GoalToolbarMenu(presentsManager: $presentsGoals)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { recordKind = .slip } label: { Image(systemName: "plus").fontWeight(.bold) }
                    Button { presentsAccount = true } label: { Image(systemName: "person.crop.circle") }
                }
            }
        }
        .sheet(item: $recordKind) { RecordEventSheet(kind: $0) }
        .sheet(isPresented: $presentsGoals) { GoalManagerSheet() }
        .sheet(isPresented: $presentsAccount) { AccountSheet() }
    }
}

private struct CalendarDay: Identifiable {
    let id: String
    let date: Date?
}

private struct CalendarCard: View {
    @EnvironmentObject private var store: AppStore
    @Binding var month: Date
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 7)

    var body: some View {
        VStack(spacing: 17) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(month, format: .dateTime.year().month(.wide))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(GapStyle.ink)
                    Text(store.text("破例和冲动会分开标记。", "Slips and urges are marked separately."))
                        .font(.caption)
                        .foregroundStyle(GapStyle.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    monthButton("chevron.left", delta: -1)
                    monthButton("chevron.right", delta: 1)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(GapStyle.secondary)
                        .frame(height: 20)
                }
                ForEach(days) { day in
                    if let date = day.date {
                        CalendarDayCell(date: date, kinds: eventKinds(on: date))
                    } else {
                        Color.clear.frame(height: 42)
                    }
                }
            }

            HStack(spacing: 14) {
                CalendarLegend(color: GapStyle.coral, text: store.text("破例", "Slip"))
                CalendarLegend(color: GapStyle.plum, text: store.text("冲动", "Urge"))
                Spacer()
            }
        }
        .softCard()
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = store.isChinese ? Locale(identifier: "zh_Hans") : Locale(identifier: "en_US")
        return formatter.veryShortStandaloneWeekdaySymbols
    }

    private var days: [CalendarDay] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else { return [] }
        let leading = calendar.component(.weekday, from: first) - 1
        var result = (0..<leading).map { CalendarDay(id: "empty-\($0)", date: nil) }
        result += range.compactMap { day in
            let date = calendar.date(byAdding: .day, value: day - 1, to: first)
            return CalendarDay(id: "day-\(day)", date: date)
        }
        return result
    }

    private func eventKinds(on date: Date) -> Set<EventKind> {
        Set(store.events.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.map(\.kind))
    }

    private func monthButton(_ icon: String, delta: Int) -> some View {
        Button {
            if let next = Calendar.current.date(byAdding: .month, value: delta, to: month) { month = next }
        } label: {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(GapStyle.ink)
                .frame(width: 36, height: 36)
                .background(.white, in: Circle())
                .overlay { Circle().stroke(GapStyle.line) }
        }
    }
}

private struct CalendarDayCell: View {
    let date: Date
    let kinds: Set<EventKind>

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.subheadline.weight(Calendar.current.isDateInToday(date) ? .bold : .semibold))
                .foregroundStyle(Calendar.current.isDateInToday(date) ? .white : GapStyle.ink)
            HStack(spacing: 3) {
                if kinds.contains(.slip) { Circle().fill(GapStyle.coral).frame(width: 5, height: 5) }
                if kinds.contains(.urge) { Circle().fill(GapStyle.plum).frame(width: 5, height: 5) }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .background(
            Calendar.current.isDateInToday(date) ? GapStyle.ink : eventBackground,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            if !Calendar.current.isDateInToday(date) {
                RoundedRectangle(cornerRadius: 12).stroke(GapStyle.line.opacity(0.8))
            }
        }
    }

    private var eventBackground: Color {
        if kinds.contains(.slip) && kinds.contains(.urge) {
            return GapStyle.coralSoft.opacity(0.9)
        }
        if kinds.contains(.slip) {
            return GapStyle.coralSoft.opacity(0.75)
        }
        if kinds.contains(.urge) {
            return GapStyle.plumSoft.opacity(0.9)
        }
        return .clear
    }
}

private struct CalendarLegend: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(GapStyle.secondary)
        }
    }
}

private struct EventHistoryCard: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                store.text("记录", "Records"),
                subtitle: store.text("间隔数字只在需要计算时出现。", "Gap numbers appear only when they add meaning.")
            )
            if store.events.isEmpty {
                ContentUnavailableView(
                    store.text("还没有记录", "No records yet"),
                    systemImage: "calendar.badge.plus",
                    description: Text(store.text("点击右上角 + 记录第一条事实。", "Tap + to record the first fact."))
                )
                .frame(minHeight: 190)
            } else {
                ForEach(store.events) { event in
                    HistoryEventRow(event: event)
                    if event.id != store.events.last?.id { Divider() }
                }
            }
        }
        .softCard()
    }
}

private struct HistoryEventRow: View {
    @EnvironmentObject private var store: AppStore
    let event: GoalEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                Image(systemName: event.kind == .slip ? "arrow.counterclockwise" : "hand.raised.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(event.kind == .slip ? GapStyle.coral : GapStyle.plum)
                    .frame(width: 34, height: 34)
                    .background(event.kind == .slip ? GapStyle.coralSoft : GapStyle.plumSoft, in: Circle())
                Rectangle().fill(GapStyle.line).frame(width: 1, height: 25)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(event.kind == .slip ? store.text("破例", "Slip") : store.text("控制住冲动", "Urge controlled"))
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Text(event.date, format: .dateTime.month(.abbreviated).day())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GapStyle.secondary)
                }
                if event.kind == .slip, let days = store.metrics.impactDays(for: event) {
                    Text(isLatestSlip
                         ? store.text("已坚持 \(days) 天", "Growing for \(days) days")
                         : store.text("\(days) 天", "\(days) days"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(GapStyle.coral)
                }
                if !event.note.isEmpty {
                    Text(event.note)
                        .font(.subheadline)
                        .foregroundStyle(GapStyle.secondary)
                        .lineLimit(3)
                }
            }
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    private var isLatestSlip: Bool {
        store.events.first(where: { $0.kind == .slip })?.id == event.id
    }
}
