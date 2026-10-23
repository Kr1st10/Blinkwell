import SwiftUI
import RestCore

let sage = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(red: 0.62, green: 0.79, blue: 0.65, alpha: 1)
        : NSColor(red: 0.28, green: 0.47, blue: 0.35, alpha: 1)
})
private let amber = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(red: 0.88, green: 0.68, blue: 0.43, alpha: 1)
        : NSColor(red: 0.65, green: 0.39, blue: 0.17, alpha: 1)
})

enum Page: String, CaseIterable {
    case today = "Сегодня", exercises = "Перерывы", statistics = "Статистика", settings = "Настройки", support = "Поддержать", sync = "Устройства"
    var icon: String {
        switch self {
        case .today: "sun.max"
        case .exercises: "figure.walk"
        case .statistics: "chart.bar.xaxis"
        case .settings: "slider.horizontal.3"
        case .support: "cup.and.saucer"
        case .sync: "arrow.triangle.2.circlepath"
        }
    }
}

struct MainView: View {
    @ObservedObject var model: AppModel
    private var page: Page { model.selectedPage }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 10) {
                    Image(systemName: "leaf.fill").font(.system(size: 25)).foregroundStyle(sage)
                    Text("blinkwell").font(.system(size: 27, weight: .semibold, design: .rounded))
                }.padding(.bottom, 36).padding(.top, 24)
                ForEach(Page.allCases.filter { $0 != .sync }, id: \.self) { item in
                    Button { model.selectedPage = item } label: {
                        Label(item.rawValue, systemImage: item.icon)
                            .font(.system(size: 14, weight: page == item ? .semibold : .regular))
                            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                            .foregroundStyle(page == item ? sage : .secondary)
                            .background(page == item ? sage.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 11))
                    }.buttonStyle(.plain)
                }
                Spacer()
                Label("Статистика на этом Mac", systemImage: "lock.shield")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Text("Маленькие перерывы.\nБольше заботы о себе.")
                    .font(.system(size: 11)).foregroundStyle(.tertiary).lineSpacing(4).padding(.bottom, 18)
            }.padding(.horizontal, 18).frame(width: 188).background(.quaternary.opacity(0.45))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(page == .today ? "Хороший день для паузы" : page.rawValue)
                                .font(.system(size: 29, weight: .semibold, design: .rounded))
                            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: page.icon).font(.system(size: 24, weight: .light)).foregroundStyle(sage)
                    }
                    switch page {
                    case .today: dashboard
                    case .exercises: exercises
                    case .statistics: StatisticsView(model: model)
                    case .settings: PreferencesView(model: model)
                    case .support: SupportView(model: model)
                    case .sync: Text("Синхронизация отложена. Эта версия работает локально на Mac.")
                    }
                    if let error = model.store.error {
                        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    }
                }.padding(32).frame(maxWidth: 900)
            }.background(Color(nsColor: .windowBackgroundColor))
        }.tint(sage)
        .alert("Blinkwell", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("Понятно") { model.message = nil }
        } message: { Text(model.message ?? "") }
    }
    var subtitle: String {
        switch page {
        case .today: "Отдыхай понемногу — в своём ритме."
        case .exercises: "Можно начать в любой момент, не дожидаясь напоминания."
        case .statistics: "Выбери день и посмотри, как менялся твой ритм."
        case .settings: "Настрой комфортный ритм для себя."
        case .sync: "Общий таймер на твоих устройствах."
        case .support: "Бесплатное приложение с добровольной поддержкой."
        }
    }
    var dashboard: some View {
        VStack(spacing: 18) {
            HStack(spacing: 28) {
                ZStack {
                    Circle().stroke(sage.opacity(0.10), lineWidth: 12)
                    Circle().trim(from: 0, to: progress).stroke(sage, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 5) {
                        Image(systemName: model.nextKind == .eyes ? "eye" : "figure.walk").foregroundStyle(sage)
                        Text(model.breakKind != nil ? (model.breakCompleted ? "Готово" : clockText(model.breakRemaining)) : model.preferences.eyesEnabled || model.preferences.bodyEnabled ? clockText(model.engine.remaining(model.nextKind)) : "—")
                            .font(.system(size: 34, weight: .medium, design: .rounded)).monospacedDigit()
                        Text(model.breakKind != nil ? (model.breakCompleted ? "перерыв завершён" : model.breakRunning ? "осталось отдыхать" : "отдых ещё не начат") : model.preferences.eyesEnabled || model.preferences.bodyEnabled ? "до перерыва" : "напоминания выключены").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }.frame(width: 180, height: 180)
                VStack(alignment: .leading, spacing: 13) {
                    Text(model.paused ? "Можно выдохнуть" : "Время под заботой")
                        .font(.system(size: 23, weight: .medium, design: .rounded))
                    Label(model.status, systemImage: model.engine.isCounting ? "circle.fill" : "pause.circle")
                        .font(.system(size: 12)).foregroundStyle(sage)
                    Text("Blinkwell напомнит, когда пора\nотвести взгляд или немного пройтись.")
                        .font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(4)
                    HStack {
                        Button(model.paused ? "Продолжить" : "Пауза") { model.togglePause() }.buttonStyle(.bordered)
                        Button(model.reading ? "Закончить чтение" : "Читаю / смотрю видео") { model.toggleReading() }
                            .buttonStyle(.borderless).font(.system(size: 11))
                    }
                }
                Spacer(minLength: 0)
            }.padding(26).frame(maxWidth: .infinity).background(sage.opacity(0.055), in: RoundedRectangle(cornerRadius: 23))
            ActivityContextView(model:model)
            if !model.preferences.eyesEnabled && !model.preferences.bodyEnabled {
                Label("Оба напоминания отключены. Включи их в настройках.", systemImage: "bell.slash").foregroundStyle(.secondary)
            }
            if let kind = model.engine.pending {
                HStack {
                    Label(kind.title, systemImage: "bell.badge").font(.headline)
                    Spacer()
                    Button("Начать") { model.startBreak(kind) }.buttonStyle(.borderedProminent)
                    Button("+5 мин") { model.snooze(kind) }
                    Button("Пропустить") { model.skip(kind) }
                }.padding(16).background(amber.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
            }
            HStack(spacing: 16) {
                timerCard(.eyes, icon: "eye", title: "Для глаз", caption: "Посмотреть вдаль", enabled: model.preferences.eyesEnabled)
                timerCard(.body, icon: "figure.walk", title: "Для тела", caption: "Встать и подвигаться", enabled: model.preferences.bodyEnabled)
            }
            HStack(spacing: 12) {
                Image(systemName: "sparkles").foregroundStyle(amber)
                Text("Лучший перерыв — тот, который тебе удобен. Можно отложить или пропустить любое напоминание.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
            }.padding(.vertical, 4)
            Button { model.selectedPage = .support } label: { CoffeeCard() }.buttonStyle(.plain)
            HStack {
                Label("Работает и без сети", systemImage: "lock.shield")
                Spacer()
                Text("macOS · Blinkwell \(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "")")
            }.font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }
    var progress: CGFloat {
        guard model.preferences.eyesEnabled || model.preferences.bodyEnabled else { return 0 }
        let kind = model.nextKind
        let interval = Double((kind == .eyes ? model.preferences.eyesMinutes : model.preferences.bodyMinutes) * 60)
        return min(1, max(0, 1 - model.engine.remaining(kind) / max(1, interval)))
    }
    func timerCard(_ kind: BreakKind, icon: String, title: String, caption: String, enabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(kind == .eyes ? sage : amber)
                Spacer()
                Text(enabled ? "включено" : "выключено").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Text(title).font(.system(size: 17, weight: .semibold))
            Text(model.breakKind == kind && !model.breakCompleted ? "Сейчас отдых" : enabled ? "Через \(clockText(model.engine.remaining(kind)))" : "По твоему желанию")
                .font(.system(size: 15, design: .rounded)).monospacedDigit()
            Text(caption).font(.system(size: 12)).foregroundStyle(.secondary)
            Button("Отдохнуть сейчас →") { model.prepareBreak(kind) }.buttonStyle(.borderless).font(.system(size: 12))
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.quaternary))
    }
    var exercises: some View {
        VStack(alignment: .leading, spacing: 18) {
            routine("eye", "Посмотри вдаль", "Отведи взгляд от экрана примерно на 6 метров. Спокойно моргни. После старта окно скроется, а окончание отметит звук, если он включён.", kind: .eyes)
            routine("figure.walk", "Дай телу движение", "Встань, пройдись, мягко подвигай плечами и смени положение. Двигайся в удобном диапазоне, без боли.", kind: .body)
            ExerciseSelectionView(model: model)
            Text("Это общие напоминания об отдыхе, а не лечение. Если движение вызывает боль или головокружение, прекрати его. При ограничениях подбери движения со специалистом.")
                .font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(5)
            Link("Об организации перерывов — HSE", destination: URL(string: "https://www.hse.gov.uk/msd/dse/work-routine.htm")!)
            Link("Об экранном напряжении — AOA", destination: URL(string: "https://www.aoa.org/healthy-eyes/eye-and-vision-conditions/computer-vision-syndrome")!)
        }
    }
    func routine(_ icon: String, _ title: String, _ text: String, kind: BreakKind) -> some View {
        VStack(alignment: .leading, spacing: 17) {
            Label(title, systemImage: icon).font(.system(size: 20, weight: .medium))
            Text(text).foregroundStyle(.secondary).lineSpacing(5)
            Button("Начать перерыв") { model.prepareBreak(kind) }.buttonStyle(.borderedProminent)
        }.padding(26).frame(maxWidth: .infinity, alignment: .leading).background(sage.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
    }
}

struct CoffeeCard: View {
    var body: some View {
        HStack(spacing: 17) {
            Text("☕").font(.system(size: 30))
            VStack(alignment: .leading, spacing: 5) {
                Text("Угостить разработчика кофе").font(.system(size: 14, weight: .semibold))
                Text("Поддержи приложение — и напиши здесь что-нибудь своё.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "arrow.up.right").foregroundStyle(amber)
        }.padding(21).background(amber.opacity(0.08), in: RoundedRectangle(cornerRadius: 17))
    }
}

struct PreferencesView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Form {
            Section("Глаза") {
                Toggle("Напоминать об отдыхе для глаз", isOn: $model.preferences.eyesEnabled)
                Stepper("Интервал: \(model.preferences.eyesMinutes) мин", value: $model.preferences.eyesMinutes, in: 1...120)
                Stepper("Продолжительность: \(model.preferences.eyesSeconds) сек", value: $model.preferences.eyesSeconds, in: 10...120, step: 5)
            }
            Section("Тело") {
                Toggle("Напоминать о разминке", isOn: $model.preferences.bodyEnabled)
                Stepper("Интервал: \(model.preferences.bodyMinutes) мин", value: $model.preferences.bodyMinutes, in: 5...180, step: 5)
                Picker("Длительность перерыва", selection: $model.preferences.bodyDuration) {
                    Text("2 минуты").tag(2); Text("5 минут").tag(5); Text("10 минут").tag(10)
                }
            }
            Section("Мой комплекс") {
                ExerciseSelectionView(model: model, showTitle: false)
            }
            Section("Активность") {
                Toggle("Приостанавливать при отсутствии ввода", isOn: $model.preferences.smart)
                Stepper("Порог бездействия: \(model.preferences.idleMinutes) мин", value: $model.preferences.idleMinutes, in: 1...15)
                    .disabled(!model.preferences.smart)
                Toggle("Учитывать естественные перерывы", isOn: $model.preferences.naturalRest)
                Text("Отсутствие ввода само по себе не считается отдыхом. После возвращения выбери «Я читал» или «Я отходил». Чтение восстановит пропущенное время и включит режим чтения на час. Подтверждённый отдых от 1 минуты сбрасывает глаза, от 5 минут — оба таймера. Блокировка и ручная пауза учитываются как отдых автоматически. Первые минуты до порога остаются в статистике активности.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Когда удобно напомнить") {
                Toggle("Не прерывать при использовании микрофона",isOn:$model.preferences.deferMicrophone)
                Text("Микрофон используется — нагрузка учитывается даже без ввода, напоминания ждут. После освобождения микрофона — минута на возвращение. Это признак возможного разговора, а не точное распознавание звонка. Звук не записывается. На macOS до 14.2 автоматическое определение недоступно.").font(.caption).foregroundStyle(.secondary)
                Text(model.microphoneDetected ? "Сейчас: микрофон используется" : model.microphoneAvailable ? "Сейчас: микрофон не используется" : "Автоматическое определение выключено или недоступно").font(.caption).foregroundStyle(.secondary)
                Text("Для видео и разговоров с выключенным микрофоном используй «Не отвлекать 30 мин». Чтение / видео включается вручную. Автоматическое распознавание видео пока не подключено.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Напоминания") {
                Toggle("Постоянная карточка напоминания", isOn: $model.preferences.popup)
                Text("Карточка остаётся поверх окон до выбора действия. Системный баннер macOS может исчезнуть — его длительность задаётся системой.").font(.caption).foregroundStyle(.secondary)
                Toggle("Звуки", isOn: $model.preferences.sound)
                HStack { Text(model.permission).font(.caption).foregroundStyle(.secondary); Spacer(); Button("Разрешить") { model.requestNotifications() } }
                Toggle("Тихие часы", isOn: $model.preferences.quietEnabled)
                if model.preferences.quietEnabled {
                    Stepper("С \(model.preferences.quietStart):00", value: $model.preferences.quietStart, in: 0...23)
                    Stepper("До \(model.preferences.quietEnd):00", value: $model.preferences.quietEnd, in: 0...23)
                    Text("Таймеры продолжают работать. Напоминание появится после тихих часов. Одинаковые часы означают тишину весь день.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Обновления") { UpdateSettingsView(manager:model.updates) }
            Section("Приложение") {
                Toggle("Скрывать значок в Dock",isOn:$model.preferences.hideDockIcon)
                Text("Blinkwell останется в строке меню, без значка в Dock и ⌘Tab. Открыть окно, настройки и завершить приложение можно через листочек. Настройка применяется сразу; при следующем запуске главное окно не откроется автоматически.").font(.caption).foregroundStyle(.secondary)
                Toggle("Запускать Blinkwell при входе в macOS", isOn: Binding(get: { model.launchEnabled }, set: { model.setLaunch($0) }))
                Toggle("Возобновлять учёт после сна и разблокировки",isOn:$model.preferences.resumeAfterWake)
                Text("После пробуждения учёт начинается без открытия окна и клика мышью. Эта настройка также снимает ручную паузу после сна или блокировки. Для запуска после перезагрузки включи автозапуск выше. Если завершить приложение через ⌘Q, оно запустится при следующем входе в macOS.").font(.caption).foregroundStyle(.secondary)
                Picker("Оформление", selection: $model.preferences.appearance) {
                    Text("Как в системе").tag("system"); Text("Светлое").tag("light"); Text("Тёмное").tag("dark")
                }
                Text("Закрытие окна оставляет приложение в строке меню. Завершить работу можно через значок листочка.").font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).scrollDisabled(true)
    }
}

struct SupportView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            CoffeeCard()
            Text("Немного кофе — много поддержки").font(.system(size: 22, weight: .medium, design: .rounded))
            Text("Я создаю Blinkwell, чтобы заботиться о себе за экраном было чуть проще. Если приложение помогает тебе, можно будет поддержать его развитие.")
                .foregroundStyle(.secondary).lineSpacing(5)
            HStack(spacing: 14) {
                ForEach([99, 199, 399], id: \.self) { amount in
                    VStack(spacing: 9) {
                        Text(amount == 99 ? "☕" : amount == 199 ? "☕ ☕" : "🫶").font(.title2)
                        Text("\(amount) ₽").font(.headline)
                    }.frame(maxWidth: .infinity).padding(22).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 15))
                }
            }
            Label("Приём донатов ещё не подключён", systemImage: "clock").foregroundStyle(amber)
            Text("Платёжный сервис и проверка оплаты появятся после их настройки разработчиком. Сейчас приложение не принимает деньги и не предлагает подтверждать оплату вручную.")
                .font(.caption).foregroundStyle(.secondary).lineSpacing(4)
            Divider()
            Label("Твоя надпись — после поддержки", systemImage: "lock").font(.headline)
            Text("После подтверждённого доната здесь можно будет задать свою фразу, эмодзи и цвет карточки. Её можно будет менять сколько угодно. Все таймеры и напоминания доступны бесплатно.")
                .font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(4)
            TextField("Например: «Выдохни. Ты всё успеешь 🌿»", text: .constant(""))
                .textFieldStyle(.roundedBorder).disabled(true)
        }
    }
}

struct ReminderView: View {
    @ObservedObject var model: AppModel
    let kind: BreakKind
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Label(kind.title, systemImage: kind == .eyes ? "eye" : "figure.walk").font(.headline).foregroundStyle(sage)
            Text(kind == .eyes ? "Посмотри вдаль и спокойно моргни." : "Время встать, пройтись и сменить положение.")
                .font(.system(size: 13)).foregroundStyle(.secondary)
            HStack {
                Button("Начать") { model.startBreak(kind) }.buttonStyle(.borderedProminent)
                Button("+5 мин") { model.snooze(kind) }
                Button("Пропустить") { model.skip(kind) }
            }
        }.padding(22).frame(maxWidth: .infinity, maxHeight: .infinity).tint(sage)
    }
}

