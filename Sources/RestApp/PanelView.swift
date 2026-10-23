import SwiftUI
import RestCore

struct PanelView: View {
    @ObservedObject var model: AppModel
    var close: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label("blinkwell", systemImage: "leaf.fill").font(.system(size: 19, weight: .semibold, design: .rounded))
                Spacer()
                Button { close() } label: { Image(systemName: "xmark") }.buttonStyle(.plain).help("Закрыть панель")
            }
            if let kind = model.breakKind {
                VStack(spacing: 10) {
                    Image(systemName: model.breakCompleted ? "checkmark.seal" : "leaf").font(.largeTitle)
                    Text(model.breakCompleted ? "Перерыв завершён" : kind.title).font(.headline)
                    if !model.breakCompleted { Text(clockText(model.breakRemaining)).font(.system(size: 36, design: .rounded)).monospacedDigit() }
                    Button("Открыть перерыв") { close(); model.prepareBreak(kind) }
                }.frame(maxWidth: .infinity).padding(.vertical, 16)
            } else if !model.preferences.eyesEnabled && !model.preferences.bodyEnabled {
                Label("Напоминания выключены", systemImage: "bell.slash").padding(.vertical, 20)
            } else {
                VStack(spacing: 5) {
                    Text(clockText(model.engine.remaining(model.nextKind))).font(.system(size: 43, weight: .light, design: .rounded)).monospacedDigit()
                    Text(model.nextKind == .eyes ? "до отдыха для глаз" : "до перерыва для тела").font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 9)
                HStack(spacing: 10) {
                    timer(.eyes, enabled: model.preferences.eyesEnabled)
                    timer(.body, enabled: model.preferences.bodyEnabled)
                }
                if let kind = model.engine.pending {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(kind.title).font(.headline)
                        HStack {
                            Button("Начать") { close(); model.startBreak(kind) }.buttonStyle(.borderedProminent)
                            Button("+5 мин") { model.snooze(kind) }
                            Button("Пропустить") { model.skip(kind) }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            ActivityContextView(model:model,compact:true)
            Text(model.status).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if model.quiet { Label("Тихие часы", systemImage: "moon").font(.caption).foregroundStyle(.secondary) }
            HStack {
                Button(model.paused ? "Продолжить" : "Пауза") { model.togglePause() }
                    .buttonStyle(.bordered).disabled(model.breakKind != nil)
                Button(model.reading ? "Закончить чтение" : "Читаю / видео") { model.toggleReading() }
                    .buttonStyle(.borderless).disabled(model.breakKind != nil)
            }
            Button { close(); model.showMain(page: .support) } label: {
                Label("Угостить разработчика кофе", systemImage: "cup.and.saucer").font(.system(size: 12))
                    .frame(maxWidth: .infinity).padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain)
            UpdateCheckButton(manager:model.updates,close:close)
            Divider()
            HStack {
                Button("Открыть окно") { close(); model.showMain() }
                Spacer()
                Button { close(); model.showMain(page: .statistics) } label: { Image(systemName: "chart.bar") }.help("Статистика")
                Button { close(); model.showMain(page: .settings) } label: { Image(systemName: "gearshape") }.help("Настройки")
                Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }.help("Завершить Blinkwell")
            }.buttonStyle(.borderless).font(.system(size: 12))
        }.padding(20).frame(width: 350).fixedSize(horizontal: false, vertical: true).tint(sage)
    }
    private func timer(_ kind: BreakKind, enabled: Bool) -> some View {
        Button {
            close(); model.prepareBreak(kind)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: kind == .eyes ? "eye" : "figure.walk")
                Text(kind == .eyes ? "Глаза" : "Тело").font(.caption)
                Text(enabled ? clockText(model.engine.remaining(kind)) : "Выключено")
                    .font(.system(size: 17, design: .rounded)).monospacedDigit()
            }.frame(maxWidth: .infinity).padding(13).background(.quaternary, in: RoundedRectangle(cornerRadius: 13))
        }.buttonStyle(.plain).help("Начать перерыв сейчас")
    }
}

struct ExerciseSelectionView: View {
    @ObservedObject var model: AppModel
    var showTitle = true
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showTitle { Text("Мой комплекс").font(.headline) }
            ForEach(Exercise.allCases) { exercise in
                Toggle(isOn: Binding(get: { model.preferences.exercises.contains(exercise) },
                    set: { model.setExercise(exercise, enabled: $0) })) {
                    Label(exercise.title, systemImage: exercise.symbol)
                }.disabled(model.preferences.exercises.count == 1 && model.preferences.exercises.contains(exercise))
            }
            Divider()
            Toggle("Автоматически менять подсказки", isOn: $model.preferences.automaticExercises)
            Toggle("Анимации", isOn: $model.preferences.animations)
            Text("Оставь хотя бы одну подсказку. Переходы «Назад» и «Следующее» меняют подсказку, сохраняя общую длительность отдыха. Изменения комплекса применяются со следующего перерыва.")
                .font(.caption).foregroundStyle(.secondary).lineSpacing(3)
        }.padding(16).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
    }
}
