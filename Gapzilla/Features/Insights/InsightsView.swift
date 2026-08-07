import Charts
import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var recordKind: EventKind?
    @State private var presentsGoals = false
    @State private var presentsAccount = false

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackground()
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            InsightHeroCard()
                            GapTrendCard()
                            UrgeEvidenceCard()
                                .id("urge-evidence-card")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .refreshable { await store.refreshAll() }
                    .onAppear {
#if DEBUG
                        if ProcessInfo.processInfo.arguments.contains("--ui-preview-insights-bars") {
                            DispatchQueue.main.async {
                                proxy.scrollTo("urge-evidence-card", anchor: .top)
                            }
                        }
#endif
                    }
                }
            }
            .navigationTitle(store.text("分析", "Insights"))
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

private struct InsightHeroCard: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                store.text("间隔统计", "Gap statistics"),
                eyebrow: store.text("变化摘要", "Progress summary"),
                subtitle: summary
            )
            HStack(spacing: 10) {
                MetricTile(value: store.metrics.currentGap, label: store.text("当前间隔", "Current"), color: GapStyle.info)
                MetricTile(value: store.metrics.bestGap, label: store.text("最长间隔", "Best"), color: GapStyle.warning)
                MetricTile(value: store.metrics.averageGap, label: store.text("平均间隔", "Average"), color: GapStyle.ink)
            }
            if let previous = store.metrics.previousGap {
                HStack {
                    Label(store.text("上一次间隔", "Previous gap"), systemImage: "clock.arrow.circlepath")
                    Spacer()
                    Text("\(previous) \(store.text("天", "days"))").fontWeight(.bold)
                }
                .font(.subheadline)
                .foregroundStyle(GapStyle.secondary)
                .padding(.top, 2)
            }
        }
        .softCard()
    }

    private var summary: String {
        guard let previous = store.metrics.previousGap else {
            return store.text("继续记录，第二次破例后会出现可比较的完整间隔。", "Keep recording. A comparable completed gap appears after the next slip.")
        }
        let delta = store.metrics.currentGap - previous
        if delta > 0 {
            return store.text("当前间隔比上一次多 \(delta) 天。", "The current gap is \(delta) days longer than the previous one.")
        }
        if delta == 0 {
            return store.text("当前间隔已经追平上一次。", "The current gap has matched the previous one.")
        }
        return store.text("当前间隔比上一次少 \(-delta) 天。", "The current gap is \(-delta) days shorter than the previous one.")
    }
}

private struct GapTrendCard: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                store.text("间隔趋势", "Gap trend"),
                subtitle: store.text("每个点代表一次完整间隔，最后一点是当前进度。", "Each point is a completed gap; the last point is current progress.")
            )
            if store.metrics.trend.isEmpty {
                ContentUnavailableView(
                    store.text("还没有趋势", "No trend yet"),
                    systemImage: "chart.xyaxis.line",
                    description: Text(store.text("记录破例后，趋势会从这里生长。", "The trend starts growing after a slip is recorded."))
                )
                .frame(height: 210)
            } else {
                Chart {
                    ForEach(store.metrics.trend) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Days", point.days)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(GapStyle.info)
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Days", point.days)
                        )
                        .symbolSize(36)
                        .foregroundStyle(GapStyle.info)
                    }

                    if let selectedPoint {
                        RuleMark(x: .value("Selected date", selectedPoint.date))
                            .foregroundStyle(GapStyle.secondary.opacity(0.45))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                        PointMark(
                            x: .value("Selected date", selectedPoint.date),
                            y: .value("Selected days", selectedPoint.days)
                        )
                        .symbolSize(72)
                        .foregroundStyle(GapStyle.info)
                        .annotation(
                            position: .top,
                            spacing: 8,
                            overflowResolution: AnnotationOverflowResolution(
                                x: .fit(to: .chart),
                                y: .fit(to: .chart)
                            )
                        ) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedPoint.date, format: chartDateFormat)
                                    .font(.caption2)
                                    .foregroundStyle(GapStyle.secondary)
                                    .lineLimit(1)
                                Text("\(selectedPoint.days) \(store.text("天", "days"))")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(GapStyle.ink)
                            }
                            .fixedSize(horizontal: true, vertical: true)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .background(
                                GapStyle.surface,
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(GapStyle.line, lineWidth: 1)
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedDate)
                .chartXScale(domain: xDomain)
                .chartXScale(range: .plotDimension(startPadding: 28, endPadding: 28))
                .onAppear {
#if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--ui-preview-insights-first-point") {
                        selectedDate = store.metrics.trend.first?.date
                    } else if ProcessInfo.processInfo.arguments.contains("--ui-preview-insights-middle-point") {
                        selectedDate = store.metrics.trend.dropFirst(store.metrics.trend.count / 2).first?.date
                    } else if ProcessInfo.processInfo.arguments.contains("--ui-preview-insights-last-point") {
                        selectedDate = store.metrics.trend.last?.date
                    }
