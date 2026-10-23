import SwiftUI

struct ActivityContextView: View {
    @ObservedObject var model: AppModel
    var compact = false
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            if let review = model.activityContext.review {
                Label("Ты читал или отходил?",systemImage:"questionmark.circle").font(.headline)
                Text("Без ввода \(Int(review.idleDuration/60)) мин. После порога не учтено \(clockText(review.missingActivity)).")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Чтение вернёт это время в нагрузку и статистику. Отдых сбросит подходящие таймеры, если учёт естественных перерывов включён.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Я читал") { model.resolveIdle(asReading:true) }.buttonStyle(.borderedProminent)
                    Button("Я отходил") { model.resolveIdle(asReading:false) }
                    if !compact { Button("Оставить как есть") { model.dismissIdleReview() }.buttonStyle(.borderless) }
                }
                if compact { Button("Оставить как есть") { model.dismissIdleReview() }.font(.caption) }
            }
            if let reason = model.interruptionReason, !model.hasIdleReview {
                Label(reason,systemImage:"bell.slash").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button(model.manualQuiet ? "Снова напоминать" : "Не отвлекать 30 мин") {model.toggleManualQuiet()}
                    .buttonStyle(.bordered).disabled(model.breakKind != nil)
                if !compact { Text(model.paused ? "Учёт на паузе" : "Время продолжит учитываться").font(.caption).foregroundStyle(.secondary) }
            }
        }.padding(compact ? 10 : 16)
            .frame(maxWidth:.infinity,alignment:.leading)
            .background(sage.opacity(0.06),in:RoundedRectangle(cornerRadius:14))
    }
}