struct BreakView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 23) {
            Spacer()
            Image(systemName: model.breakCompleted ? "checkmark.seal" : model.breakKind == .eyes ? "sun.horizon" : model.currentExercise.symbol)
                .font(.system(size: 65, weight: .ultraLight)).foregroundStyle(sage)
                .symbolEffect(.pulse, options: .repeating, isActive: model.breakRunning && !reduceMotion && model.preferences.animations)
            Text(title).font(.system(size: 27, weight: .medium, design: .rounded))
            Text(instruction).font(.system(size: 14)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).lineSpacing(5).frame(maxWidth: 420)
            if !model.breakCompleted {
                Text(clockText(model.breakRemaining)).font(.system(size: 43, weight: .light, design: .rounded)).monospacedDigit()
                if model.breakKind == .body && model.breakRunning {
                    if model.routine?.automatic == true {
                        Text((model.routine?.index == model.breakExercises.count - 1 ? "До конца перерыва " : "Смена подсказки через ") + clockText(model.stepRemaining))
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    HStack {
                        Button("Назад") { model.moveExercise(by: -1) }.disabled((model.routine?.index ?? 0) == 0)
                        Text("\((model.routine?.index ?? 0) + 1) / \(model.breakExercises.count)").font(.caption).foregroundStyle(.secondary)
                        Button("Следующее") { model.moveExercise(by: 1) }.disabled((model.routine?.index ?? 0) >= model.breakExercises.count - 1)
                    }
                }
            }
            if model.breakKind == .body {
                Button("Свернуть в карточку") { model.toggleCompactBreak() }.buttonStyle(.borderless)
            }
            HStack {
                if model.breakCompleted {
                    Button("Вернуться к делам") { model.closeBreak() }.buttonStyle(.borderedProminent)
                } else {
                    Button("Отменить") { model.cancelBreak() }.buttonStyle(.borderless)
                    if !model.breakRunning {
                        Button(model.breakKind == .eyes ? "Отвести взгляд и начать" : "Начать перерыв") { model.beginBreak() }.buttonStyle(.borderedProminent)
                    }
                }
            }
            Text(model.breakKind == .eyes ? "Отсчёт отдыха начинается только после старта. Окно скроется — смотреть на таймер не нужно." : "Двигайся спокойно, без боли. Смотреть на экран необязательно.")
                .font(.system(size: 10)).foregroundStyle(.tertiary).multilineTextAlignment(.center)
            Spacer()
        }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity).background(sage.opacity(0.055)).tint(sage)
    }
    var title: String {
        if model.breakCompleted { return "Хорошая пауза" }
        return model.breakKind == .eyes ? "Посмотри вдаль" : model.currentExercise.title
    }
    var instruction: String {
        if model.breakCompleted { return "Перерыв завершён. Можно спокойно возвращаться к делам." }
        return model.breakKind == .eyes ? "Выбери предмет примерно в 6 метрах от себя.\nРасслабь взгляд и несколько раз спокойно моргни." : model.currentExercise.instruction
    }
}