#endif
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(GapStyle.line)
                        AxisValueLabel().foregroundStyle(GapStyle.secondary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: xAxisDates) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel(collisionResolution: .disabled) {
                                Text(date, format: chartDateFormat)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .offset(x: xAxisLabelOffset(for: value))
                            }
                            .foregroundStyle(GapStyle.secondary)
                        }
                    }
                }
                .frame(height: 230)
            }
        }
        .softCard()
    }

    private var chartDateFormat: Date.FormatStyle {
        .dateTime
            .month(.abbreviated)
            .day()
            .locale(Locale(identifier: "zh_Hans"))
    }

    private var selectedPoint: GapPoint? {
        guard let selectedDate else { return nil }
        return store.metrics.trend.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private var xAxisDates: [Date] {
        let dates = store.metrics.trend.map(\.date)
        guard dates.count > 3 else { return dates }
        let lastIndex = dates.count - 1
        return [dates[0], dates[lastIndex / 2], dates[lastIndex]]
    }

    private var xDomain: ClosedRange<Date> {
        let dates = store.metrics.trend.map(\.date)
        guard let first = dates.first, let last = dates.last else {
            return store.metrics.today.addingTimeInterval(-86_400)...store.metrics.today.addingTimeInterval(86_400)
        }
        let padding = max(86_400, last.timeIntervalSince(first) * 0.06)
        return first.addingTimeInterval(-padding)...last.addingTimeInterval(padding)
    }

    private func xAxisLabelOffset(for value: AxisValue) -> CGFloat {
        value.index == value.count - 1 ? -24 : 0
    }
}

private struct MonthUrges: Identifiable {
    let id: Date
    let month: Date
    let count: Int
}

private struct UrgeEvidenceCard: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                store.text("被你控制住的冲动", "Urges you controlled"),
                subtitle: store.text(
                    "只统计已经结束的日期中，同日没有破例的冲动。",
                    "Only urges on completed days without a slip are counted."
                )
            )
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(store.metrics.urgesLastSevenDays)")
                    .font(.system(size: 44, weight: .bold, design: .default))
                    .foregroundStyle(GapStyle.urge)
                Text(store.text("次 / 近 7 天", "in the last 7 days"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GapStyle.secondary)
            }
            Chart(months) { item in
                BarMark(
                    x: .value("Month", monthLabel(for: item.month)),
                    y: .value("Urges", item.count)
                )
                .foregroundStyle(GapStyle.urge)
                .cornerRadius(3)
                .annotation(position: .top, spacing: 4) {
                    if item.count > 0 {
                        Text("\(item.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(GapStyle.urge)
                    }
                }
            }
            .chartYScale(domain: 0...yAxisUpperBound)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(GapStyle.line)
                    AxisValueLabel().foregroundStyle(GapStyle.secondary)
                }
            }
            .chartXAxis {
                AxisMarks(values: months.map { monthLabel(for: $0.month) }) { _ in
                    AxisValueLabel()
                }
            }
            .chartXScale(range: .plotDimension(startPadding: 12, endPadding: 12))
            .frame(height: 150)
        }
        .softCard()
    }

    private var months: [MonthUrges] {
        let calendar = Calendar.current
        let current = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        return (-5...0).compactMap { offset in
            guard let month = calendar.date(byAdding: .month, value: offset, to: current),
                  let next = calendar.date(byAdding: .month, value: 1, to: month) else { return nil }
            let count = store.metrics.controlledUrges.filter { $0.date >= month && $0.date < next }.count
            return MonthUrges(id: month, month: month, count: count)
        }
    }

    private var monthFormat: Date.FormatStyle {
        .dateTime
            .month(.abbreviated)
            .locale(Locale(identifier: "zh_Hans"))
    }

    private var yAxisUpperBound: Int {
        let maximum = months.map(\.count).max() ?? 0
        return max(1, maximum + max(1, maximum / 4))
    }

    private func monthLabel(for month: Date) -> String {
        month.formatted(monthFormat)
    }
}
