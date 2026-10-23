import SwiftUI
import Charts
import RestCore
import RestStorage

struct StatisticsView: View {
    @ObservedObject var model: AppModel
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var selectedTime: Date?
    @State private var details: DayDetails?
    @State private var confirmClear = false
    private var calendar: Calendar { .current }
    private var start: Date { calendar.startOfDay(for: selectedDay) }
    private var end: Date { calendar.date(byAdding: .day, value: 1, to: start)! }
    private var chosenBin: ActivityBin? {
        guard let selectedTime else { return nil }
        return details?.bins.first { selectedTime >= $0.start && selectedTime < $0.start.addingTimeInterval(900) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                Button { moveDay(-1) } label: { Image(systemName: "chevron.left") }.help("Предыдущий день")
                DatePicker("День", selection: $selectedDay, in: ...Date(), displayedComponents: .date)
                    .labelsHidden().datePickerStyle(.field)
                Button { moveDay(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(calendar.isDateInToday(selectedDay)).help("Следующий день")
                Spacer()
                Button("Сегодня") { selectedDay = calendar.startOfDay(for: Date()) }
            }
            HStack(spacing: 12) {
                metric("Активность", value: duration(details?.summary?.seconds ?? 0), icon: "desktopcomputer")
                metric("Отдых для глаз", value: "\(details?.summary?.eyes ?? 0)", icon: "eye")
                metric("Перерывы для тела", value: "\(details?.summary?.body ?? 0)", icon: "figure.walk")
            }
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Ритм дня").font(.system(size: 20, weight: .medium, design: .rounded))
                        Text("\(selectedDay.formatted(.dateTime.day().month(.wide))) · активность по 15 минут")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let chosenBin {
                        VStack(alignment: .trailing, spacing: 5) {
                            Text(chosenBin.start.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))).font(.caption)
                            Text(duration(chosenBin.seconds)).font(.headline).monospacedDigit()
                        }
                    }
                }
                Chart {
                    ForEach((details?.bins ?? []).filter { $0.seconds > 0 }) { bin in
                        RectangleMark(xStart: .value("Начало", bin.start), xEnd: .value("Конец", min(end, bin.start.addingTimeInterval(900))),
                                      yStart: .value("Ноль", 0.0), yEnd: .value("Минуты", bin.seconds / 60))
                            .foregroundStyle(LinearGradient(colors: [sage.opacity(0.9), sage.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                            .offset(xStart: 0.5, xEnd: -0.5)
                            .cornerRadius(3)
                    }
                    if let chosenBin {
                        RuleMark(x: .value("Выбрано", chosenBin.start)).foregroundStyle(.secondary.opacity(0.4)).lineStyle(StrokeStyle(dash: [3, 4]))
                    }
                }
                .chartXScale(domain: start...end).chartYScale(domain: 0...15)
                .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 4)) { _ in AxisGridLine().foregroundStyle(.quaternary); AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted))) } }
                .chartYAxis { AxisMarks(position: .leading, values: [0, 5, 10, 15]) { value in
                    AxisGridLine().foregroundStyle(.quaternary)
                    AxisValueLabel { if let number = value.as(Int.self) { Text("\(number) мин") } }
                } }
                .chartXSelection(value: $selectedTime).frame(height: 225)
                .accessibilityLabel("Активность за \(selectedDay.formatted(date: .long, time: .omitted))")
                .accessibilityValue(duration(details?.locatedSeconds ?? 0))
                if let details, details.locatedSeconds < 1 {
                    Text(details.legacySeconds > 1 ? "Для этого дня сохранился только общий итог. Почасового распределения в старой версии не было." : "За этот день пока нет записанной активности.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Нажми или проведи по графику, чтобы посмотреть отдельный интервал.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let details, details.legacySeconds >= 1 {
                    Label("\(duration(details.legacySeconds)) в общем итоге записаны до появления графика.", systemImage: "clock.arrow.circlepath")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(24).background(sage.opacity(0.045), in: RoundedRectangle(cornerRadius: 20))
            if let details, !details.events.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Перерывы в этот день").font(.headline)
                    Chart(details.events) { event in
                        PointMark(x: .value("Время", event.date), y: .value("Вид", event.kind == .eyes ? "Глаза" : "Тело"))
                            .symbolSize(65).foregroundStyle(event.kind == .eyes ? sage : Color.orange)
                    }.chartXScale(domain: start...end)
                        .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 4)) { _ in AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted))) } }
                        .frame(height: 85)
                    Text("Отмечены завершённые таймеры отдыха. Выполнение движений приложение не проверяет.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(22).background(.background, in: RoundedRectangle(cornerRadius: 18))
            }
            if !model.days.isEmpty {
                Text("История дней").font(.headline)
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(model.days) { day in
                            Button { if let date = dateFromKey(day.id) { selectedDay = date } } label: {
                                VStack(spacing: 7) {
                                    Text(dateFromKey(day.id)?.formatted(.dateTime.day().month(.abbreviated)) ?? day.id).font(.caption)
                                    Text(duration(day.seconds)).font(.system(size: 15, weight: .medium, design: .rounded))
                                    Text(breakCount(day.eyes + day.body)).font(.system(size: 10)).foregroundStyle(.secondary)
                                }.frame(width: 115).padding(.vertical, 15)
                                    .background(ActivityBuckets.dayKey(selectedDay) == day.id ? sage.opacity(0.13) : Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 13))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            Text("Сохраняются только длительность активности в 15-минутных интервалах и время завершения перерывов. Без названий приложений, текста или содержимого экрана. Все данные — на этом Mac.")
                .font(.caption).foregroundStyle(.secondary).lineSpacing(3)
            Button("Удалить статистику…", role: .destructive) { confirmClear = true }
        }
        .onAppear { model.flush(); reload() }
        .onChange(of: selectedDay) { _, _ in selectedTime = nil; reload() }
        .onChange(of: model.statisticsRevision) { _, _ in reload() }
        .confirmationDialog("Удалить всю локальную статистику?", isPresented: $confirmClear) {
            Button("Удалить", role: .destructive) { model.clearStatistics() }
        } message: { Text("Это действие нельзя отменить. Настройки сохранятся.") }
    }
    private func reload() { details = model.store.details(on: selectedDay) }
    private func moveDay(_ offset: Int) { if let date = calendar.date(byAdding: .day, value: offset, to: selectedDay) { selectedDay = date } }
    private func dateFromKey(_ key: String) -> Date? {
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"; return formatter.date(from: key)
    }
    private func duration(_ seconds: Double) -> String {
        let minutes = Int(max(0, seconds) / 60)
        if seconds > 0 && minutes == 0 { return "<1 мин" }
        return minutes >= 60 ? "\(minutes / 60) ч \(minutes % 60) мин" : "\(minutes) мин"
    }
    private func breakCount(_ count: Int) -> String {
        let tail = count % 100
        let word = (11...14).contains(tail) ? "перерывов" : count % 10 == 1 ? "перерыв" : (2...4).contains(count % 10) ? "перерыва" : "перерывов"
        return "\(count) \(word)"
    }
    private func metric(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).foregroundStyle(sage)
            Text(value).font(.system(size: 23, weight: .medium, design: .rounded)).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.padding(19).frame(maxWidth: .infinity, alignment: .leading).background(sage.opacity(0.065), in: RoundedRectangle(cornerRadius: 16))
    }
}
