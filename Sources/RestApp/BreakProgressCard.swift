import SwiftUI

struct BreakProgressCard: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            Label(model.breakCompleted ? "Перерыв завершён" : "Разминка",systemImage:model.breakCompleted ? "checkmark.seal" : "figure.walk")
                .font(.headline).foregroundStyle(sage)
            if !model.breakCompleted {
                Text(model.currentExercise.title).font(.subheadline)
                Text(clockText(model.breakRemaining)).font(.system(size:32,weight:.light,design:.rounded)).monospacedDigit()
                Text("Двигайся спокойно. Смотреть на экран необязательно.").font(.caption).foregroundStyle(.secondary)
            } else { Text("Можно возвращаться к делам.").foregroundStyle(.secondary) }
            HStack {
                if model.breakCompleted { Button("Готово") {model.closeBreak()}.buttonStyle(.borderedProminent) }
                else if !model.breakRunning { Button("Начать") {model.beginBreak()}.buttonStyle(.borderedProminent) }
                Button("Развернуть") {model.toggleCompactBreak()}
                if !model.breakCompleted { Button("Отменить") {model.cancelBreak()}.buttonStyle(.borderless) }
            }
        }.padding(20).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.leading).background(.regularMaterial).tint(sage)
    }
}
