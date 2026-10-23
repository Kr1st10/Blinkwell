import AppKit
import Combine
import Sparkle
import SwiftUI

@MainActor final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var canCheck = false
    @Published private(set) var automaticChecks = false
    @Published private(set) var status = "Обновления проверяются по твоему запросу"
    private var observations = Set<AnyCancellable>()
    private var started = false
    private lazy var controller = SPUStandardUpdaterController(startingUpdater:false,updaterDelegate:self,userDriverDelegate:nil)
    var beforeCheck: (() -> Void)?
    var beforeInstall: (() -> Void)?

    func start() {
        guard !started else { return }
        started = true
        controller.updater.publisher(for:\.canCheckForUpdates)
            .receive(on:RunLoop.main).sink { [weak self] in self?.canCheck = $0 }.store(in:&observations)
        controller.updater.publisher(for:\.automaticallyChecksForUpdates)
            .receive(on:RunLoop.main).sink { [weak self] in self?.automaticChecks = $0 }.store(in:&observations)
        controller.startUpdater()
    }
    func check() {
        guard canCheck else { return }
        beforeCheck?()
        status = "Проверяем новую версию…"
        controller.checkForUpdates(nil)
    }
    func setAutomaticChecks(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
        status = enabled ? "Новые версии проверяются автоматически" : "Обновления проверяются по твоему запросу"
    }
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        status = "Доступна версия \(item.displayVersionString)"
    }
    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        status = "Установлена актуальная совместимая версия"
    }
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let failure = error as NSError
        if failure.domain == SUSparkleErrorDomain && failure.code == SUError.noUpdateError.rawValue { return }
        status = "Не удалось проверить или установить обновление. Попробуй позже."
    }
    // The ordinary termination path also flushes statistics; this hook covers
    // installation handoff before Sparkle asks the host application to terminate.
    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        beforeInstall?()
    }
}

struct UpdateSettingsView: View {
    @ObservedObject var manager: UpdateManager
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {
                Text("Blinkwell \(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "")")
                Spacer()
                Button("Проверить обновления…") {manager.check()}.disabled(!manager.canCheck)
            }
            Toggle("Проверять обновления автоматически",isOn:Binding(get:{manager.automaticChecks},set:{manager.setAutomaticChecks($0)}))
            Text(manager.status).font(.caption).foregroundStyle(.secondary)
            Text("Проверка обращается к GitHub. Настройки и статистика не отправляются. Пакет проверяется по подписи разработчика; установка перезапускает приложение. Автоматическая установка выключена.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct UpdateCheckButton: View {
    @ObservedObject var manager: UpdateManager
    var close: () -> Void
    var body: some View {
        Button {close(); manager.check()} label: {
            Label("Проверить обновления…",systemImage:"arrow.down.circle")
                .frame(maxWidth:.infinity,alignment:.leading)
        }.buttonStyle(.borderless).font(.system(size:12)).disabled(!manager.canCheck)
    }
}
